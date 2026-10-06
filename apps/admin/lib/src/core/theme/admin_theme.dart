/// `buildAdminTheme()` — **jedina** funkcija koja pravi `ThemeData` u `apps/admin`.
///
/// Ako neki ekran napravi svoju `ThemeData` ili posegne za heksom, od tog mjesta nadalje
/// handoff prestaje da važi, a niko to ne vidi dok ne uporedi dva ekrana jedan uz drugi.
/// Zato su boje ovdje platformske palete, a ne tenant parametri.
///
/// ## Razlika od `core_ui.buildAppTheme()`
///
/// Klijentska tema **prima** dvije brand boje, jer ih vlasnik bira i mijenjaju se bez
/// builda; zato tamo postoji cijela mašinerija za računanje čitljivog `onPrimary`. Admin
/// je jedan build za sve salone i ima fiksnu light/dark paletu — kontrast se zato ne računa u
/// runtime-u nego **mjeri u testu** (`theme_contrast_test.dart`). Uvoz `core_ui` u admin
/// prolazi analizu i prolazi test, a vidi se tek kad dva salona otvore istu aplikaciju.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'admin_status_colors.dart';
import 'admin_tokens.dart';
import 'admin_typography.dart';

/// Tema admin aplikacije.
ThemeData buildAdminTheme([Brightness brightness = Brightness.light]) {
  final colors = brightness == Brightness.dark
      ? AdminPalette.dark
      : AdminPalette.light;
  final textTheme = adminTextTheme();
  final borderSide = BorderSide(
    color: colors.border,
    width: AdminSize.hairline,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminRadius.base),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: _adminColorScheme(colors, brightness),
    // Bez ripplea (FE-205): Material val je najprepoznatljiviji potpis koji redizajn
    // sklanja. Potvrda dodira ostaje — `InkWell` i dalje crta `hoverColor` i
    // `highlightColor` iz teme, pa dugme ne djeluje kao da ne reaguje.
    splashFactory: NoSplash.splashFactory,
    // **Push unutar grane klizi s desna na telefonu, pretapa se na webu i desktopu.**
    // Promjena taba nije push (`indexedStack` je bez animacije), pa prelaz vrijedi samo za
    // detalj u grani. Na Androidu ga daje ova tema uz `MaterialPage`, na iOS-u
    // `CupertinoPage` iz routera (sa swipe-back sa lijeve ivice). Web i desktop ostaju na
    // kratkom pretapanju: sidebar stoji mirno, a klizanje ploče pored njega djeluje kao
    // da se pomjera cijela aplikacija.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platforma in TargetPlatform.values)
          platforma:
              platforma == TargetPlatform.android ||
                  platforma == TargetPlatform.iOS
              ? const CupertinoPageTransitionsBuilder()
              : const _Pretapanje(),
      },
    ),
    textTheme: textTheme,
    // Widget koji ne gleda `textTheme` (npr. `Text` bez stila u tuđoj komponenti) mora i
    // dalje dobiti Barlow, a ne Roboto.
    fontFamily: kAdminSansFamily,
    scaffoldBackgroundColor: colors.ground,
    canvasColor: colors.ground,
    dividerColor: colors.separator,
    extensions: [colors, AdminStatusColors.fromPalette(colors)],

    // Kartica: bijela ploha na sivoj podlozi, bez sjenke. Dubina u ovom sistemu dolazi iz
    // hairline obruba — `elevation` bi dodao drugi jezik dubine preko istog elementa.
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: BorderSide(color: colors.cardEdge, width: AdminSize.hairline),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: colors.separator,
      thickness: AdminSize.hairline,
      space: AdminSize.hairline,
    ),

    listTileTheme: ListTileThemeData(
      textColor: colors.ink,
      iconColor: colors.textSecondary,
      shape: shape,
    ),

    // Ispunjeno dugme je **glavna radnja** i zato nosi `action` (coral), ne `accent`.
    // Ovo je jedino mjesto koje to odlučuje — ekrani ne prepisuju boju dugmeta kod sebe.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.action,
        foregroundColor: colors.onAction,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        shape: shape,
      ),
    ),

    // FAB je ista radnja kao `+ Novi termin` u top baru, samo na telefonu — i mora nositi
    // istu boju. Bez ovoga pada na M3 default (`primaryContainer`/`onPrimaryContainer`),
    // pa je glavni CTA na telefonu blijedo siv dok je na desktopu coral.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.action,
      foregroundColor: colors.onAction,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: textTheme.labelLarge,
    ),

    // Sekundarna radnja je obrub, ne ispuna — canvas primarnu i sekundarnu razlikuje
    // ispunom (`Potvrdi` puno, `Odbij` obrub), ne bojom teksta.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        side: borderSide,
        shape: shape,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, AdminSize.touchTarget),
        shape: shape,
      ),
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
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
        borderSide: BorderSide(color: colors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: BorderSide(color: colors.destructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        borderSide: BorderSide(color: colors.destructive, width: 2),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accentTint,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(color: colors.textSecondary),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: colors.textSecondary),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colors.ink),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.ink),
      shape: shape,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium?.copyWith(color: colors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: borderSide,
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),

    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.accentTint,
      labelStyle: textTheme.labelMedium?.copyWith(color: colors.ink),
      side: borderSide,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
    ),
  );
}

/// `ColorScheme` admina.
///
/// `secondary` nosi `action` (coral) jer je to boja glavne radnje. Bijeli tekst na njemu
/// pada AA (3,05:1), pa `onSecondary` ide na `onAction` — v. doc u `admin_colors.dart`.
ColorScheme _adminColorScheme(AdminPalette colors, Brightness brightness) =>
    ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.accentTint,
      onPrimaryContainer: colors.accentInk,
      secondary: colors.action,
      onSecondary: colors.onAction,
      secondaryContainer: colors.waitingTint,
      onSecondaryContainer: colors.waitingInk,
      // Tercijarna uloga je „čeka odgovor" — jedini status koji i van liste termina traži
      // svoju boju (brojač zahtjeva na dashboardu).
      tertiary: colors.positiveInk,
      onTertiary: colors.positiveTint,
      tertiaryContainer: colors.positiveTint,
      onTertiaryContainer: colors.positiveInk,
      error: colors.destructive,
      onError: colors.onDestructive,
      errorContainer: colors.destructive,
      onErrorContainer: colors.onDestructive,
      // `surface` je **radna pozadina**, ne kartica: to je ploha na kojoj ekran počinje.
      // Kartice su `surfaceContainer*` i bijele su.
      surface: colors.ground,
      onSurface: colors.ink,
      surfaceContainerLowest: colors.surface,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.neutralTint,
      surfaceContainerHighest: colors.neutralTint,
      // `textMuted` (#6B757B) ovdje **ne smije stajati**: na radnoj pozadini mjeri 4,35:1.
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.separator,
      inverseSurface: colors.ink,
      onInverseSurface: colors.ground,
    );

/// Pretapanje od ~150 ms, u oba smjera.
///
/// Trajanje rute ostaje Materialovih 300 ms (tema ga ne može mijenjati), pa se pretapanje
/// odradi u **prvoj polovini** animacije. `reverseCurve` isto radi pri povratku: bez njega
/// bi ekran pri zatvaranju 150 ms stajao nepomično, pa tek onda nestao.
class _Pretapanje extends PageTransitionsBuilder {
  const _Pretapanje();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
    ),
    child: child,
  );
}
