/// Imenovane teme iz `tenant.yaml` `branding.theme`.
///
/// Tema ne nosi brand boje — one dolaze iz backenda (`salons.primary_color`) i mijenjaju
/// se bez builda. Ovdje su **svjetlina, neutralna paleta, par pisama i način izbora**
/// (ADR-0025). To su odluke koje se ne mijenjaju po salonu unutar iste vertikale, i zato
/// smiju biti u kodu.
library;

import 'package:flutter/material.dart';

import '../tokens/typography.dart';

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

  /// Svijetla, za `beauty`. Topla bijela pozadina, Jost, izbor u brand boji.
  ///
  /// **Neutrale su prepisane iz `prototype/beauty/README.md` §Design Tokens.**
  elegantBeauty('elegant_beauty', Brightness.light),

  /// Svijetla, topla, za masažu (`health`). Bjelokost i lan, Newsreader + Public Sans,
  /// izbor u brand boji.
  ///
  /// **Neutrale su prepisane iz `prototype/masaza/SPEC.md` §Tokeni, light** (ADR-0026).
  warmWellness('warm_wellness', Brightness.light),

  /// Svijetla, hladna, za fizioterapiju (`health`). Isti oblik i pisma kao [warmWellness],
  /// druge neutrale.
  ///
  /// **Neutrale su prepisane iz `prototype/masaza/fizio/SPEC.md` §Tokeni, light** (ADR-0026).
  ///
  /// TODO(dental-tipografija): dentalna vertikala traži i veći body font (17 sp, `docs/02 §14`) —
  /// to je promjena tipografije, ne samo palete. Ide uz task koji uvede `dental` vertikalu;
  /// ona je van Sprinta 5 i tada dobija i svoju odluku o temi (ADR-0026).
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

  /// Par pisama teme (ADR-0025). Skala je ista za sve — mijenja se samo pismo.
  AppFonts get fonts => switch (this) {
    AppTheme.modernBarber => AppFonts.classic,
    AppTheme.elegantBeauty => AppFonts.jost,
    AppTheme.warmWellness => AppFonts.newsreader,
    AppTheme.clinicalCalm => AppFonts.newsreader,
  };

  /// Da li izbor (slot, dan, red, progres, tab traka) nosi brand boju.
  ///
  /// `false` je barberov oblik iz `prototype/ui/SPEC.md`: izbor je invertovan u boji teksta.
  /// `true` znači i da se `primary` **izvodi** iz brand boje (`BrandRoles.derive`) umjesto
  /// da se koristi sirova — v. ADR-0025.
  bool get brandSelection => switch (this) {
    AppTheme.modernBarber => false,
    AppTheme.elegantBeauty => true,
    AppTheme.warmWellness => true,
    AppTheme.clinicalCalm => true,
  };

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
    // Topla bijela (lan), ne roza — da ne zaprlja zlatni i šljiva brand drugog salona.
    AppTheme.elegantBeauty => const AppNeutrals(
      surface: Color(0xFFFCF9F6),
      surfaceContainer: Color(0xFFF5EFEA),
      photoGround: Color(0xFFECE4DC),
      navSurface: Color(0xFFF8F3EE),
      outline: Color(0xFFDDD2C9),
      hairline: Color(0xFFEAE2DA),
      strongOutline: Color(0xFF9A8D83),
      textPrimary: Color(0xFF1F1A17),
      textMuted: Color(0xFF5E554F),
      textDisabled: Color(0xFF8F847B),
      disabledFill: Color(0xFFECE6E0),
      // Handoff: `rgba(31,26,23,.52)`. Blur ispod ostaje (ADR-0025), iako ga handoff skida.
      scrim: Color(0x851F1A17),
      error: Color(0xFFA3352D),
      onError: Color(0xFFFFFFFF),
    ),
    // Handoff ima tri plohe (`background`, `surface`, `surfaceRaised`); ovdje su dvije.
    // `background` je pozadina ekrana, `surface` kartica i tab bar. `surfaceRaised` (bijela)
    // je modal, koji u ovom sistemu stoji na `surfaceContainer` kao i u ostalim temama.
    AppTheme.warmWellness => const AppNeutrals(
      surface: Color(0xFFF4EDE3),
      surfaceContainer: Color(0xFFFAF5EE),
      photoGround: Color(0xFFE5DACA),
      navSurface: Color(0xFFFAF5EE),
      outline: Color(0xFFD0C4B3),
      hairline: Color(0xFFE4DACC),
      strongOutline: Color(0xFF8A8072),
      textPrimary: Color(0xFF2D2925),
      textMuted: Color(0xFF6A6259),
      textDisabled: Color(0xFFA39B90),
      disabledFill: Color(0xFFE7DED1),
      // Handoff: `rgba(45,41,37,.52)`.
      scrim: Color(0x852D2925),
      error: Color(0xFF9A3B2E),
      onError: Color(0xFFFFFFFF),
    ),
    // Isto mapiranje kao [warmWellness]. Topli sand na `photoGround` je namjeran — handoff
    // ga zove „jedino mjesto topline".
    AppTheme.clinicalCalm => const AppNeutrals(
      surface: Color(0xFFF4F7F5),
      surfaceContainer: Color(0xFFFFFFFF),
      photoGround: Color(0xFFE9E1D4),
      navSurface: Color(0xFFFFFFFF),
      outline: Color(0xFFBCC9C4),
      hairline: Color(0xFFDDE5E1),
      strongOutline: Color(0xFF7E8B87),
      textPrimary: Color(0xFF1F2929),
      textMuted: Color(0xFF586264),
      textDisabled: Color(0xFF9AA5A2),
      disabledFill: Color(0xFFE4EAE7),
      // Handoff: `rgba(31,41,41,.52)`.
      scrim: Color(0x851F2929),
      error: Color(0xFF9A3B2E),
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
