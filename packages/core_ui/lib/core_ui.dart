/// Design system — tema, tokeni i komponente zajedničke svim tenantima.
///
/// ## Tri pravila ovog sloja
///
/// 1. **`ThemeData` se pravi samo u `buildAppTheme`.** Brand boje su runtime podatak iz
///    backenda; svaka druga `ThemeData` u sistemu je mjesto gdje tenant boja tiho prestaje
///    da važi.
/// 2. **Nijedna komponenta ne piše literal boju ni literal razmak.** Boje dolaze iz
///    `ColorScheme` i `ThemeExtension`-a, razmaci iz `AppSpacing`. `Color(0xFF...)` u
///    komponenti znači da jedan tenant izgleda pogrešno, a niko to ne vidi do njegovog builda.
/// 3. **Komponente ne uvoze `core_domain`.** Primaju gotove stringove, ne modele —
///    formatiranje cijene i vremena zna ekran, koji jedini poznaje jezik i vertikalu.
///    Zato isti `core_ui` služi i klijentskoj i admin aplikaciji.
///
/// Kontrast nije preporuka nego provjera koja pada build: `contrast.dart` računa WCAG
/// odnos, a `theme_factory_test.dart` mjeri svaki par boja obje demo palete. Razlog je
/// konkretan — vlasnik salona bira boju sam i može izabrati žutu (`docs/02 §14`).
library;

export 'src/components/app_button.dart';
export 'src/components/app_dialog.dart';
export 'src/components/back_header.dart';
export 'src/components/bottom_nav_bar.dart';
export 'src/components/calendar_month.dart';
export 'src/components/empty_state.dart';
export 'src/components/link_row.dart';
export 'src/components/photo_frame.dart';
export 'src/components/selectable_row.dart';
export 'src/components/service_card.dart';
export 'src/components/skeleton_loader.dart';
export 'src/components/spec_card.dart';
export 'src/components/star_rating.dart';
export 'src/components/status_badge.dart';
export 'src/components/step_progress_bar.dart';
export 'src/components/time_slot_chip.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/contrast.dart';
export 'src/theme/page_transition.dart';
export 'src/theme/theme_factory.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/status_colors.dart';
export 'src/tokens/typography.dart';
