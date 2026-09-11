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
  /// Tamna, za `barber` vertikalu. Zlatna brand boja na skoro-crnoj pozadini.
  modernBarber('modern_barber', Brightness.dark),

  /// Svijetla, za `beauty`. Topla bijela pozadina, roze brand boja.
  elegantBeauty('elegant_beauty', Brightness.light),

  /// Svijetla, hladna neutralna paleta za `dental`/`health`.
  ///
  /// TODO(task-12): dentalna vertikala traži i veći body font (17 sp, `docs/02 §14`) —
  /// to je promjena tipografije, ne samo palete, pa ide uz taj task.
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
    AppTheme.modernBarber => const AppNeutrals(
      surface: Color(0xFF171717),
      surfaceContainer: Color(0xFF222222),
      outline: Color(0xFF3A3A3A),
      textPrimary: Color(0xFFF5F5F5),
      textMuted: Color(0xFFB5B5B5),
    ),
    AppTheme.elegantBeauty => const AppNeutrals(
      surface: Color(0xFFFFFBFB),
      surfaceContainer: Color(0xFFF6EDED),
      outline: Color(0xFFE0D3D3),
      textPrimary: Color(0xFF1F1A1A),
      textMuted: Color(0xFF5F5555),
    ),
    AppTheme.clinicalCalm => const AppNeutrals(
      surface: Color(0xFFFBFCFD),
      surfaceContainer: Color(0xFFEDF2F5),
      outline: Color(0xFFD2DCE2),
      textPrimary: Color(0xFF16212B),
      textMuted: Color(0xFF52616E),
    ),
  };
}

/// Neutralne boje jedne teme. Namjerno bez brand boja — one su runtime podatak.
@immutable
class AppNeutrals {
  const AppNeutrals({
    required this.surface,
    required this.surfaceContainer,
    required this.outline,
    required this.textPrimary,
    required this.textMuted,
  });

  final Color surface;
  final Color surfaceContainer;
  final Color outline;
  final Color textPrimary;

  /// Sekundarni tekst. Mjeri se na `surface` isto kao i primarni — "prigušeno" ne znači
  /// ispod praga; `docs/02 §14` traži AA za **sav** tekst.
  final Color textMuted;
}
