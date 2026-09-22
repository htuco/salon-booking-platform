/// Imenovane teme iz `tenant.yaml` `branding.theme`.
///
/// Tema ne nosi brand boje — one dolaze iz backenda (`salons.primary_color`) i mijenjaju
/// se bez builda. Ovdje su samo **svjetlina i neutralna paleta**: pozadina, površina,
/// obrub. To su odluke koje se ne mijenjaju po salonu unutar iste vertikale, i zato
/// smiju biti u kodu.
library;

import 'package:flutter/material.dart';

/// Imenovana tema salona. Vrijednost dolazi kao string iz `tenant.yaml` i iz
/// `salons.theme`, pa `fromName` nikad ne baca — baza smije dodati temu koju app iz
/// storea ne poznaje, isto pravilo kao `AppointmentStatus.unknown`.
enum AppTheme {
  /// Tamna, za `barber` vertikalu.
  ///
  /// **Vrijednosti su prepisane iz `prototype/ui/SPEC.md` §Design Tokens, znak po znak.**
  /// Barber aplikacija mora biti 1:1 sa handoffom; ostale vertikale dobijaju svoj dizajn,
  /// pa njihove palete ostaju izvedene.
  modernBarber('modern_barber', Brightness.dark),

  /// Svijetla, za `beauty`. Topla bijela pozadina, roze brand boja.
  elegantBeauty('elegant_beauty', Brightness.light),

  /// Svijetla, hladna neutralna paleta za `dental`/`health`.
  ///
  /// TODO(dental-tipografija): dentalna vertikala traži i veći body font (17 sp, `docs/02 §14`) —
  /// to je promjena tipografije, ne samo palete. Ide uz task koji uvede `dental` vertikalu;
  /// ona je odgođena u `tasks/sprint-0/06-vertical-pack.md` i nema svoj task.
  clinicalCalm('clinical_calm', Brightness.light);

  const AppTheme(this.key, this.brightness);

  /// Ključ kakav stoji u `tenant.yaml` i u koloni `salons.theme`.
  final String key;
  final Brightness brightness;

  /// Nepoznato ime pada na `modernBarber` umjesto da sruši app.
  ///
  /// App u storeu je uvijek starija od baze: tema dodana migracijom poslije zadnjeg
  /// submissiona ne smije biti izuzetak pri startu.
  static AppTheme fromName(String? name) => values.firstWhere(
    (theme) => theme.key == name,
    orElse: () => AppTheme.modernBarber,
  );

  /// Neutralna paleta ove teme — sve osim brand boja.
  AppNeutrals get neutrals => switch (this) {
    // Svih devet vrijednosti dolazi iz `SPEC.md` §Design Tokens.
    AppTheme.modernBarber => const AppNeutrals(
      surface: Color(0xFF0F1012),
      surfaceContainer: Color(0xFF151719),
      photoGround: Color(0xFF1A1D20),
      navSurface: Color(0xFF0B0C0D),
      outline: Color(0xFF454B50),
      hairline: Color(0xFF33383C),
      strongOutline: Color(0xFF6B7176),
      textPrimary: Color(0xFFFFFFFF),
      textMuted: Color(0xFFC3C9CE),
      textDisabled: Color(0xFF8B9298),
      disabledFill: Color(0xFF2A2E32),
      scrim: Color(0xB80B0C0D),
      error: Color(0xFFFF8A80),
      onError: Color(0xFF2C0000),
    ),
    AppTheme.elegantBeauty => const AppNeutrals(
      surface: Color(0xFFFFFBFB),
      surfaceContainer: Color(0xFFF6EDED),
      photoGround: Color(0xFFF0E4E4),
      navSurface: Color(0xFFF9F1F1),
      outline: Color(0xFFE0D3D3),
      hairline: Color(0xFFEBDEDE),
      strongOutline: Color(0xFFBFA9A9),
      textPrimary: Color(0xFF1F1A1A),
      textMuted: Color(0xFF5F5555),
      textDisabled: Color(0xFF8A7C7C),
      disabledFill: Color(0xFFEDE2E2),
      scrim: Color(0xB81F1A1A),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
    ),
    AppTheme.clinicalCalm => const AppNeutrals(
      surface: Color(0xFFFBFCFD),
      surfaceContainer: Color(0xFFEDF2F5),
      photoGround: Color(0xFFE4EBEF),
      navSurface: Color(0xFFF2F6F8),
      outline: Color(0xFFD2DCE2),
      hairline: Color(0xFFE3EAEE),
      strongOutline: Color(0xFFA9B7C0),
      textPrimary: Color(0xFF16212B),
      textMuted: Color(0xFF52616E),
      textDisabled: Color(0xFF7D8A94),
      disabledFill: Color(0xFFE6EDF1),
      scrim: Color(0xB816212B),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
    ),
  };
}

/// Neutralne boje jedne teme. Namjerno bez brand boja — one su runtime podatak.
@immutable
class AppNeutrals {
  const AppNeutrals({
    required this.surface,
    required this.surfaceContainer,
    required this.photoGround,
    required this.navSurface,
    required this.outline,
    required this.hairline,
    required this.strongOutline,
    required this.textPrimary,
    required this.textMuted,
    required this.textDisabled,
    required this.disabledFill,
    required this.scrim,
    required this.error,
    required this.onError,
  });

  /// Pozadina ekrana. `SPEC.md`: `#0F1012`.
  final Color surface;

  /// Izdignuta kartica. `SPEC.md`: `#151719`.
  final Color surfaceContainer;

  /// Podloga okvira za fotografiju. `SPEC.md`: `#1A1D20` — tamnija od kartice, da se
  /// prazan okvir vidi kao okvir, a ne kao rupa u kartici.
  final Color photoGround;

  /// Podloga donje navigacije. `SPEC.md` je razdvaja od pozadine ekrana (`#0B0C0D`
  /// naspram `#0F1012`) — traka je **udubljena**, ne izdignuta, jer sistem nema sjenki
  /// pa dubinu nosi samo razlika tona i hairline iznad nje.
  ///
  /// U svijetlim temama razlika ide u suprotnom smjeru: pozadina je već skoro bijela, pa
  /// traka mora biti nijansu tamnija da se uopšte vidi kao zasebna ploha.
  final Color navSurface;

  /// Granica kartice i reda koji se bira. `SPEC.md`: `#454B50`.
  final Color outline;

  /// Razdjelnik unutar grupe redova. `SPEC.md`: `#33383C` — **tanji od [outline]**.
  /// Ista boja za oboje bi grupu redova pretvorila u mrežu.
  final Color hairline;

  /// Jača granica: sekundarno dugme, modal, bottom sheet. `SPEC.md`: `#6B7176`.
  final Color strongOutline;

  final Color textPrimary;

  /// Sekundarni tekst. Mjeri se na `surface` isto kao i primarni — "prigušeno" ne znači
  /// ispod praga; `docs/02 §14` traži AA za **sav** tekst.
  final Color textMuted;

  /// Tekst onemogućenog dugmeta. `SPEC.md`: `#8B9298`.
  final Color textDisabled;

  /// Ispuna onemogućenog dugmeta. `SPEC.md`: `#2A2E32`.
  final Color disabledFill;

  /// Zastor ispod modala i bottom sheeta. `SPEC.md`: `rgba(6,7,8,.72)` — otud alfa
  /// `0xB8`. Ide **uz** `blur(1.5px)`, ne umjesto njega.
  ///
  /// Po temi je različit jer zastor mora biti tamniji od onoga što zatamnjuje: ista
  /// vrijednost na svijetloj temi ostavlja modal da lebdi nad sivilom bez dubine.
  final Color scrim;

  /// Boja greške i destruktivne radnje.
  ///
  /// Stajala je kao heks u `theme_factory.dart` i bila **ista u sve tri teme**, pa je
  /// svijetla tema dobijala tamnu `#FF8A80` logiku. Sada je token kao i ostalo.
  final Color error;

  /// Tekst na [error]. Bira se za kontrast, ne za kontrast sa pozadinom ekrana.
  final Color onError;
}
