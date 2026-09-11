import 'package:flutter/material.dart';

/// Statusne boje — **fiksne, ne mijenjaju se po salonu** (`docs/02 §16`).
///
/// "Potvrđeno" mora biti zeleno u svakoj aplikaciji. Da statusi idu kroz tenant paletu,
/// salon koji izabere zelenu kao primarnu boju dobio bi ekran na kojem se potvrđen i
/// otkazan termin ne razlikuju — a to je stanje koje korisnik čita na brzinu, iz liste.
///
/// Zato ove boje **ne** ulaze u `ColorScheme`: da uđu, sljedeća komponenta bi ih pokupila
/// kao `theme.colorScheme.error` i izgubila razliku. Do njih se dolazi kroz
/// `Theme.of(context).extension<AppStatusColors>()`, odnosno `context.statusColors`.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.info,
    required this.onInfo,
    required this.blocked,
    required this.onBlocked,
  });

  /// Svijetla varijanta — čitljiva na svijetloj pozadini (`elegant_beauty`).
  ///
  /// Parovi `on*` su izračunati, ne pogođeni: v. test `status_colors_test.dart`, koji
  /// svaki par mjeri na WCAG AA.
  factory AppStatusColors.light() => const AppStatusColors(
    success: Color(0xFF1B7F4C),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5A00),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF1A5FB4),
    onInfo: Color(0xFFFFFFFF),
    blocked: Color(0xFF5C5C5C),
    onBlocked: Color(0xFFFFFFFF),
  );

  /// Tamna varijanta (`modern_barber`). Isti *pojmovi*, posvijetljeni tonovi — tamna
  /// pozadina traži svjetliji ton da bi odnos ostao iznad 4.5:1, pa tekst na njima
  /// postaje taman.
  factory AppStatusColors.dark() => const AppStatusColors(
    success: Color(0xFF6BD49B),
    onSuccess: Color(0xFF00210F),
    warning: Color(0xFFF0B86E),
    onWarning: Color(0xFF241700),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF2C0000),
    info: Color(0xFF8AB8F5),
    onInfo: Color(0xFF001A3D),
    blocked: Color(0xFFB0B0B0),
    onBlocked: Color(0xFF1A1A1A),
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color info;
  final Color onInfo;
  final Color blocked;
  final Color onBlocked;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? info,
    Color? onInfo,
    Color? blocked,
    Color? onBlocked,
  }) => AppStatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
    blocked: blocked ?? this.blocked,
    onBlocked: onBlocked ?? this.onBlocked,
  );

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      blocked: Color.lerp(blocked, other.blocked, t)!,
      onBlocked: Color.lerp(onBlocked, other.onBlocked, t)!,
    );
  }
}

/// Kratica do statusnih boja iz teme.
///
/// `context.statusColors.success` umjesto `Theme.of(context).extension<...>()!` — bez
/// nje bi svaka komponenta ponovila `!` i jedna bi ga prije ili kasnije zaboravila.
extension AppStatusColorsX on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light();
}
