/// Theme factory — **jedina** funkcija koja pravi `ThemeData` u cijelom sistemu.
///
/// Ako neki ekran ili app negdje napravi svoju `ThemeData`, tenant boja prestaje da važi
/// na tom mjestu i to se vidi tek na tuđem buildu. Zato su boje ovdje ulaz, ne konstanta:
/// `buildAppTheme` prima dvije brand boje i ime teme, i sve ostalo izvodi.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/status_colors.dart';
import 'app_theme.dart';
import 'contrast.dart';

/// Gradi temu iz dvije brand boje.
///
/// [primary] i [secondary] su `salons.primary_color`/`secondary_color` iz backenda, ili
/// fallback iz `tenant.yaml` dok odgovor ne stigne. [themeName] bira svjetlinu i
/// neutralnu paletu; nepoznato ime pada na `modern_barber`.
///
/// [brightness] postoji da bi test mogao renderovati istu paletu u obje svjetline. U
/// aplikaciji se ne prosljeđuje — svjetlinu nosi imenovana tema, jer je `modern_barber`
/// tamna po dizajnu, a ne po sistemskoj postavci uređaja.
ThemeData buildAppTheme({
  required Color primary,
  required Color secondary,
  String? themeName,
  Brightness? brightness,
}) {
  final appTheme = AppTheme.fromName(themeName);
  final svjetlina = brightness ?? appTheme.brightness;
  final neutrals = appTheme.neutrals;
  final jeTamna = svjetlina == Brightness.dark;

  // `onPrimary` se racuna, ne pogadja. Ovo je cijeli razlog postojanja ovog fajla:
  // vlasnik moze izabrati zutu, a bijeli tekst na zutoj je neciljiv (`docs/02 §14`).
  final onPrimary = onColorFor(primary);
  final onSecondary = onColorFor(secondary);

  // Brand boja kao **tekst** na pozadini je drugi problem od brand boje kao pozadine:
  // `#171717` (sekundarna barbera) na tamnoj pozadini je nevidljiva. Zato se za tekst
  // uzima pomjerena varijanta koja ostaje prepoznatljivo brand boja.
  //
  // Mjeri se na **obje** povrsine, ne samo na `surface`: cijena na kartici usluge stoji
  // na `surfaceContainer`, koji je tamniji (ili svjetliji) od pozadine ekrana. Verzija
  // koja je gledala samo `surface` davala je roze cijenu sa 4.12:1 na beauty kartici —
  // uhvatio `components_test.dart`, ne oko.
  final primaryNaPozadini = _citljivoNaObje(
    primary,
    neutrals.surface,
    neutrals.surfaceContainer,
  );
  final secondaryNaPozadini = _citljivoNaObje(
    secondary,
    neutrals.surface,
    neutrals.surfaceContainer,
  );

  final colorScheme = ColorScheme(
    brightness: svjetlina,
    primary: primary,
    onPrimary: onPrimary,
    // Kontejnerske varijante nose brand boju kao *pozadinu bloka* (istaknuta kartica),
    // pa moraju ostati dovoljno odvojene od `surface` da se blok uopste vidi.
    primaryContainer: primary,
    onPrimaryContainer: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondary,
    onSecondaryContainer: onSecondary,
    error: jeTamna ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
    onError: jeTamna ? const Color(0xFF2C0000) : const Color(0xFFFFFFFF),
    surface: neutrals.surface,
    onSurface: neutrals.textPrimary,
    surfaceContainerHighest: neutrals.surfaceContainer,
    onSurfaceVariant: neutrals.textMuted,
    outline: neutrals.outline,
  );

  final textTheme = _textTheme(neutrals);

  return ThemeData(
    useMaterial3: true,
    brightness: svjetlina,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: neutrals.surface,
    textTheme: textTheme,

    // Statusne boje idu kroz extension, ne kroz `ColorScheme` — v. `status_colors.dart`.
    extensions: <ThemeExtension<dynamic>>[
      jeTamna ? AppStatusColors.dark() : AppStatusColors.light(),
      AppBrandColors(
        primaryOnSurface: primaryNaPozadini,
        secondaryOnSurface: secondaryNaPozadini,
      ),
    ],

    appBarTheme: AppBarTheme(
      backgroundColor: neutrals.surface,
      foregroundColor: neutrals.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),

    cardTheme: CardThemeData(
      color: neutrals.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: neutrals.outline),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        // Minimalna visina je token, ne procjena: `docs/02 §14` trazi 48 dp.
        minimumSize: const Size(0, AppSize.buttonHeight),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryNaPozadini,
        minimumSize: const Size(0, AppSize.buttonHeight),
        textStyle: textTheme.labelLarge,
        side: BorderSide(color: neutrals.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryNaPozadini,
        minimumSize: const Size(0, AppSize.touchTarget),
        textStyle: textTheme.labelLarge,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutrals.surfaceContainer,
      hintStyle: textTheme.bodyMedium?.copyWith(color: neutrals.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: neutrals.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: neutrals.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: primaryNaPozadini, width: 2),
      ),
    ),

    dividerTheme: DividerThemeData(color: neutrals.outline, space: 1),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: neutrals.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),

    // `docs/02 §14`: max 300 ms. Fade je najkraci prelaz koji jos citljivo povezuje ekrane.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Brand boja pomjerena dok ne bude citljiva na **obje** povrsine teme.
///
/// Ista boja nosi tekst i na pozadini ekrana i na kartici, a te dvije se razlikuju. Pomak
/// se racuna prema onoj koja je tezi slucaj — boja citljiva na tezoj je citljiva i na
/// lakoj, dok obrnuto ne vrijedi.
Color _citljivoNaObje(Color brand, Color surface, Color container) {
  final naSurface = readableOn(brand, surface);
  if (meetsAa(naSurface, container)) return naSurface;

  final naContaineru = readableOn(brand, container);
  if (meetsAa(naContaineru, surface)) return naContaineru;

  // Nijedna pojedinacna meta ne zadovoljava obje povrsine — trazi se veci pomak prema
  // onoj povrsini na kojoj boja stoji losije.
  final teza = contrastRatio(brand, surface) < contrastRatio(brand, container)
      ? surface
      : container;
  return readableOn(brand, teza, target: kWcagAa + 1.0);
}

/// Tipografska skala iz `docs/02 §16`.
///
/// Body je 16, a ne Flutterov default 14: `docs/02 §14` trazi **minimum 15 sp**, jer se
/// app koristi jednom rukom, u salonu, cesto starijoj populaciji.
TextTheme _textTheme(AppNeutrals neutrals) {
  final primary = neutrals.textPrimary;
  final muted = neutrals.textMuted;
  return TextTheme(
    // Naziv salona na hero povrsini.
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: primary,
    ),
    // Naslov ekrana.
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: primary,
    ),
    // Naslov sekcije i naslov kartice.
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: primary,
    ),
    // Glavni tekst.
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: primary),
    // Opis, sekundarni tekst.
    bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: muted),
    // Dugmad.
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: primary,
    ),
    // Badge i meta podatak. Najmanji tekst u sistemu — ispod ovoga se ne ide.
    labelSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: muted,
    ),
  );
}

/// Brand boje pomjerene tako da su citljive **kao tekst** na pozadini teme.
///
/// `colorScheme.primary` ostaje tacna brand boja i koristi se kao pozadina (dugme, chip).
/// Za tekst se uzima ovo — inace `#171717` na tamnoj pozadini nestane.
@immutable
class AppBrandColors extends ThemeExtension<AppBrandColors> {
  const AppBrandColors({
    required this.primaryOnSurface,
    required this.secondaryOnSurface,
  });

  final Color primaryOnSurface;
  final Color secondaryOnSurface;

  @override
  AppBrandColors copyWith({
    Color? primaryOnSurface,
    Color? secondaryOnSurface,
  }) => AppBrandColors(
    primaryOnSurface: primaryOnSurface ?? this.primaryOnSurface,
    secondaryOnSurface: secondaryOnSurface ?? this.secondaryOnSurface,
  );

  @override
  AppBrandColors lerp(covariant AppBrandColors? other, double t) {
    if (other == null) return this;
    return AppBrandColors(
      primaryOnSurface: Color.lerp(
        primaryOnSurface,
        other.primaryOnSurface,
        t,
      )!,
      secondaryOnSurface: Color.lerp(
        secondaryOnSurface,
        other.secondaryOnSurface,
        t,
      )!,
    );
  }
}

/// Kratica do brand boja citljivih na pozadini.
extension AppBrandColorsX on BuildContext {
  AppBrandColors get brandColors =>
      Theme.of(this).extension<AppBrandColors>() ??
      AppBrandColors(
        primaryOnSurface: Theme.of(this).colorScheme.primary,
        secondaryOnSurface: Theme.of(this).colorScheme.secondary,
      );
}
