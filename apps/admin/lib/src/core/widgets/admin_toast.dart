import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'admin_scaffold.dart' show AdminBreakpoint;

/// Toast obavijest admina — `prototype/adminv2/toast/` (handoff `5a`–`5c`).
///
/// Zamjenjuje Material `SnackBar`. Snackbar je jedan red na dnu, bez vrste i bez opisa;
/// handoff traži tamnu karticu sa krugom vrste, naslovom, opcionim opisom i najviše jednom
/// akcijom, gore desno na desktopu i odozgo na telefonu.
///
/// ```dart
/// AdminToast.uspjeh(context, 'Termin je potvrđen');
/// AdminToast.greska(context, 'Klijent nije sačuvan', opis: 'Pokušajte ponovo.');
/// ```
///
/// - **Naslov je šta se desilo**, opis jedna rečenica konteksta. Validacija forme ne ide
///   ovdje nego uz polje.
/// - **Uspjeh i informacija se gase sami** za 5 s (koralna linija odbrojava, hover i
///   fokus je zaustavljaju). **Upozorenje i greška stoje** dok se ne zatvore.
/// - **Desktop drži najviše tri**, najnovija gore, najstarija ispada. **Telefon jednu**,
///   nova zamjenjuje staru; zatvara se i povlačenjem prema gore.
///
/// Toast živi u **korijenskom** `Overlay`-u. U aplikaciji je to [AdminToastSloj] iznad
/// navigatora, pa toast stoji i iznad dijaloga i bottom sheeta; u widget testu sa golim
/// `MaterialApp` je to overlay navigatora. Isti poziv radi na oba mjesta.
abstract final class AdminToast {
  /// Radnja korisnika je uspjela.
  static void uspjeh(
    BuildContext context,
    String naslov, {
    String? opis,
    AdminToastAkcija? akcija,
  }) => _iz(context, AdminToastVrsta.uspjeh, naslov, opis, akcija);

  /// Događaj koji nije ishod radnje — novi zahtjev, „uskoro".
  static void info(
    BuildContext context,
    String naslov, {
    String? opis,
    AdminToastAkcija? akcija,
  }) => _iz(context, AdminToastVrsta.info, naslov, opis, akcija);

  /// Radnja nije prošla zbog stanja, ne kvara — slot je u međuvremenu zauzet.
  static void upozorenje(
    BuildContext context,
    String naslov, {
    String? opis,
    AdminToastAkcija? akcija,
  }) => _iz(context, AdminToastVrsta.upozorenje, naslov, opis, akcija);

  /// Radnja nije uspjela.
  static void greska(
    BuildContext context,
    String naslov, {
    String? opis,
    AdminToastAkcija? akcija,
  }) => _iz(context, AdminToastVrsta.greska, naslov, opis, akcija);

  static void _iz(
    BuildContext context,
    AdminToastVrsta vrsta,
    String naslov,
    String? opis,
    AdminToastAkcija? akcija,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    prikazi(overlay, vrsta, naslov, opis: opis, akcija: akcija);
  }

  /// Za mjesto koje nema `BuildContext` ispod overlaya — realtime listener u `main.dart`.
  static void prikazi(
    OverlayState overlay,
    AdminToastVrsta vrsta,
    String naslov, {
    String? opis,
    AdminToastAkcija? akcija,
  }) {
    final domacin = _domacini[overlay] ??= _Domacin(overlay);
    domacin.dodaj(
      _Obavijest(vrsta: vrsta, naslov: naslov, opis: opis, akcija: akcija),
    );
  }
}

enum AdminToastVrsta {
  uspjeh,
  info,
  upozorenje,
  greska;

  /// Uspjeh i informacija se gase sami; upozorenje i greška traže da ih neko pročita.
  Duration? get trajanje => switch (this) {
    uspjeh || info => const Duration(seconds: 5),
    upozorenje || greska => null,
  };
}

/// Jedina akcija toasta — kratka, u verzalu (`Poništi`, `Otvori`, `Pokušaj ponovo`).
@immutable
class AdminToastAkcija {
  const AdminToastAkcija(this.labela, this.onPressed);

  final String labela;
  final VoidCallback onPressed;
}

/// Ključ overlaya iz [AdminToastSloj]; `main.dart` ga koristi za toast bez contexta.
final adminToastOverlayKey = GlobalKey<OverlayState>();

/// Overlay **iznad** navigatora, za `MaterialApp.router(builder: …)`.
///
/// Bez njega bi korijenski overlay bio overlay navigatora, i dijalog otvoren poslije
/// toasta bi ga prekrio.
class AdminToastSloj extends StatefulWidget {
  const AdminToastSloj({required this.child, super.key});

  final Widget child;

  @override
  State<AdminToastSloj> createState() => _AdminToastSlojState();
}

class _AdminToastSlojState extends State<AdminToastSloj> {
  late final OverlayEntry _aplikacija = OverlayEntry(
    opaque: true,
    maintainState: true,
    builder: (_) => widget.child,
  );

  @override
  void didUpdateWidget(AdminToastSloj oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Builder entryja čita `widget.child` tek kad se entry gradi; bez ovoga bi ostao
    // stari router.
    _aplikacija.markNeedsBuild();
  }

  // Nema `dispose()` entryja: ovaj state se gasi **prije** overlaya ispod sebe, a entry
  // koji je još u overlayu ne smije se dispose-ovati (assert u `OverlayEntry.dispose`).

  @override
  Widget build(BuildContext context) =>
      Overlay(key: adminToastOverlayKey, initialEntries: [_aplikacija]);
}

/// Mjere iz `toast.css`.
abstract final class _Mjera {
  static const double sirina = 360;
  static const double odTopBara = 16;
  static const double odRuba = 24;
  static const double razmak = 10;
  static const double telefonRub = 12;
  static const double telefonVrh = 8;
  static const double krug = 28;
  static const int najviseNaDesktopu = 3;

  /// Ispod −40 px povlačenja prema gore toast se zatvara.
  static const double prevlacenje = -40;

  static const Duration ulaz = Duration(milliseconds: 320);
  static const Duration izlaz = Duration(milliseconds: 220);

  /// `cubic-bezier(.2,.9,.3,1.15)` — blagi prebačaj na dolasku.
  static const Curve krivaUlaza = Cubic(0.2, 0.9, 0.3, 1.15);

  /// `ease-in` izlaza. `CurvedAnimation` u reverseu traži obrnutu krivu.
  static const Curve krivaIzlaza = Cubic(0.4, 0, 1, 1);
}

final _domacini = Expando<_Domacin>('toast');

class _Obavijest {
  _Obavijest({
    required this.vrsta,
    required this.naslov,
    required this.opis,
    required this.akcija,
  });

  final AdminToastVrsta vrsta;
  final String naslov;
  final String? opis;
  final AdminToastAkcija? akcija;

  /// Postavljeno kad toast krene napolje; kartica tada pušta izlaz i javlja se nazad.
  final odlazi = ValueNotifier(false);

  bool get ziva => !odlazi.value;
}

/// Lista toastova jednog overlaya. Entry postoji samo dok ima šta da se crta — sljedeći
/// toast se zato ubacuje na vrh, iznad dijaloga otvorenog u međuvremenu.
class _Domacin extends ChangeNotifier {
  _Domacin(this.overlay);

  final OverlayState overlay;
  OverlayEntry? _entry;

  /// Najnoviji prvi.
  final List<_Obavijest> obavijesti = [];

  void dodaj(_Obavijest nova) {
    final zive = obavijesti.where((o) => o.ziva).toList();
    // Isti naslov dvaput (realtime koji pada u petlji, dupli klik) je jedna obavijest.
    if (zive.any((o) => o.vrsta == nova.vrsta && o.naslov == nova.naslov)) {
      return;
    }
    if (_telefon(overlay.context)) {
      for (final o in zive) {
        o.odlazi.value = true;
      }
    } else if (zive.length >= _Mjera.najviseNaDesktopu) {
      zive.last.odlazi.value = true;
    }
    obavijesti.insert(0, nova);
    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => _Podrucje(domacin: this));
      overlay.insert(_entry!);
    }
    notifyListeners();
  }

  void ukloni(_Obavijest o) {
    obavijesti.remove(o);
    if (obavijesti.isNotEmpty) {
      notifyListeners();
      return;
    }
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
    _domacini[overlay] = null;
  }
}

bool _telefon(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AdminBreakpoint.desktop;

class _Podrucje extends StatelessWidget {
  const _Podrucje({required this.domacin});

  final _Domacin domacin;

  @override
  Widget build(BuildContext context) {
    final telefon = _telefon(context);
    return ListenableBuilder(
      listenable: domacin,
      builder: (context, _) {
        final kartice = [
          for (final o in domacin.obavijesti)
            _Kartica(
              key: ObjectKey(o),
              obavijest: o,
              telefon: telefon,
              onUklonjena: () => domacin.ukloni(o),
            ),
        ];
        return Stack(
          children: [
            if (telefon)
              Positioned(
                top: MediaQuery.paddingOf(context).top + _Mjera.telefonVrh,
                left: _Mjera.telefonRub,
                right: _Mjera.telefonRub,
                // Jedna po jedna: stara izlazi ispod nove koja ulazi.
                child: Stack(children: kartice.reversed.toList()),
              )
            else
              Positioned(
                top: AdminSize.topBarHeight + _Mjera.odTopBara,
                right: _Mjera.odRuba,
                width: _Mjera.sirina,
                child: Semantics(
                  container: true,
                  label: 'Obavijesti',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: kartice,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Kartica extends StatefulWidget {
  const _Kartica({
    required this.obavijest,
    required this.telefon,
    required this.onUklonjena,
    super.key,
  });

  final _Obavijest obavijest;
  final bool telefon;
  final VoidCallback onUklonjena;

  @override
  State<_Kartica> createState() => _KarticaState();
}

class _KarticaState extends State<_Kartica> with TickerProviderStateMixin {
  late final AnimationController _pomak = AnimationController(
    vsync: this,
    duration: _Mjera.ulaz,
    reverseDuration: _Mjera.izlaz,
  );
  late final Animation<double> _vidljivost = CurvedAnimation(
    parent: _pomak,
    curve: _Mjera.krivaUlaza,
    reverseCurve: _Mjera.krivaIzlaza.flipped,
  );
  late final Animation<double> _visina = CurvedAnimation(
    parent: _pomak,
    curve: Curves.easeOutCubic,
  );

  /// Odbrojavanje do samozatvaranja. `null` za upozorenje i grešku.
  AnimationController? _odbrojavanje;

  bool _hover = false;
  bool _fokus = false;
  double _povuceno = 0;

  _Obavijest get _o => widget.obavijest;

  @override
  void initState() {
    super.initState();
    _o.odlazi.addListener(_naOdlazak);
    if (_o.vrsta.trajanje case final trajanje?) {
      _odbrojavanje = AnimationController(vsync: this, duration: trajanje)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _zatvori();
        })
        ..forward();
    }
    _pomak.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `prefers-reduced-motion`: pomjeranje nestaje, odbrojavanje ostaje — ono je
    // informacija, ne ukras.
    final bezPokreta = MediaQuery.disableAnimationsOf(context);
    _pomak
      ..duration = bezPokreta ? const Duration(milliseconds: 1) : _Mjera.ulaz
      ..reverseDuration = bezPokreta
          ? const Duration(milliseconds: 1)
          : _Mjera.izlaz;
  }

  @override
  void dispose() {
    _o.odlazi.removeListener(_naOdlazak);
    _odbrojavanje?.dispose();
    _pomak.dispose();
    super.dispose();
  }

  void _zatvori() => _o.odlazi.value = true;

  Future<void> _naOdlazak() async {
    if (!_o.odlazi.value) return;
    _odbrojavanje?.stop();
    await _pomak.reverse().orCancel.catchError((_) {});
    if (mounted) widget.onUklonjena();
  }

  void _pauza() {
    final o = _odbrojavanje;
    if (o == null || !_o.ziva) return;
    if (_hover || _fokus) {
      o.stop();
    } else if (!o.isAnimating) {
      o.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final kartica = MouseRegion(
      onEnter: (_) {
        _hover = true;
        _pauza();
      },
      onExit: (_) {
        _hover = false;
        _pauza();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (imaFokus) {
          _fokus = imaFokus;
          _pauza();
        },
        child: _Tijelo(
          obavijest: _o,
          odbrojavanje: _odbrojavanje,
          onZatvori: _zatvori,
        ),
      ),
    );

    final pomaknuta = AnimatedBuilder(
      animation: _vidljivost,
      child: kartica,
      builder: (context, child) {
        final v = _vidljivost.value;
        final ostatak = 1 - v;
        // `translateX(calc(100% + 32px))` / `translateY(calc(-100% - 60px))`.
        final pomaknuto = widget.telefon
            ? Transform.translate(
                offset: Offset(0, -60 * ostatak + _povuceno),
                child: FractionalTranslation(
                  translation: Offset(0, -ostatak),
                  child: child,
                ),
              )
            : Transform.translate(
                offset: Offset(32 * ostatak, 0),
                child: FractionalTranslation(
                  translation: Offset(ostatak, 0),
                  child: child,
                ),
              );
        return Opacity(opacity: v.clamp(0.0, 1.0), child: pomaknuto);
      },
    );

    if (widget.telefon) {
      return GestureDetector(
        onVerticalDragUpdate: (d) {
          if (!_o.ziva) return;
          setState(() => _povuceno = math.min(0, _povuceno + d.delta.dy));
          if (_povuceno < _Mjera.prevlacenje) _zatvori();
        },
        onVerticalDragEnd: (_) {
          if (_o.ziva) setState(() => _povuceno = 0);
        },
        onVerticalDragCancel: () {
          if (_o.ziva) setState(() => _povuceno = 0);
        },
        child: pomaknuta,
      );
    }

    // Desktop: kartica se rasklapa po visini, pa ostale klize dolje umjesto da skoče.
    // `Align`, ne `SizeTransition`: ovaj drugi uvijek clipuje, pa je od sjene ostajala
    // siva traka oštrih ivica u razmaku ispod kartice.
    return AnimatedBuilder(
      animation: _visina,
      child: Padding(
        padding: const EdgeInsets.only(bottom: _Mjera.razmak),
        child: pomaknuta,
      ),
      builder: (context, child) => Align(
        alignment: Alignment.topCenter,
        heightFactor: _visina.value.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }
}

class _Tijelo extends StatelessWidget {
  const _Tijelo({
    required this.obavijest,
    required this.odbrojavanje,
    required this.onZatvori,
  });

  final _Obavijest obavijest;
  final AnimationController? odbrojavanje;
  final VoidCallback onZatvori;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final akcija = obavijest.akcija;
    final (krug, glif) = switch (obavijest.vrsta) {
      AdminToastVrsta.uspjeh => (boje.toastOk, Icons.check_rounded),
      AdminToastVrsta.info => (boje.toastInfo, null),
      AdminToastVrsta.upozorenje => (
        boje.toastWarn,
        Icons.priority_high_rounded,
      ),
      AdminToastVrsta.greska => (boje.toastErr, Icons.close_rounded),
    };
    final hitno =
        obavijest.vrsta == AdminToastVrsta.upozorenje ||
        obavijest.vrsta == AdminToastVrsta.greska;

    final sadrzaj = Padding(
      // `padding:14px 14px 16px`; uz akciju dno nosi njena dodirna meta.
      padding: EdgeInsets.fromLTRB(14, 14, 14, akcija == null ? 16 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: _Mjera.krug,
              height: _Mjera.krug,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: krug, shape: BoxShape.circle),
              child: glif == null
                  ? Text(
                      'i',
                      style: barlow(
                        size: 14,
                        weight: 600,
                        height: 1,
                        color: boje.sidebarBackground,
                      ),
                    )
                  : Icon(glif, size: 16, color: boje.sidebarBackground),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              // Naslov u ravni sa sredinom kruga (28 px kruga, 19,5 px reda).
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    obavijest.naslov,
                    style: barlow(
                      size: 15,
                      weight: 600,
                      height: 1.3,
                      color: boje.sidebarAccentForeground,
                    ),
                  ),
                  if (obavijest.opis case final opis?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        opis,
                        style: barlow(size: 13.5, color: boje.sidebarText),
                      ),
                    ),
                  if (akcija != null)
                    _Dugme(
                      labela: akcija.labela,
                      onPressed: () {
                        akcija.onPressed();
                        onZatvori();
                      },
                      boja: boje.action,
                      hover: Color.lerp(
                        boje.action,
                        boje.sidebarAccentForeground,
                        0.2,
                      )!,
                      prsten: boje.action,
                      child: Text(
                        akcija.labela.toUpperCase(),
                        semanticsLabel: akcija.labela,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Mjesto za ×; samo dugme stoji u uglu, sa punom dodirnom metom.
          const SizedBox(width: 24),
        ],
      ),
    );

    return Semantics(
      container: true,
      // Uloga je ono što web čitač ekrana najavljuje; na Androidu i iOS-u uloga se ne
      // prenosi, pa tamo najavljuje live region. Oboje zajedno Flutter odbija.
      role: kIsWeb
          ? (hitno ? SemanticsRole.alert : SemanticsRole.status)
          : null,
      liveRegion: !kIsWeb,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: boje.sidebarBackground,
          borderRadius: BorderRadius.circular(AdminRadius.small),
          boxShadow: [
            BoxShadow(
              color: boje.sidebarBackground.withValues(alpha: 0.28),
              offset: const Offset(0, 12),
              blurRadius: 32,
            ),
            BoxShadow(
              color: boje.sidebarBackground.withValues(alpha: 0.16),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AdminRadius.small),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                sadrzaj,
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Dugme(
                    labela: 'Zatvori',
                    onPressed: onZatvori,
                    boja: boje.sidebarMuted,
                    hover: boje.sidebarAccentForeground,
                    prsten: boje.action,
                    kvadrat: true,
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
                if (odbrojavanje case final o?)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: AnimatedBuilder(
                      animation: o,
                      builder: (context, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1 - o.value,
                        child: ColoredBox(color: boje.action),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tekstualno dugme toasta: akcija i ×. Dodirna meta je [AdminSize.touchTarget], a crta
/// se samo glif — Material `TextButton` bi donio podlogu na hoveru koju handoff nema.
class _Dugme extends StatefulWidget {
  const _Dugme({
    required this.labela,
    required this.onPressed,
    required this.boja,
    required this.hover,
    required this.prsten,
    required this.child,
    this.kvadrat = false,
  });

  final String labela;
  final VoidCallback onPressed;
  final Color boja, hover, prsten;
  final Widget child;

  /// × u uglu: 44×44. Akcija je visoka 44, a široka koliko je tekst.
  final bool kvadrat;

  @override
  State<_Dugme> createState() => _DugmeState();
}

class _DugmeState extends State<_Dugme> {
  bool _hover = false;
  bool _prsten = false;

  @override
  Widget build(BuildContext context) {
    final boja = _hover ? widget.hover : widget.boja;
    final glif = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminRadius.small / 2),
        border: _prsten ? Border.all(color: widget.prsten, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: IconTheme.merge(
          data: IconThemeData(color: boja),
          child: DefaultTextStyle.merge(
            style: barlow(
              size: 13,
              weight: 600,
              height: 1.2,
              tracking: 0.04,
              color: boja,
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      label: widget.kvadrat ? widget.labela : null,
      excludeSemantics: widget.kvadrat,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _prsten = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: widget.kvadrat ? AdminSize.touchTarget : null,
            height: AdminSize.touchTarget,
            child: Align(
              alignment: widget.kvadrat
                  ? Alignment.center
                  : AlignmentDirectional.centerStart,
              widthFactor: widget.kvadrat ? null : 1,
              // Padding od 2 px nosi fokus prsten (`outline-offset:2px`); akcija se zato
              // vraća ulijevo, u ravan naslova.
              child: widget.kvadrat
                  ? glif
                  : Transform.translate(
                      offset: const Offset(-2, 0),
                      child: glif,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
