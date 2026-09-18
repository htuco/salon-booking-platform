/// `buildAdminTheme()` — **jedina** funkcija koja pravi `ThemeData` u `apps/admin`.
///
/// Ako neki ekran napravi svoju `ThemeData` ili posegne za heksom, od tog mjesta nadalje
/// handoff prestaje da važi, a niko to ne vidi dok ne uporedi dva ekrana jedan uz drugi.
/// Zato su boje ovdje konstante iz `AdminColors`, a ne parametri.
///
/// ## Razlika od `core_ui.buildAppTheme()`
///
/// Klijentska tema **prima** dvije brand boje, jer ih vlasnik bira i mijenjaju se bez
/// builda; zato tamo postoji cijela mašinerija za računanje čitljivog `onPrimary`. Admin
/// je jedan build za sve salone i njegove boje su fiksne — kontrast se zato ne računa u
/// runtime-u nego **mjeri u testu** (`theme_contrast_test.dart`). Uvoz `core_ui` u admin
/// prolazi analizu i prolazi test, a vidi se tek kad dva salona otvore istu aplikaciju.
library;

import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'admin_status_colors.dart';
import 'admin_tokens.dart';
import 'admin_typography.dart';

/// Tema admin aplikacije.
ThemeData buildAdminTheme() {
  final textTheme = adminTextTheme();
  const borderSide = BorderSide(
    color: AdminColors.border,
    width: AdminSize.hairline,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminRadius.base),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: _adminColorScheme,
    textTheme: textTheme,
    // Widget koji ne gleda `textTheme` (npr. `Text` bez stila u tuđoj komponenti) mora i
    // dalje dobiti Space Grotesk, a ne Roboto.
    fontFamily: kAdminSansFamily,
    scaffoldBackgroundColor: AdminColors.ground,
    canvasColor: AdminColors.ground,
    dividerColor: AdminColors.separator,
    extensions: [AdminStatusColors.standard()],

    // Kartica: bijela ploha na sivoj podlozi, bez sjenke. Dubina u ovom sistemu dolazi iz
    // hairline obruba — `elevation` bi dodao drugi jezik dubine preko istog elementa.
    cardTheme: CardThemeData(
      color: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: borderSide,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: AdminColors.ink),
      shape: const Border(bottom: borderSide),
    ),

    dividerTheme: const DividerThemeData(
      color: AdminColors.separator,
      thickness: AdminSize.hairline,
      space: AdminSize.hairline,
    ),

    listTileTheme: ListTileThemeData(
      textColor: AdminColors.ink,
      iconColor: AdminColors.textSecondary,
      shape: shape,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.ink,
        foregroundColor: AdminColors.ground,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        shape: shape,
      ),
    ),

    // Sekundarna radnja je obrub, ne ispuna — canvas primarnu i sekundarnu razlikuje
    // ispunom (`Potvrdi` puno, `Odbij` obrub), ne bojom teksta.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.ink,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        side: borderSide,
        shape: shape,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.accentInk,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        shape: shape,
      ),
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AdminColors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: AdminColors.textSecondary,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: AdminColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: const BorderSide(color: AdminColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: const BorderSide(color: AdminColors.destructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: const BorderSide(color: AdminColors.destructive, width: 2),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AdminColors.accentTint,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(color: AdminColors.textSecondary),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: AdminColors.textSecondary),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AdminColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AdminColors.ground,
      ),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: AdminColors.ink),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AdminColors.ink),
      shape: shape,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium?.copyWith(color: AdminColors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: borderSide,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AdminColors.accent,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AdminColors.surface,
      selectedColor: AdminColors.accentTint,
      labelStyle: textTheme.labelMedium?.copyWith(color: AdminColors.ink),
      side: borderSide,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
    ),
  );
}

/// `ColorScheme` admina.
///
/// Namjerno **bez** `AdminColors.accentSoft`: bijeli tekst na njemu mjeri 4,15:1, a crni
/// 4,30:1 — nijedan ne prolazi AA, pa ta boja nije podloga za tekst i nema ulogu u šemi.
const ColorScheme _adminColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AdminColors.accent,
  onPrimary: AdminColors.onAccent,
  primaryContainer: AdminColors.accentTint,
  onPrimaryContainer: AdminColors.accentInk,
  // Sekundarna uloga nosi **tamniju** varijantu akcenta, onu koju canvas koristi kao
  // tekst na tintu. Sekundarni akcent iz SPEC tabele ovdje ne stoji — v. doc iznad.
  secondary: AdminColors.accentInk,
  onSecondary: AdminColors.onAccent,
  secondaryContainer: AdminColors.accentTint,
  onSecondaryContainer: AdminColors.accentInk,
  // Tercijarna uloga je „čeka odgovor" — jedini status koji i van liste termina traži
  // svoju boju (brojač zahtjeva na dashboardu).
  tertiary: AdminColors.waitingInk,
  onTertiary: AdminColors.onAccent,
  tertiaryContainer: AdminColors.waitingTint,
  onTertiaryContainer: AdminColors.waitingInk,
  error: AdminColors.destructive,
  onError: AdminColors.onAccent,
  errorContainer: AdminColors.destructiveTint,
  onErrorContainer: AdminColors.destructive,
  // `surface` je **radna pozadina**, ne kartica: to je ploha na kojoj ekran počinje.
  // Kartice su `surfaceContainer*` i bijele su.
  surface: AdminColors.ground,
  onSurface: AdminColors.ink,
  surfaceContainerLowest: AdminColors.surface,
  surfaceContainerLow: AdminColors.surface,
  surfaceContainer: AdminColors.surface,
  surfaceContainerHigh: AdminColors.neutralTint,
  surfaceContainerHighest: AdminColors.neutralTint,
  // `textMuted` (#6B757B) ovdje **ne smije stajati**: na radnoj pozadini mjeri 4,35:1.
  onSurfaceVariant: AdminColors.textSecondary,
  outline: AdminColors.border,
  outlineVariant: AdminColors.separator,
  inverseSurface: AdminColors.ink,
  onInverseSurface: AdminColors.ground,
);
