/// Tipografija admin aplikacije — **jedna porodica, Barlow**, u tri reza (400–600). Rez 700
/// je izbačen (ADR-0022): nijedan stil ga nije tražio, a nosio je 108 KB.
///
/// Do ADR-0020 je admin nosio Space Grotesk + JetBrains Mono (ADR-0019). Vlasnik
/// proizvoda je tražio da admin bude **1:1 sa `prototype/adminv2/export/`**, a izvoz je
/// crtan u Barlowu od naslova do vremena u tabeli — mono se u njemu ne pojavljuje nigdje.
///
/// ## Gdje je nestao mono
///
/// Mono je nosio inline podatak (`13:00`, `82%`) da cifre stoje jedna ispod druge. Isti
/// posao radi **`FontFeature.tabularFigures()`** nad Barlowom: svaka cifra dobija istu
/// širinu, a slova ostaju proporcionalna. To je razlog zašto [barlowTabular] postoji kao
/// zasebna funkcija, a ne kao `copyWith` na ekranu — zaboravljen `tnum` se vidi tek kad
/// se `11:00` i `19:20` nađu u istoj koloni.
///
/// ## Fajlovi su zapakovani, ne sa mreže
///
/// Font preko mreže znači prvi frame u pogrešnom pismu, a na lošoj vezi i ekran bez teksta
/// — u alatki kojom salon vodi dan to nije kozmetička šteta. Fajlovi stoje u
/// `apps/admin/assets/fonts/` uz OFL licencu i upisani su u `pubspec.yaml`.
///
/// Rezovi su **statični**, jedan fajl po težini, pa `fontWeight` sam bira fajl i
/// `FontVariation` ovdje nema posla.
///
/// ## Mjere
///
/// Veličine su izmjerene iz `3b` (2× izvoz): visina verzala podijeljena sa 0,7, koliko je
/// verzal u Barlowu od em-kvadrata. Naslov dana 34, brojka metrike 36, red tabele 15,
/// zaglavlje kolone 12 sa razmakom `.08em`.
///
/// ## Boja nije ovdje
///
/// Stilovi nose pismo, veličinu, težinu i prored. Boju dodjeljuje tema.
library;

import 'package:flutter/material.dart';

/// Ime porodice. Mora se poklapati sa `family:` u `pubspec.yaml`.
const String kAdminSansFamily = 'Barlow';

/// Barlow sa zadanom težinom.
///
/// [tracking] je u **em**, kako ga handoff i piše (`letter-spacing:.08em`), pa se ovdje
/// množi veličinom. Prepisivanje u logičke piksele bi značilo da isti razmak izgleda
/// drugačije na 12 i na 34 px.
TextStyle barlow({
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
);

/// Barlow sa **tabularnim ciframa** — za vrijeme, datum i inline brojku.
///
/// Lista termina se čita kao kolona; cifre moraju stajati jedna ispod druge i kad se
/// promijeni tekstualna skala uređaja.
TextStyle barlowTabular({
  required double size,
  int weight = 400,
  double height = 1.3,
  double tracking = 0,
  Color? color,
}) => barlow(
  size: size,
  weight: weight,
  height: height,
  tracking: tracking,
  color: color,
).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Imenovani stilovi koje `TextTheme` ne pokriva.
abstract final class AdminText {
  /// Vrijeme termina u listi i kalendaru — `13:00`, `10:00–10:40`.
  static TextStyle get time => barlowTabular(size: 14, weight: 500);

  /// Isto vrijeme, ali kao nosilac reda (tabela rasporeda, kalendar dana).
  ///
  /// `3b`: `13:00` u tabeli je iste visine kao ime klijenta pored njega — 15 px.
  static TextStyle get timeLarge => barlowTabular(size: 15, weight: 500);

  /// Verzalna labela iznad kolone — `VRIJEME`, `KLIJENT`.
  ///
  /// Razmak `.08em` je dio oblika, ne ukras: bez njega verzalni tekst te veličine izgleda
  /// kao greška u pismu.
  static TextStyle get eyebrow =>
      barlowTabular(size: 12, weight: 500, tracking: 0.08);

  /// Statusna oznaka u piluli — „Potvrđeno", „Na čekanju". `3b`: 13 px, 500.
  static TextStyle get statusLabel =>
      barlow(size: 13, weight: 500, height: 1.2);

  /// Inline brojčani podatak uz tekst — `82%`, `26 min`, brojač u sidebaru.
  static TextStyle get dataInline => barlowTabular(size: 13, weight: 500);

  /// Veliki broj u kartici metrike — `14`, `2h 40m`, `265 KM`. `3b`: 36 px, 600.
  static TextStyle get metricNumber =>
      barlowTabular(size: 36, weight: 600, height: 1.1, tracking: -0.01);

  /// Naslov ekrana — `Ponedjeljak, 18. maj`. `3b`: 34 px, 600.
  static TextStyle get display =>
      barlow(size: 34, weight: 600, height: 1.12, tracking: -0.01);

  /// Verzalna navigacija sidebara — `DANAS`, `KALENDAR`. `3b`: 14 px, 500, `.1em`.
  static TextStyle get navigation =>
      barlow(size: 14, weight: 500, height: 1.2, tracking: 0.1);

  /// Tekst primarnog dugmeta u verzalu — `+ NOVI TERMIN`, `POTVRDI`. `3b`: 14 px, 600,
  /// `.04em` — izmjereno širinom natpisa, jer je verzal osjetljiv na razmak više od
  /// veličine. Sekundarno dugme („Blokiraj termin", „Odbij") ostaje u rečenici.
  static TextStyle get actionLabel =>
      barlow(size: 14, weight: 600, height: 1.2, tracking: 0.04);
}

/// `TextTheme` admina. Sve uloge su Barlow; veličine su iz `3b`.
///
/// Barlow je uži od Space Groteska, pa je ista uloga ovdje za pola do jedan piksel
/// veća nego do ADR-0020 — izvoz tako i crta.
TextTheme adminTextTheme() => TextTheme(
  displayLarge: barlow(size: 36, weight: 600, height: 1.2, tracking: -0.01),
  displayMedium: barlow(size: 34, weight: 600, height: 1.12, tracking: -0.01),
  displaySmall: barlow(size: 30, weight: 600, height: 1.1, tracking: -0.01),
  headlineLarge: barlow(size: 24, weight: 600, height: 1.15),
  headlineMedium: barlow(size: 21, weight: 600, height: 1.2),
  // „Raspored dana", „Zahtjevi", „Zauzetost majstora" — 19 px, 600.
  headlineSmall: barlow(size: 19, weight: 600, height: 1.2),
  titleLarge: barlow(size: 18, weight: 600, height: 1.3),
  titleMedium: barlow(size: 16, weight: 600, height: 1.3),
  // Ime klijenta u redu tabele i u zahtjevu — 15 px, 600.
  titleSmall: barlow(size: 15, weight: 600, height: 1.3),
  // Podnaslov dana („3 majstora u smjeni · …") — 16 px.
  bodyLarge: barlow(size: 16, height: 1.45),
  // Usluga i majstor u tabeli, opis zahtjeva — 15 px.
  bodyMedium: barlow(size: 15, height: 1.45),
  // Labela i opis kartice metrike — 14 px.
  bodySmall: barlow(size: 14, height: 1.45),
  labelLarge: barlow(size: 15, weight: 500, height: 1.2),
  labelMedium: barlow(size: 14, weight: 500, height: 1.2),
  labelSmall: barlow(size: 13, weight: 500, height: 1.2),
);
