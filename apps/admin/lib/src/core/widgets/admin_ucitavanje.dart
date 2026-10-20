import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Animacija čekanja „Termin i sada" (task 63): termin stoji, linija „sada" klizi kroz njega.
///
/// Izvor istine za pokret je `assets/brand/melura-ucitavanje.svg`; ovo je prepis u Dartu, a
/// `web/index.html` je prepis u CSS-u za splash prije prvog Flutter kadra. Sva tri moraju
/// imati isti pokret, inače se na prelazu sa splasha vidi skok — zato su [trajanje] i
/// [kriva] javni i `web_splash_test.dart` ih poredi sa CSS-om.
///
/// **Nije zamjena za kostur.** Ekran sa podacima (Danas, liste, kalendar) i dalje crta
/// [AdminSkeleton]: kostur pokazuje oblik sadržaja koji dolazi, pa se raspored ne pomjeri.
/// Ova animacija je za čekanje bez oblika — start aplikacije i radnja u toku.
class AdminUcitavanje extends StatelessWidget {
  const AdminUcitavanje({this.velicina = 72, super.key});

  /// Stranica kvadrata u kojem se crta (referenca je 100 × 100).
  final double velicina;

  /// Jedan prolaz gore pa dolje — `1.6s` u SVG-u i CSS-u.
  static const trajanje = Duration(milliseconds: 1600);

  /// `cubic-bezier(.45, 0, .25, 1)`, primijenjena na svaku polovinu prolaza, kao CSS
  /// keyframes između 0 %, 50 % i 100 %.
  static const kriva = Cubic(0.45, 0, 0.25, 1);

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Semantics(
      label: 'Učitavanje',
      child: _TerminISada(
        velicina: Size.square(velicina),
        termin: boje.action,
        sada: boje.nowLine,
        tacka: true,
      ),
    );
  }
}

/// Indikator unutar dugmeta dok radnja traje — isti pokret kao [AdminUcitavanje], sužen.
///
/// `CircularProgressIndicator` je Material potpis — debljina, tempo i luk se ne daju
/// uskladiti sa ostatkom redizajna, a unutar dugmeta je i najvidljiviji. Znak je
/// **jednobojan**: termin je ista boja kao linija, prigušena, jer koralni termin ne bi
/// imao kontrast ni na koralnom ni na sivom dugmetu.
///
/// Dugme dok radnja traje je **onemogućeno** (`onPressed: null`), pa sivo. Njegov
/// `DefaultTextStyle` je tada M3 `onSurface` na 38 % — termin bi na tome pao na ~13 % i
/// nestao. Zato se ne nasljeđuje boja teksta nego se uzima [AdminPalette.ink] (≈11:1 na
/// sivom dugmetu; ista vrijednost kao `onAction` na koralnom).
///
/// Na 16–24 px linija i tačka se stope, pa dugme nosi liniju **bez tačke** (tako je i
/// „PRIJAVLJUJEM" na stranici sa znakom), a linija ne pada ispod 2 px.
class AdminButtonBusy extends StatelessWidget {
  const AdminButtonBusy({this.color, super.key});

  /// Boja linije i termina. Kad je `null`, [AdminPalette.ink].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final boja = color ?? context.adminColors.ink;

    return Semantics(
      label: 'Radnja je u toku',
      child: _TerminISada(
        velicina: const Size.square(20),
        termin: boja.withValues(alpha: 0.35),
        sada: boja,
        tacka: false,
      ),
    );
  }
}

class _TerminISada extends StatefulWidget {
  const _TerminISada({
    required this.velicina,
    required this.termin,
    required this.sada,
    required this.tacka,
  });

  final Size velicina;
  final Color termin;
  final Color sada;
  final bool tacka;

  @override
  State<_TerminISada> createState() => _TerminISadaState();
}

class _TerminISadaState extends State<_TerminISada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: AdminUcitavanje.trajanje,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `docs/02 §14`: kad sistem traži manje pokreta, linija stoji na sredini termina.
    // Kontroler se tada zaustavlja, ne samo sakriva — petlja koja tiho vrti kadrove troši
    // bateriju i drži `pumpAndSettle` u testu zauvijek.
    if (MediaQuery.disableAnimationsOf(context)) {
      _kontroler.stop();
    } else if (!_kontroler.isAnimating) {
      _kontroler.repeat();
    }
  }

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final miruje = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _kontroler,
        builder: (context, _) => CustomPaint(
          size: widget.velicina,
          painter: TerminISadaPainter(
            pomak: miruje ? 0 : pomakSada(_kontroler.value),
            termin: widget.termin,
            sada: widget.sada,
            tacka: widget.tacka,
          ),
        ),
      ),
    );
  }
}

/// Pomak linije „sada" u jedinicama reference (−34 … +34) za fazu `t` u `[0, 1)`.
///
/// Prva polovina ide od vrha do dna termina, druga nazad; [AdminUcitavanje.kriva] se
/// primjenjuje na svaku polovinu posebno, kao u CSS keyframes.
@visibleForTesting
double pomakSada(double t) {
  const hod = 34.0;
  if (t < 0.5) {
    return -hod + 2 * hod * AdminUcitavanje.kriva.transform(t * 2);
  }
  return hod - 2 * hod * AdminUcitavanje.kriva.transform((t - 0.5) * 2);
}

/// Crta znak u kvadratu 100 × 100, skaliran na veličinu platna.
@visibleForTesting
class TerminISadaPainter extends CustomPainter {
  const TerminISadaPainter({
    required this.pomak,
    required this.termin,
    required this.sada,
    required this.tacka,
  });

  /// Vertikalni pomak linije u jedinicama reference; 0 je sredina termina.
  final double pomak;
  final Color termin;
  final Color sada;
  final bool tacka;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas
      ..save()
      ..translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2)
      ..scale(s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 12, 52, 76),
        const Radius.circular(_radijusTermina),
      ),
      Paint()..color = termin,
    );

    // Na 20 px (dugme) bi 7 jedinica bilo 1,4 px i antialiasing bi liniju razmazao u
    // sivu crtu, pa ne pada ispod [_minLinijaPx]. Na 72 px je 7 jedinica ionako deblje.
    final debljina = math.max(7.0, _minLinijaPx / s);
    final linija = Paint()..color = sada;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 50 - debljina / 2 + pomak, 84, debljina),
        Radius.circular(math.max(_radijusLinije, debljina / 2)),
      ),
      linija,
    );
    if (tacka) canvas.drawCircle(Offset(12, 50 + pomak), 7.5, linija);

    canvas.restore();
  }

  @override
  bool shouldRepaint(TerminISadaPainter old) =>
      old.pomak != pomak ||
      old.termin != termin ||
      old.sada != sada ||
      old.tacka != tacka;
}

// Geometrija znaka u jedinicama reference 100 × 100, prepisana iz SVG-a. Nije radius
// kontrole (`AdminRadius`): skalira se sa znakom i ne prati temu.
const double _radijusTermina = 10;
const double _radijusLinije = 3.5;

/// Najtanja linija „sada" u logičkim pikselima, bez obzira na veličinu znaka.
const double _minLinijaPx = 2;
