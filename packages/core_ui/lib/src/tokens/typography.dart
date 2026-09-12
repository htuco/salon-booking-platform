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

/// Archivo sa zadanom težinom.
///
/// [weight] je vrijednost `wght` ose (400 / 500 / 600 u ovom sistemu).
TextStyle archivo({
  required double size,
  int weight = 400,
  double height = 1.5,
  Color? color,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: kBodyFamily,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: letterSpacing,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// DM Serif Display. Ima samo jednu težinu (400) — zato nema `weight` parametra.
TextStyle serif({required double size, double height = 1.05, Color? color}) =>
    TextStyle(
      fontFamily: kSerifFamily,
      fontSize: size,
      height: height,
      color: color,
    );

/// Uppercase kicker iznad naslova — "ZAHTJEV JE POSLAN" na success ekranu.
///
/// `SPEC.md`: 14px/600, letter-spacing `.18em`. Razmak je dio oblika, ne ukras: bez njega
/// verzalni tekst te veličine izgleda kao greška u fontu.
TextStyle kicker({Color? color}) => archivo(
  size: 14,
  weight: 600,
  height: 1.2,
  letterSpacing: 14 * 0.18,
  color: color,
);

/// Tipografska skala mapirana na Material `TextTheme`.
///
/// Mapiranje je namjerno plitko — `display*` su serif naslovi, `title*` su Archivo
/// naglašeni, `body*` je tijelo. Ekran koji treba tačnu veličinu iz handoffa zove
/// [serif]/[archivo] direktno.
TextTheme buildTextTheme({required Color primary, required Color muted}) {
  return TextTheme(
    // Vrijeme termina ("14:30") i druge velike brojke.
    displayLarge: serif(size: 52, color: primary),
    displayMedium: serif(size: 44, color: primary),
    // Naslov ekrana ("Izaberite uslugu", "Još jedan korak").
    displaySmall: serif(size: 40, color: primary),
    headlineLarge: serif(size: 34, color: primary),
    headlineMedium: serif(size: 32, color: primary),
    // Naslov sekcije u serifu ("Maj 2026").
    headlineSmall: serif(size: 26, color: primary),
    // Naziv u redu liste (usluga, radnik) — `SPEC.md`: 20px/600.
    titleLarge: archivo(size: 21, weight: 600, height: 1.3, color: primary),
    titleMedium: archivo(size: 20, weight: 600, height: 1.3, color: primary),
    titleSmall: archivo(size: 18, weight: 600, height: 1.3, color: primary),
    // Tijelo.
    bodyLarge: archivo(size: 17, color: primary),
    bodyMedium: archivo(size: 16, color: muted),
    bodySmall: archivo(size: 15, color: muted),
    // Labela primarnog CTA — `SPEC.md`: 19–21px/600.
    labelLarge: archivo(size: 19, weight: 600, height: 1.2, color: primary),
    labelMedium: archivo(size: 16, weight: 500, height: 1.2, color: primary),
    // Najmanji tekst u sistemu. `docs/02 §14` ne dozvoljava ispod 12.
    labelSmall: archivo(size: 12, weight: 500, height: 1.2, color: muted),
  );
}
