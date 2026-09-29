/// Tipografija iz `prototype/ui/SPEC.md` §Design Tokens.
///
/// Dva pisma, sa jasnom podjelom posla:
///
/// - **DM Serif Display** nosi naslove i brojeve (vrijeme termina, cijena). To je ono što
///   ekranu daje karakter; bez njega handoff izgleda kao bilo koja Material aplikacija.
/// - **Archivo** nosi sve ostalo — tijelo, dugmad, labele.
///
/// **Fajlovi se pakuju uz aplikaciju** (`apps/client/pubspec.yaml`), nikad se ne učitavaju
/// sa mreže: font preko mreže znači prvi frame u pogrešnom pismu, a na lošoj vezi i ekran
/// bez teksta.
///
/// ## Zašto `FontVariation`, a ne `fontWeight`
///
/// Archivo u `google/fonts` postoji samo kao **varijabilni** font (ose `wdth`/`wght`) —
/// statički rezovi po težini ne postoje u izvoru. Kod varijabilnog fonta `fontWeight` sam
/// zna ostati bez efekta, jer nema zasebnog fajla za tu težinu; `FontVariation('wght', …)`
/// gađa osu direktno. Zato se ovdje postavlja **oboje**: `fontWeight` da Flutter zna šta je
/// semantički u pitanju (i da fallback font bude podebljan), i `fontVariations` da se osa
/// stvarno pomjeri.
///
/// ## Pismo je po temi (ADR-0025)
///
/// Gornje vrijedi za `modern_barber` i `clinical_calm`. `elegant_beauty` nosi **Jost** i za
/// naslove i za tijelo. Tema bira par kroz [AppFonts]; skala ispod je ista za sve teme —
/// mijenja se pismo, ne veličina ni prored.
///
/// ## Boja nije ovdje
///
/// Stilovi nose veličinu, težinu i prored. Boju dodjeljuje tema iz `ColorScheme`-a, jer je
/// ona jedina koja zna koji je tenant u pitanju.
library;

import 'package:flutter/material.dart';

/// Ime porodice za naslove. Mora se poklapati sa `family:` u `pubspec.yaml`.
const String kSerifFamily = 'DM Serif Display';

/// Ime porodice za tijelo teksta.
const String kBodyFamily = 'Archivo';

/// Pismo teme `elegant_beauty`. Varijabilno (`wght` 100–900), kao i Archivo.
const String kJostFamily = 'Jost';

/// Par pisama jedne teme: naslovi i brojevi, pa tijelo.
@immutable
class AppFonts {
  const AppFonts({
    required this.display,
    required this.body,
    this.displayWeight,
  });

  /// DM Serif Display + Archivo — `prototype/ui/SPEC.md`.
  static const classic = AppFonts(display: kSerifFamily, body: kBodyFamily);

  /// Jost za sve, naslovi na 500 — `prototype/beauty/README.md` §Tipografija.
  static const jost = AppFonts(
    display: kJostFamily,
    body: kJostFamily,
    displayWeight: 500,
  );

  final String display;
  final String body;

  /// Težina naslova. `null` znači da pismo ima jedan rez (DM Serif Display) i da se osa
  /// ne gađa.
  final int? displayWeight;
}

/// Pismo tijela sa zadanom težinom — Archivo, osim ako tema ne kaže drugo.
///
/// [weight] je vrijednost `wght` ose (400 / 500 / 600 u ovom sistemu).
TextStyle archivo({
  required double size,
  int weight = 400,
  double height = 1.5,
  Color? color,
  double? letterSpacing,
  String family = kBodyFamily,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: letterSpacing,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// Pismo naslova. DM Serif Display ima samo jednu težinu (400), pa se osa gađa tek kad
/// tema da [AppFonts.displayWeight].
TextStyle serif({
  required double size,
  double height = 1.05,
  Color? color,
  AppFonts fonts = AppFonts.classic,
}) {
  final weight = fonts.displayWeight;
  return TextStyle(
    fontFamily: fonts.display,
    fontSize: size,
    height: height,
    color: color,
    fontWeight: weight == null ? null : FontWeight.values[(weight ~/ 100) - 1],
    fontVariations:
        weight == null ? null : [FontVariation('wght', weight.toDouble())],
  );
}

/// Uppercase kicker iznad naslova — "ZAHTJEV JE POSLAN" na success ekranu.
///
/// `SPEC.md`: 14px/600, letter-spacing `.18em`. Razmak je dio oblika, ne ukras: bez njega
/// verzalni tekst te veličine izgleda kao greška u fontu.
///
/// Pismo je ono koje je tema dala ovom [TextTheme] (ADR-0025). Ekran ne zna temu, pa se
/// pismo čita iz `bodyLarge` — isti izvor iz kojeg ga čita i ostatak ekrana. Kicker je jedini stil koji nije u Material skali, pa mu treba ovaj put.
extension KickerX on TextTheme {
  TextStyle kicker({Color? color}) => archivo(
    size: 14,
    weight: 600,
    height: 1.2,
    letterSpacing: 14 * 0.18,
    color: color,
    family: bodyLarge?.fontFamily ?? kBodyFamily,
  );
}

/// Tipografska skala mapirana na Material `TextTheme`.
///
/// Mapiranje je namjerno plitko — `display*` su naslovi u pismu naslova teme, `title*`
/// su naglašeno tijelo, `body*` je tijelo. Ekran koji treba tačnu veličinu iz handoffa zove
/// [serif]/[archivo] direktno.
TextTheme buildTextTheme({
  required Color primary,
  required Color muted,
  AppFonts fonts = AppFonts.classic,
}) {
  // Pismo teme ulazi ovdje, jednom, pa nijedan stil ispod ne može ostati u tuđem pismu.
  TextStyle naslov({required double size, required Color color}) =>
      serif(size: size, color: color, fonts: fonts);
  TextStyle tijelo({
    required double size,
    int weight = 400,
    double height = 1.5,
    required Color color,
  }) => archivo(
    size: size,
    weight: weight,
    height: height,
    color: color,
    family: fonts.body,
  );

  return TextTheme(
    // Vrijeme termina ("14:30") i druge velike brojke.
    displayLarge: naslov(size: 52, color: primary),
    displayMedium: naslov(size: 44, color: primary),
    // Naslov ekrana ("Izaberite uslugu", "Još jedan korak").
    displaySmall: naslov(size: 40, color: primary),
    headlineLarge: naslov(size: 34, color: primary),
    headlineMedium: naslov(size: 32, color: primary),
    // Naslov sekcije u serifu ("Maj 2026").
    headlineSmall: naslov(size: 26, color: primary),
    // Naziv u redu liste (usluga, radnik) — `SPEC.md`: 20px/600.
    titleLarge: tijelo(size: 21, weight: 600, height: 1.3, color: primary),
    titleMedium: tijelo(size: 20, weight: 600, height: 1.3, color: primary),
    titleSmall: tijelo(size: 18, weight: 600, height: 1.3, color: primary),
    // Tijelo.
    bodyLarge: tijelo(size: 17, color: primary),
    bodyMedium: tijelo(size: 16, color: muted),
    bodySmall: tijelo(size: 15, color: muted),
    // Labela primarnog CTA — `SPEC.md`: 19–21px/600.
    labelLarge: tijelo(size: 19, weight: 600, height: 1.2, color: primary),
    labelMedium: tijelo(size: 16, weight: 500, height: 1.2, color: primary),
    // Najmanji tekst u sistemu. `docs/02 §14` ne dozvoljava ispod 12.
    labelSmall: tijelo(size: 12, weight: 500, height: 1.2, color: muted),
  );
}

