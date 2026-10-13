import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Klijentski profil — ime, telefon i prihvatanje uslova na identitetu (task 66).
///
/// **Ne šalje se ni salon ni identitet.** Oba RPC-a izvode osobu iz tokena, a profil nije
/// salonski podatak: salon ga dobija tek kroz svoj adresar, koji baza popunjava sama
/// (ADR-0030). Argument koji se ne šalje ne može se ni podmetnuti.
class ClientProfileRepository {
  const ClientProfileRepository(this._client);

  final SupabaseClient _client;

  /// Šta profilu fali. Osoblje i neprijavljen korisnik dobijaju `42501` → greška.
  Future<ClientProfileStatus> status() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('client_profile_status');
    if (rows.isEmpty) {
      throw const MappingError('`client_profile_status` nije vratio red');
    }
    return ClientProfileStatus.fromJson(rows.first as Map<String, dynamic>);
  });

  /// „Dopuni profil": telefon, prihvatanje važeće verzije uslova i ime kad ga nalog nema.
  ///
  /// `null` [phone] zadržava telefon koji nalog već ima — korisnik koji samo prihvata novu
  /// verziju uslova ga ne kuca ponovo. Neispravan unos baza odbija sa `PT400` i porukom na
  /// bosanskom.
  Future<void> complete({
    required bool acceptTerms,
    String? phone,
    String? name,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'complete_my_profile',
      params: {
        'p_phone': phone?.trim(),
        'p_accept_terms': acceptTerms,
        if (name != null && name.trim().isNotEmpty) 'p_name': name.trim(),
      },
    );
  });
}
