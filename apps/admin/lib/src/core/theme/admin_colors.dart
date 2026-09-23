/// Semanticka paleta admin aplikacije.
///
/// Vrijednosti su sRGB ekvivalenti OKLCH tokena iz dostavljene Tailwind teme. Paleta je
/// `ThemeExtension` zato što prilagođeni widgeti prate light/dark temu kao i Material widgeti.
///
/// ## [action] — coral, i dva mjesta gdje odstupa od CSS-a
///
/// [action] je `--secondary` (`oklch(0.6835 0.1676 34.7009)` → `#EE6C4D`) i nosi **glavnu
/// radnju**: `+ Novi termin`, `Potvrdi`, `Prijava`. [accent] (`--primary`) ostaje na
/// selekciji, aktivnoj stavci sidebara i podacima. Dvije stvari se nisu dale prepisati
/// doslovno:
///
/// - **[onAction] nije bijela.** CSS daje `--secondary-foreground: oklch(1 0 0)`, ali
///   bijela na `#EE6C4D` mjeri **3,05:1** i pada AA. Tekst je zato `--foreground`
///   (`#2C2C2C`, 4,58:1). Mjeri `theme_contrast_test.dart`.
/// - **Dark [action] nije roza.** CSS dark `--secondary` je
///   `oklch(0.8169 0.1032 19.5306)` → `#FFA8A8`, drugi ton, ne svjetliji coral — isto
///   dugme bi promijenilo karakter boje između modova. Zadržana je CSS svjetlina
///   (`L=0.8169`), uzeti su ton i zasićenje corala (`0.1676 34.7009`) → `#FF9776`,
///   8,15:1 na [ground]. Iz istog razloga i dark `waitingInk` ide na `#FF9776`.
library;

import 'package:flutter/material.dart';

@immutable
class AdminPalette extends ThemeExtension<AdminPalette> {
  const AdminPalette({
    required this.ink,
    required this.ground,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.action,
    required this.onAction,
    required this.border,
    required this.separator,
    required this.textSecondary,
    required this.textMuted,
    required this.destructive,
    required this.onDestructive,
    required this.accentInk,
    required this.accentTint,
    required this.sidebarRaised,
    required this.sidebarBackground,
    required this.sidebarAccentForeground,
    required this.sidebarSelected,
    required this.sidebarDivider,
    required this.breadcrumbSeparator,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.positiveTint,
    required this.positiveInk,
    required this.waitingTint,
    required this.waitingInk,
    required this.neutralTint,
    required this.cardEdge,
  });

  static const light = AdminPalette(
    ink: Color(0xFF2C2C2C),
    ground: Color(0xFFFCFCF9),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF3D5A80),
    onAccent: Color(0xFFFFFFFF),
    action: Color(0xFFEE6C4D),
    onAction: Color(0xFF2C2C2C),
    // Izmjereno iz `adminv2/export/3b`: obrub **kontrole** (polje pretrage, „Blokiraj
    // termin", „Odbij") je `#DEE2E6`, a linija između redova tabele i zahtjeva `#E2E2E2`.
    // Ranije su stajali `#E2E2E2` i `#F0F1F3` — linija je bila blijeđa od izvoza.
    border: Color(0xFFDEE2E6),
    separator: Color(0xFFE2E2E2),
    textSecondary: Color(0xFF666666),
    textMuted: Color(0xFF666666),
    destructive: Color(0xFFB83C3C),
    onDestructive: Color(0xFFFFFFFF),
    accentInk: Color(0xFF3D5A80),
    accentTint: Color(0xFFE9ECEF),
    // **Sidebar je taman i u svijetloj temi** (FE-401, `adminv2/export/3b`). Vrijednosti su
    // izmjerene iz izvoza, ne procijenjene, i sve odreda su **već postojeći tamni tokeni**:
    // pozadina `#141517`, aktivna stavka `#373A40`, aktivni tekst `#FFFFFF`, neaktivni
    // `#C1C2C5`. Radna površina ostaje svijetla (`#FBFBF8` u izvozu ≈ `ground`).
    //
    // Ovo razrješava protivrječnost **unutar** `prototype/admin/SPEC.md`: red 11 traži
    // „stalni tamni sidebar", a tabela tokena u redu 86 daje `#F8F9FA` za svijetlu temu.
    // Kod je do sada slijedio tabelu, `adminv2` slijedi red 11. Po
    // [ADR-0016](../../../../../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md)
    // izvoz je jači za vizual.
    sidebarRaised: Color(0xFF2C2E33),
    sidebarBackground: Color(0xFF141517),
    sidebarAccentForeground: Color(0xFFFFFFFF),
    sidebarSelected: Color(0xFF373A40),
    sidebarDivider: Color(0xFF373A40),
    breadcrumbSeparator: Color(0xFFE2E2E2),
    sidebarText: Color(0xFFC1C2C5),
    sidebarMuted: Color(0xFF909296),
    positiveTint: Color(0xFFE0F2F1),
    positiveInk: Color(0xFF004D40),
    waitingTint: Color(0xFFEE6C4D),
    waitingInk: Color(0xFF2C2C2C),
    neutralTint: Color(0xFFF0F1F3),
    // Kartica u `3b` **nema obrub kontrole** — rub je `#F4F4F1`, jedva tamniji od
    // `ground`. Sa `border` bi svaka kartica izgledala kao polje za unos.
    cardEdge: Color(0xFFF4F4F1),
  );

  static const dark = AdminPalette(
    ink: Color(0xFFDCDCDC),
    ground: Color(0xFF1A1B1E),
    surface: Color(0xFF25262B),
    accent: Color(0xFF91A7FF),
    onAccent: Color(0xFF1A1B1E),
    action: Color(0xFFFF9776),
    onAction: Color(0xFF1A1B1E),
    border: Color(0xFF373A40),
    separator: Color(0xFF373A40),
    textSecondary: Color(0xFF909296),
    textMuted: Color(0xFF909296),
    // `#F03E3E` je kao tekst na `surface` mjerio 3,93:1 (FE-502); ton iste crvene,
    // svjetliji, prolazi AA i kao tekst i ispod `onDestructive`.
    destructive: Color(0xFFFF6B6B),
    // CSS predlaze bijelu, ali ona na crvenoj daje ispod 4,5:1. Najtamniji token iz
    // iste palete zadrzava karakter teme i prolazi WCAG AA.
    onDestructive: Color(0xFF141517),
    accentInk: Color(0xFF91A7FF),
    accentTint: Color(0xFF2C2E33),
    sidebarRaised: Color(0xFF2C2E33),
    sidebarBackground: Color(0xFF141517),
    sidebarAccentForeground: Color(0xFFFFFFFF),
    sidebarSelected: Color(0xFF2C2E33),
    sidebarDivider: Color(0xFF373A40),
    breadcrumbSeparator: Color(0xFF373A40),
    sidebarText: Color(0xFFC1C2C5),
    sidebarMuted: Color(0xFF909296),
    positiveTint: Color(0xFF373A40),
    positiveInk: Color(0xFF63E6BE),
    waitingTint: Color(0xFF2C2E33),
    waitingInk: Color(0xFFFF9776),
    neutralTint: Color(0xFF2C2E33),
    cardEdge: Color(0xFF373A40),
  );

  final Color ink, ground, surface, accent, onAccent;
  final Color action, onAction;
  final Color border, separator, textSecondary, textMuted;
  final Color destructive, onDestructive, accentInk, accentTint;
  final Color sidebarRaised, sidebarSelected, sidebarDivider;
  final Color sidebarBackground, sidebarAccentForeground;
  final Color breadcrumbSeparator, sidebarText, sidebarMuted;
  final Color positiveTint, positiveInk, waitingTint, waitingInk, neutralTint;

  /// Rub kartice — mekši od [border], koji nose kontrole.
  final Color cardEdge;

  @override
  AdminPalette copyWith() => this;

  @override
  AdminPalette lerp(ThemeExtension<AdminPalette>? other, double t) {
    if (other is! AdminPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AdminPalette(
      ink: mix(ink, other.ink),
      ground: mix(ground, other.ground),
      surface: mix(surface, other.surface),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      action: mix(action, other.action),
      onAction: mix(onAction, other.onAction),
      border: mix(border, other.border),
      separator: mix(separator, other.separator),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      destructive: mix(destructive, other.destructive),
      onDestructive: mix(onDestructive, other.onDestructive),
      accentInk: mix(accentInk, other.accentInk),
      accentTint: mix(accentTint, other.accentTint),
      sidebarRaised: mix(sidebarRaised, other.sidebarRaised),
      sidebarBackground: mix(sidebarBackground, other.sidebarBackground),
      sidebarAccentForeground: mix(
        sidebarAccentForeground,
        other.sidebarAccentForeground,
      ),
      sidebarSelected: mix(sidebarSelected, other.sidebarSelected),
      sidebarDivider: mix(sidebarDivider, other.sidebarDivider),
      breadcrumbSeparator: mix(breadcrumbSeparator, other.breadcrumbSeparator),
      sidebarText: mix(sidebarText, other.sidebarText),
      sidebarMuted: mix(sidebarMuted, other.sidebarMuted),
      positiveTint: mix(positiveTint, other.positiveTint),
      positiveInk: mix(positiveInk, other.positiveInk),
      waitingTint: mix(waitingTint, other.waitingTint),
      waitingInk: mix(waitingInk, other.waitingInk),
      neutralTint: mix(neutralTint, other.neutralTint),
      cardEdge: mix(cardEdge, other.cardEdge),
    );
  }
}

extension AdminPaletteContext on BuildContext {
  AdminPalette get adminColors =>
      Theme.of(this).extension<AdminPalette>() ?? AdminPalette.light;
}

/// Light aliases for non-widget code and backwards-compatible token tests.
abstract final class AdminColors {
  static const ink = Color(0xFF2C2C2C),
      ground = Color(0xFFFCFCF9),
      surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFF3D5A80), onAccent = Color(0xFFFFFFFF);
  static const action = Color(0xFFEE6C4D), onAction = Color(0xFF2C2C2C);
  static const border = Color(0xFFDEE2E6), separator = Color(0xFFE2E2E2);
  static const textSecondary = Color(0xFF666666), textMuted = Color(0xFF666666);
  static const destructive = Color(0xFFB83C3C),
      destructiveTint = Color(0xFFC94C4C);
  static const accentInk = Color(0xFF3D5A80), accentTint = Color(0xFFE9ECEF);
  static const sidebarRaised = Color(0xFFE9ECEF),
      sidebarSelected = Color(0xFFE9ECEF);
  static const sidebarDivider = Color(0xFFDEE2E6),
      breadcrumbSeparator = Color(0xFFE2E2E2);
  static const sidebarText = Color(0xFF333333),
      sidebarMuted = Color(0xFF666666);
  static const positiveTint = Color(0xFFE0F2F1),
      positiveInk = Color(0xFF004D40);
  static const waitingTint = Color(0xFFEE6C4D), waitingInk = Color(0xFF2C2C2C);
  static const neutralTint = Color(0xFFF0F1F3);
}
