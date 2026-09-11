import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Čita katalog usluga salona iz `public.services`.
///
/// Politika `public_active` propušta roli `anon` samo `is_active` redove aktivnog salona,
/// pa lista koju klijent dobije **već** ne sadrži ugašene usluge. Ne filtriraj ih ponovo u
/// Dartu: dupli filter sakrije dan kad politika prestane raditi.
class ServiceRepository {
  const ServiceRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, salon_id, name, description, category, price, duration_minutes';

  /// Sve aktivne usluge salona, sortirane po kategoriji pa po imenu — isti redoslijed koji
  /// ekran prikazuje, da se ne sortira ponovo na klijentu.
  ///
  /// Prazan salon vraća praznu listu, ne grešku: salon bez usluga je uredno stanje
  /// (tek postavljen tenant), a ekran za to ima prazno stanje.
  Future<List<Service>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('services')
        .select(_columns)
        .eq('salon_id', salonId)
        .order('category')
        .order('name');

    return servicesFromRows(rows);
  });
}

/// Mapira `services` redove na [Service] — v. `salonFromRow` za razlog izdvajanja.
@visibleForTesting
List<Service> servicesFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan `services` red', cause: error);
  }
}
