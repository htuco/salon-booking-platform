/// Uloge izbora — čime komponenta crta **izabrano** (ADR-0025).
///
/// Barber (`prototype/ui/SPEC.md`) izbor invertuje u boji teksta: izabrani slot je bijel sa
/// tamnim tekstom, traka u tab baru je bijela. Beauty (`prototype/beauty/README.md`) izbor
/// nosi brand bojom. Komponenta ne smije znati koja je tema — zato čita ove uloge, a tema
/// odlučuje šta u njima stoji.
library;

import 'package:flutter/material.dart';

import 'contrast.dart';
import 'oklch.dart';

@immutable
class AppSelectionColors extends ThemeExtension<AppSelectionColors> {
  const AppSelectionColors({
    required this.selected,
    required this.onSelected,
    required this.selectedPressed,
    required this.selectedContainer,
    required this.accentLine,
    required this.accentInk,
  });

  /// Izbor u boji teksta — barberov oblik. Vrijednosti su **tačno** one koje su komponente
  /// crtale prije ove klase, pa barber ostaje isti.
  factory AppSelectionColors.inverted(ColorScheme scheme) => AppSelectionColors(
    selected: scheme.onSurface,
    onSelected: scheme.surface,
    selectedPressed: scheme.onSurface,
    // `SPEC.md`: izabrani red je `rgba(242,242,243,.10)` preko podloge.
    selectedContainer: Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.10),
      scheme.surface,
    ),
    accentLine: scheme.onSurface,
    accentInk: scheme.onSurface,
  );

  /// Ispuna izabranog slota i dana, pređeni korak, kvačica izabranog reda, rub izabranog.
  final Color selected;

  /// Tekst i ikona na [selected].
  final Color onSelected;

  /// [selected] dok je pritisnut.
  final Color selectedPressed;

  /// Podloga izabranog reda (usluga, radnik).
  final Color selectedContainer;

  /// Tanka oznaka: traka 3px u tab baru. Traži ≥ 3:1 (non-text), ne 4.5:1.
  final Color accentLine;

  /// Aktivna ikona i labela u tab baru — tekst, pa ≥ 4.5:1.
  final Color accentInk;

  @override
  AppSelectionColors copyWith({
    Color? selected,
    Color? onSelected,
    Color? selectedPressed,
    Color? selectedContainer,
    Color? accentLine,
    Color? accentInk,
  }) => AppSelectionColors(
    selected: selected ?? this.selected,
    onSelected: onSelected ?? this.onSelected,
    selectedPressed: selectedPressed ?? this.selectedPressed,
    selectedContainer: selectedContainer ?? this.selectedContainer,
    accentLine: accentLine ?? this.accentLine,
    accentInk: accentInk ?? this.accentInk,
  );

  @override
  AppSelectionColors lerp(covariant AppSelectionColors? other, double t) {
    if (other == null) return this;
    return AppSelectionColors(
      selected: Color.lerp(selected, other.selected, t)!,
      onSelected: Color.lerp(onSelected, other.onSelected, t)!,
      selectedPressed: Color.lerp(selectedPressed, other.selectedPressed, t)!,
      selectedContainer: Color.lerp(
        selectedContainer,
        other.selectedContainer,
        t,
      )!,
      accentLine: Color.lerp(accentLine, other.accentLine, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
    );
  }
}

/// Brand uloge izvedene iz jedne boje salona — algoritam iz `prototype/beauty/README.md`.
///
/// Salon daje `brand` (i opcionalno `secondary`); sve ostalo je izračunato, pa i salon koji
/// izabere svijetlu pudrastu boju dobije dugme sa čitljivim bijelim tekstom.
@immutable
class BrandRoles {
  const BrandRoles({
    required this.brandLine,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.brandContainer,
    required this.brandInk,
  });

  /// [text] je boja teksta u izabranom redu (`textPrimary` teme). Sekundarna boja salona
  /// postaje podloga tog reda samo ako tekst na njoj ostaje čitljiv — barberova `#171717`
  /// prenesena na beauty temu bi inače dala crno na crnom.
  factory BrandRoles.derive({
    required Color brand,
    required Color surface,
    required Color text,
    Color? secondary,
  }) {
    const bijela = Color(0xFFFFFFFF);
    final oklch = Oklch.fromColor(brand);

    final primary = darkenTo(brand, bijela, 4.6);
    final pritisnuta = Oklch.fromColor(primary);
    final brandContainer = secondary != null && meetsAa(text, secondary)
        ? secondary
        : Oklch(0.968, _min(oklch.c * 0.2, 0.018), oklch.h).toColor();

    return BrandRoles(
      brandLine: darkenTo(brand, surface, 3.05),
      primary: primary,
      primaryPressed: pritisnuta.withL(pritisnuta.l - 0.06).toColor(),
      onPrimary: bijela,
      brandContainer: brandContainer,
      brandInk: darkenTo(brand, brandContainer, 4.6),
    );
  }

  /// Traka u tab baru, fokus prsten, marker „danas". ≥ 3:1 na `surface`.
  final Color brandLine;

  /// Primarno dugme, izabrani slot i dan, progres. ≥ 4.5:1 sa [onPrimary].
  final Color primary;
  final Color primaryPressed;

  /// Uvijek bijela — handoff je izričit.
  final Color onPrimary;

  /// Podloga izabranog reda.
  final Color brandContainer;

  /// Brand kao tekst: linkovi, „Izabrano", aktivna ikona. ≥ 4.5:1 na [brandContainer].
  final Color brandInk;

  /// [navSurface] je podloga tab bara. `brandInk` je mjeren na `brandContainer`, a tab bar
  /// je nijansu tamniji — bez ovog koraka roze aktivna labela padne na ~4.46:1.
  AppSelectionColors toSelection({required Color navSurface}) =>
      AppSelectionColors(
        selected: primary,
        onSelected: onPrimary,
        selectedPressed: primaryPressed,
        selectedContainer: brandContainer,
        accentLine: brandLine,
        accentInk: darkenTo(brandInk, navSurface, 4.6),
      );
}

double _min(double a, double b) => a < b ? a : b;

/// Kratica do uloga izbora. Tema bez extensiona (admin) pada na barberov oblik, pa se
/// komponenta ponaša isto kao prije ADR-0025.
extension AppSelectionColorsX on BuildContext {
  AppSelectionColors get selectionColors {
    final theme = Theme.of(this);
    return theme.extension<AppSelectionColors>() ??
        AppSelectionColors.inverted(theme.colorScheme);
  }
}
