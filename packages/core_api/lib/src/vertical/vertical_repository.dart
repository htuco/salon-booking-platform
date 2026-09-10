import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Čita vertikalu salona: `vertical_packs` red plus `salons.terminology_override`.
///
/// Oba se dohvataju **jednim** upitom kroz embed po FK-u (`vertical_pack_key`) — dva
/// odvojena upita znače dva round-tripa na startu app-e i, gore, prozor u kojem je
/// terminologija na ekranu iz jedne vertikale a override iz druge.
///
/// Politika `public_verticals` daje `select` nad `vertical_packs` i `anon` roli, pa ovo radi
/// prije logina. Salon se ipak čita po `id`-u iz builda — tenant scope se ne izvodi iz
/// korisnika, nego iz `SALON_ID`-a kojim je build napravljen.
class VerticalRepository {
  const VerticalRepository(this._client);

  final SupabaseClient _client;

  /// Kolone se nabrajaju eksplicitno umjesto `*`: `select('*')` bi na svaku novu kolonu
  /// u `salons` (a to je najšira tabela u šemi) vukao podatke koje ovaj ekran ne treba.
  static const _query = '''
terminology_override,
vertical_packs!inner(key, display_name, terminology, default_settings, default_theme, feature_flags)
''';

  /// Vraća vertikalu za dati salon, ili [Vertical.fallback] ako red ne postoji.
  ///
  /// Ne baca na "nema reda": `SALON_ID` dolazi iz builda, pa salon koji nedostaje znači
  /// pogrešno konfigurisan tenant — app tada mora pokazati generic tekst, a ne prazan ekran.
  /// Mrežna greška se, za razliku od toga, propagira: pozivalac je razlikuje od praznog
  /// rezultata i može ponuditi "pokušaj ponovo".
  Future<Vertical> fetchForSalon(String salonId) async {
    final row = await _client
        .from('salons')
        .select(_query)
        .eq('id', salonId)
        .maybeSingle();

    return verticalFromSalonRow(row);
  }
}

/// Mapira `salons` red (sa `vertical_packs` embedom) na [Vertical].
///
/// Izdvojeno iz [VerticalRepository] da bi se moglo testirati bez lažiranja cijelog
/// PostgREST builder lanca — mapiranje je ono što nosi pravila, a `.from().select().eq()`
/// je tuđi kod koji test ne treba ponovo dokazivati.
@visibleForTesting
Vertical verticalFromSalonRow(Map<String, dynamic>? row) {
  if (row == null) return Vertical.fallback;

  final pack = row['vertical_packs'];
  if (pack is! Map) return Vertical.fallback;

  return Vertical.fromJson(
    pack.cast<String, dynamic>(),
    terminologyOverride: switch (row['terminology_override']) {
      final Map<String, dynamic> override => override,
      final Map override => override.cast<String, dynamic>(),
      _ => null,
    },
  );
}
