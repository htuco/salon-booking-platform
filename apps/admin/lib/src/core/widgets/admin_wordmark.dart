/// Ime proizvoda i logo placeholder — **jedno mjesto za obje ljuske**.
///
/// Do FE-401 je „Salon OS" stajao prepisan na dva mjesta (sidebar i prijava), uz znak `SO`
/// u kvadratu. Preimenovanje je zato bilo izmjena na dva fajla plus četiri asercije; ovaj
/// widget postoji da sljedeće preimenovanje bude izmjena na jednom mjestu.
///
/// **Ime proizvoda je konstanta, ne string u ekranu.** Admin je jedan platformski build za
/// sve salone, pa ovdje nikad ne ide ime salona — ono dolazi iz `salons` i stoji u
/// breadcrumbu top bara.
///
/// Logo je **placeholder**, kao i u `adminv2/export/3b` i `3j`: isprekidani kvadrat sa
/// natpisom `LOGO`. Pravi logo još ne postoji kao asset; kad stigne, mijenja se samo ovdje.
library;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Ime proizvoda. Jedina tačka istine za string koji se vidi u UI-u.
const String kImeProizvoda = 'Melura';

/// Podnaslov uz ime na ekranu prijave (`3j`).
const String kPotpisProizvoda = 'administracija salona';

/// Uloga prijavljenog, ispisana za čovjeka — `3b` je crta ispod imena u podnožju sidebara.
///
/// Ulazi su tri vrijednosti `public.staff_role` enuma (`super_admin`, `salon_admin`,
/// `employee`). **Nepoznata uloga vraća `null`, a ne sirovu vrijednost**: red iz baze koji
/// ovdje ne prepoznajemo znači da je enum proširen, a ispisati `salon_manager` korisniku
/// je gore nego ne ispisati ništa — podnožje tada pokaže samo ime i mail, kao do sada.
String? labelaUloge(String role) => switch (role) {
  'super_admin' => 'administrator platforme',
  'salon_admin' => 'vlasnik lokacije',
  'employee' => 'radnik',
  _ => null,
};

/// Wordmark sa logo placeholderom.
///
/// `naTamnom` bira boju teksta: sidebar i desna strana prijave su tamni, lijeva strana
/// prijave je svijetla. Boje idu iz palete, nikad hardkodirane — `no_hardcoded_colors_test`
/// to i provjerava.
class AdminWordmark extends StatelessWidget {
  const AdminWordmark({
    this.naTamnom = true,
    this.potpis = false,
    this.velicinaZnaka = 30,
    super.key,
  });

  /// Tekst ide na tamnu podlogu (sidebar, desna strana prijave).
  final bool naTamnom;

  /// Ispisuje „administracija salona" ispod imena — samo na prijavi (`3j`).
  final bool potpis;

  /// Stranica logo placeholdera.
  final double velicinaZnaka;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final bojaTeksta = naTamnom ? boje.sidebarAccentForeground : boje.ink;
    final bojaPotpisa = naTamnom ? boje.sidebarMuted : boje.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoPlaceholder(strana: velicinaZnaka, naTamnom: naTamnom),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Velikim slovima kao u `3b` i `3j`. `toUpperCase()` se **ne** poziva ovdje:
                // ime je vlastita imenica i tako se i čita naglas u čitaču ekrana, a vizuelni
                // oblik je stvar stila. Handoff ga crta verzalom, pa ide `letterSpacing`.
                kImeProizvoda.toUpperCase(),
                semanticsLabel: kImeProizvoda,
                overflow: TextOverflow.ellipsis,
                // `3b`: 21 px, 600, razmak `.1em` — visina verzala 15 px na 2× izvozu.
                style: barlow(
                  size: 21,
                  weight: 600,
                  height: 1.1,
                  tracking: 0.1,
                  color: bojaTeksta,
                ),
              ),
              if (potpis)
                Text(
                  kPotpisProizvoda,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.eyebrow.copyWith(color: bojaPotpisa),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Isprekidani kvadrat sa natpisom `LOGO`, kako ga crta handoff.
///
/// Namjerno je **placeholder, a ne prazan prostor**: prazno mjesto u sidebaru izgleda kao
/// greška u iscrtavanju, a isprekidani okvir kaže „ovdje ide logo, još ga nema".
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder({required this.strana, required this.naTamnom});

  final double strana;
  final bool naTamnom;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final boja = naTamnom ? boje.sidebarMuted : boje.textMuted;

    return SizedBox(
      width: strana,
      height: strana,
      child: CustomPaint(
        painter: _IsprekidaniOkvir(boja: boja),
        child: Center(
          child: Text(
            'LOGO',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: boja,
              fontSize: 7,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Isprekidana granica; Flutter je nema u `Border`, pa se crta ručno.
class _IsprekidaniOkvir extends CustomPainter {
  const _IsprekidaniOkvir({required this.boja});

  final Color boja;

  @override
  void paint(Canvas canvas, Size size) {
    final olovka = Paint()
      ..color = boja
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const crtica = 3.0;
    const razmak = 2.5;
    final putanja = Path()
      ..addRect(Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1));

    for (final mjera in putanja.computeMetrics()) {
      var pozicija = 0.0;
      while (pozicija < mjera.length) {
        final kraj = (pozicija + crtica).clamp(0.0, mjera.length);
        canvas.drawPath(mjera.extractPath(pozicija, kraj), olovka);
        pozicija = kraj + razmak;
      }
    }
  }

  @override
  bool shouldRepaint(_IsprekidaniOkvir stari) => stari.boja != boja;
}
