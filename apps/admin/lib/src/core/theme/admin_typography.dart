/// Tipografija admin aplikacije — dva pisma sa podijeljenim poslom.
///
/// - **Space Grotesk** (400/500/600/700): naslovi, tijelo, dugmad, navigacija.
/// - **JetBrains Mono** (400/500/600): vrijeme, datum, inline brojčani podatak, verzalne
///   eyebrow labele i statusne oznake.
///
/// ## Fajlovi su zapakovani, ne sa mreže
///
/// Canvas ih učitava sa Google Fonts (`<link href="fonts.googleapis.com...">`); aplikacija
/// ne smije. Font preko mreže znači prvi frame u pogrešnom pismu, a na lošoj vezi i ekran
/// bez teksta — u alatki kojom salon vodi dan to nije kozmetička šteta. Fajlovi stoje u
/// `apps/admin/assets/fonts/` uz svoju OFL licencu i upisani su u `pubspec.yaml`.
///
/// ## Zašto `fontVariations`, a ne samo `fontWeight`
///
/// Oba pisma su **varijabilna** (jedna `wght` osa), pa `fontWeight` sam zna ostati bez
/// efekta — nema zasebnog fajla za tu težinu. Kod Space Groteska to nije teoretski rizik:
/// njegova osa ide 300–700 sa **defaultom na 300**, pa bi tekst bez `FontVariation` bio
/// tanji od cijelog handoffa, i to ujednačeno, tako da izgleda kao izbor a ne kao greška.
/// Zato se postavlja oboje: `fontWeight` da Flutter zna šta je semantički u pitanju (i da
/// fallback pismo bude podebljano), `fontVariations` da se osa stvarno pomjeri.
///
/// ## Gdje mono prestaje — dva mjesta gdje `SPEC.md` i canvas ne govore isto
///
/// `SPEC.md` daje monu „datume, vrijeme, brojčane metrike i statusne oznake". Mjerenje
/// finalnog canvasa potvrđuje prva dva i **obara ostala dva**:
///
/// - **Velika brojka nije mono.** Canvas ne crta JetBrains Mono nigdje iznad 15 px;
///   brojevi u karticama metrika (`14`, `71%`, `265 KM`) su Space Grotesk 700, 24–38 px.
///   Mono je pismo *inline podatka* — `13:00`, `82%`, `26 MIN`, `15 KM`, broj telefona.
/// - **Statusna oznaka nije mono.** Pilula u finalnom canvasu je
///   `font:500 12.5px 'Space Grotesk'` malim slovima („Potvrđeno"). Verzalna mono oznaka
///   postoji samo u ranijoj skici `Smjer C - Space Grotesk.dc.html`, iz koje je ta
///   rečenica u `SPEC.md` i prepisana.
///
/// U oba slučaja je uzet **crtež**, jer je on ono što ekran mora dati. Razlika je
/// zabilježena u `prototype/admin/SPEC.md`.
///
/// ## Boja nije ovdje
///
/// Stilovi nose pismo, veličinu, težinu i prored. Boju dodjeljuje tema.
library;

import 'package:flutter/material.dart';

/// Ime porodice za sve osim podataka. Mora se poklapati sa `family:` u `pubspec.yaml`.
const String kAdminSansFamily = 'Space Grotesk';

/// Ime porodice za vrijeme, datume, inline brojke i statusne oznake.
const String kAdminMonoFamily = 'JetBrains Mono';

/// Space Grotesk sa zadanom težinom.
///
/// [tracking] je u **em**, kako ga handoff i piše (`letter-spacing:-.02em`), pa se ovdje
/// množi veličinom. Prepisivanje u logičke piksele bi značilo da isti potez izgleda
/// drugačije na 13 i na 34 px.
TextStyle grotesk({
  required double size,
  int weight = 400,
  double height = 1.4,
  double tracking = 0,
  Color? color,
}) => TextStyle(
  fontFamily: kAdminSansFamily,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: tracking == 0 ? null : size * tracking,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// JetBrains Mono sa zadanom težinom.
///
/// `tabularFigures` je ovdje namjerno uvijek uključen: mono pismo drži širinu znaka, ali
/// lista termina se čita kao kolona i cifre moraju stajati jedna ispod druge i kad se
/// promijeni tekstualna skala uređaja.
TextStyle mono({
  required double size,
  int weight = 400,
  double height = 1.3,
  double tracking = 0,
  Color? color,
}) => TextStyle(
  fontFamily: kAdminMonoFamily,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: tracking == 0 ? null : size * tracking,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Imenovani stilovi koje `TextTheme` ne pokriva.
///
/// Material `TextTheme` ima 15 uloga i sve su Space Grotesk — da je neka od njih mono,
/// pokupio bi je prvi `Chip` ili `TooltipTheme` koji je ne očekuje. Mono se zato traži
/// **imenom**, kroz ovu klasu.
abstract final class AdminText {
  /// Vrijeme termina u listi i kalendaru — `13:00`, `10:00–10:40`.
  ///
  /// Canvas: `font:500 14px 'JetBrains Mono'`, najčešći mono stil u handoffu (31 pojava).
  static TextStyle get time => mono(size: 14, weight: 500);

  /// Isto vrijeme, ali kao nosilac reda (kalendar dana, zaglavlje termina).
  static TextStyle get timeLarge => mono(size: 15, weight: 500);

  /// Verzalna eyebrow labela iznad bloka — `VRIJEME`, `KLIJENT`, `VITEZ / DANAS`.
  ///
  /// Razmak `.08em` je dio oblika, ne ukras: bez njega verzalni tekst te veličine izgleda
  /// kao greška u pismu.
  static TextStyle get eyebrow =>
      mono(size: 10.5, weight: 400, tracking: 0.08);

  /// Statusna oznaka u piluli — „Potvrđeno", „Na čekanju".
  ///
  /// **Space Grotesk, ne mono** — v. „Gdje mono prestaje" na vrhu fajla. Canvas:
  /// `font:500 12.5px 'Space Grotesk'`, `border-radius:20px`, `padding:4px 11px`.
  static TextStyle get statusLabel =>
      grotesk(size: 12.5, weight: 500, height: 1.2);

  /// Inline brojčani podatak uz tekst — `82%`, `26 MIN`, `04 NOVA`.
  static TextStyle get dataInline => mono(size: 12, weight: 400);

  /// Veliki broj u kartici metrike — `14`, `71%`, `265 KM`.
  ///
  /// **Space Grotesk, ne mono** — v. „Gdje mono prestaje" na vrhu fajla.
  static TextStyle get metricNumber =>
      grotesk(size: 30, weight: 700, height: 1.15, tracking: -0.03);

  /// Naslov ekrana — `Ponedjeljak, 18. maj`.
  static TextStyle get display =>
      grotesk(size: 34, weight: 700, height: 1.12, tracking: -0.03);
}

/// `TextTheme` admina. Sve uloge su Space Grotesk; veličine i težine su iz canvasa,
/// gdje su mjerene po učestalosti, a ne izabrane.
TextTheme adminTextTheme() => TextTheme(
  // Veliki naslovi: canvas ih crta 700 sa negativnim trackingom, jer Space Grotesk na
  // toj veličini bez zbijanja izgleda razvučeno.
  displayLarge: grotesk(size: 36, weight: 700, height: 1.2, tracking: -0.03),
  displayMedium: grotesk(size: 34, weight: 700, height: 1.12, tracking: -0.03),
  displaySmall: grotesk(size: 30, weight: 700, height: 1.1, tracking: -0.03),
  headlineLarge: grotesk(size: 24, weight: 700, height: 1.15, tracking: -0.025),
  headlineMedium: grotesk(size: 20, weight: 700, height: 1.2, tracking: -0.025),
  headlineSmall: grotesk(size: 19, weight: 600, height: 1.2, tracking: -0.02),
  titleLarge: grotesk(size: 17, weight: 600, height: 1.3, tracking: -0.02),
  titleMedium: grotesk(size: 16, weight: 600, height: 1.3, tracking: -0.01),
  titleSmall: grotesk(size: 15, weight: 600, height: 1.3, tracking: -0.01),
  bodyLarge: grotesk(size: 14.5, height: 1.45),
  bodyMedium: grotesk(size: 14, height: 1.45),
  bodySmall: grotesk(size: 13, height: 1.45),
  // Dugme je 600 — canvas ne koristi 500 ni na jednom primarnom dugmetu.
  labelLarge: grotesk(size: 14, weight: 600, height: 1.2),
  labelMedium: grotesk(size: 13, weight: 500, height: 1.2),
  labelSmall: grotesk(size: 12.5, weight: 500, height: 1.2),
);
