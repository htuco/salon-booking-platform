/// Statusne boje admina, kao `ThemeExtension`.
///
/// ## Zašto ne u `ColorScheme`
///
/// Da uđu kao `error`/`tertiary`, prva sljedeća komponenta bi ih pokupila kao svoje
/// (`Chip`, `SnackBar`, `TextField` sa greškom) i „potvrđeno" bi se pojavilo na mjestu
/// koje nema veze sa statusom termina. Do njih se zato dolazi imenom, kroz
/// `Theme.of(context).extension<AdminStatusColors>()`.
///
/// ## Zašto uopšte postoje, kad admin nije brandiran
///
/// Razlog je drugi nego u `core_ui`. Tamo statusne boje stoje izvan teme da ih **tenant
/// paleta ne progura** — salon koji izabere zelenu ne smije dobiti ekran na kojem se
/// potvrđen i otkazan termin ne razlikuju. Ovdje tenanta nema; ovdje je razlog da statusi
/// ostanu **jedan skup parova**, umjesto da svaki ekran bira svoju nijansu zelene.
///
/// ## Boja nije jedini nosilac
///
/// Uz svaku oznaku ide tekst (`SPEC.md`, „Raspored i komponente"; WCAG 1.4.1). Parovi
/// ispod su izmjereni na AA u `theme_contrast_test.dart` — tri su iz canvasa, dva su
/// izvedena jer ih handoff ne crta.
library;

import 'package:flutter/material.dart';

import 'admin_colors.dart';

/// Jedan ton statusa: podloga oznake i tekst na njoj.
@immutable
class AdminStatusTone {
  const AdminStatusTone({required this.background, required this.foreground});

  /// Podloga pilule.
  final Color background;

  /// Tekst i ikona na [background].
  final Color foreground;

  AdminStatusTone lerpTo(AdminStatusTone other, double t) => AdminStatusTone(
    background: Color.lerp(background, other.background, t)!,
    foreground: Color.lerp(foreground, other.foreground, t)!,
  );
}

/// Parovi boja za statuse termina.
@immutable
class AdminStatusColors extends ThemeExtension<AdminStatusColors> {
  const AdminStatusColors({
    required this.positive,
    required this.waiting,
    required this.neutral,
    required this.negative,
    required this.negativeQuiet,
  });

  /// Handoff vrijednosti; tri izmjerene iz canvasa, dvije izvedene.
  factory AdminStatusColors.standard() => const AdminStatusColors(
    // Canvas: `background:#e8f3ec;color:#2f6b47` — „Potvrđeno". 5,57:1.
    positive: AdminStatusTone(
      background: AdminColors.positiveTint,
      foreground: AdminColors.positiveInk,
    ),
    // Canvas: `background:#fdf1dd;color:#8a5a12` — „Na čekanju". 5,29:1.
    waiting: AdminStatusTone(
      background: AdminColors.waitingTint,
      foreground: AdminColors.waitingInk,
    ),
    // Canvas: `background:#eef1f3;color:#6b757b` — „Završeno". **Taj par mjeri 4,15:1 i
    // pada AA**, pa je tekst spušten na `AdminColors.textSecondary` (5,26:1). Razlika je
    // jedna nijansa sive i ne vidi se; pad ispod praga se vidi tek kome smeta.
    neutral: AdminStatusTone(
      background: AdminColors.neutralTint,
      foreground: AdminColors.textSecondary,
    ),
    // Izvedeno: canvas ne crta otkazan termin. Uzet je destruktivni par iz SPEC tabele,
    // isti koji nosi upozorenja. 5,48:1.
    negative: AdminStatusTone(
      background: AdminColors.destructiveTint,
      foreground: AdminColors.destructive,
    ),
    // Izvedeno: „nije se pojavio" nije otkazivanje i ne smije izgledati isto — otkazao je
    // neko, a ovo se prosto desilo. Neutralna podloga, destruktivan tekst. 5,68:1.
    negativeQuiet: AdminStatusTone(
      background: AdminColors.neutralTint,
      foreground: AdminColors.destructive,
    ),
  );

  /// Potvrđen termin.
  final AdminStatusTone positive;

  /// Zahtjev koji čeka odgovor salona.
  final AdminStatusTone waiting;

  /// Završen termin i nepoznat status iz novije baze.
  final AdminStatusTone neutral;

  /// Otkazan termin, destruktivna radnja.
  final AdminStatusTone negative;

  /// Klijent se nije pojavio.
  final AdminStatusTone negativeQuiet;

  @override
  AdminStatusColors copyWith({
    AdminStatusTone? positive,
    AdminStatusTone? waiting,
    AdminStatusTone? neutral,
    AdminStatusTone? negative,
    AdminStatusTone? negativeQuiet,
  }) => AdminStatusColors(
    positive: positive ?? this.positive,
    waiting: waiting ?? this.waiting,
    neutral: neutral ?? this.neutral,
    negative: negative ?? this.negative,
    negativeQuiet: negativeQuiet ?? this.negativeQuiet,
  );

  @override
  AdminStatusColors lerp(ThemeExtension<AdminStatusColors>? other, double t) {
    if (other is! AdminStatusColors) return this;
    return AdminStatusColors(
      positive: positive.lerpTo(other.positive, t),
      waiting: waiting.lerpTo(other.waiting, t),
      neutral: neutral.lerpTo(other.neutral, t),
      negative: negative.lerpTo(other.negative, t),
      negativeQuiet: negativeQuiet.lerpTo(other.negativeQuiet, t),
    );
  }
}

/// Kratica do statusnih boja. Bez nje svaki ekran piše `extension<...>()!` i sam bira šta
/// kad je `null`.
extension AdminStatusColorsX on BuildContext {
  AdminStatusColors get statusColors =>
      Theme.of(this).extension<AdminStatusColors>() ??
      AdminStatusColors.standard();
}
