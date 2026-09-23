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
      'id, salon_id, name, description, category, price, duration_minutes, slot_step_minutes, '
      'is_active, image_url';

  /// Sve aktivne usluge salona, sortirane **uzlazno** po kategoriji pa po imenu — isti
  /// redoslijed koji ekran prikazuje, da se ne sortira ponovo na klijentu.
  ///
  /// Smjer se navodi eksplicitno jer `order` u `postgrest`-u podrazumijeva **silazno**
  /// (`ascending = false`), pa je dokumentovani uzlazni ugovor svih ovih mjeseci bio laž.
  /// Sa četiri demo usluge to niko nije primijetio.
  ///
  /// **Uzlazno nije isto što i ispravno za izlog.** Na salonu sa osam usluga i četiri
  /// kategorije, uzlazno daje „Brada" i „Njega" na vrh — a Početna pokazuje samo prve tri,
  /// pa u izlog ide brijanje umjesto šišanja. `services` nema kolonu za ručni redoslijed;
  /// dok je ne dobije (`sort_order` migracija), ovaj poredak je samo **predvidiv**, ne dobar.
  ///
  /// Prazan salon vraća praznu listu, ne grešku: salon bez usluga je uredno stanje
  /// (tek postavljen tenant), a ekran za to ima prazno stanje.
  Future<List<Service>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('services')
        .select(_columns)
        .eq('salon_id', salonId)
        // **`ascending: true` je obavezan.** `PostgrestTransformBuilder.order` ima
        // `ascending = false` kao default (postgrest 2.9.1,
        // `postgrest_transform_builder.dart:104`), pa `.order('category')` šalje
        // `category.desc` — obrnuto od onoga što dokumentacija iznad obećava.
        .order('category', ascending: true)
        .order('name', ascending: true);

    return servicesFromRows(rows);
  });

  /// Kreira uslugu kroz validirani RPC. [price] je decimalni tekst (`15.00`), ne
  /// `double`: JSON floating point ne smije biti izvor vrijednosti koja završava u
  /// Postgres `numeric(10,2)` koloni.
  Future<Service> create({
    required String salonId,
    required String name,
    required String description,
    required String category,
    required String price,
    required int durationMinutes,
    String? imageUrl,
    int? slotStepMinutes,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'create_service',
      params: {
        'p_salon_id': salonId,
        'p_name': name,
        'p_description': description,
        'p_category': category,
        'p_price': price,
        'p_duration_minutes': durationMinutes,
        'p_image_url': imageUrl,
        // Uvijek se šalje: `null` znači salonski korak, ne „ne diraj".
        'p_slot_step_minutes': slotStepMinutes,
      },
    );
    return serviceFromRpc(row);
  });

  Future<Service> update({
    required String salonId,
    required String serviceId,
    required String name,
    required String description,
    required String category,
    required String price,
    required int durationMinutes,
    String? imageUrl,
    int? slotStepMinutes,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'update_service',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_name': name,
        'p_description': description,
        'p_category': category,
        'p_price': price,
        'p_duration_minutes': durationMinutes,
        'p_image_url': imageUrl,
        // Uvijek se šalje: `null` znači salonski korak, ne „ne diraj".
        'p_slot_step_minutes': slotStepMinutes,
      },
    );
    return serviceFromRpc(row);
  });

  Future<Service> setActive({
    required String salonId,
    required String serviceId,
    required bool isActive,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'set_service_active',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_is_active': isActive,
      },
    );
    return serviceFromRpc(row);
  });
}

/// PostgREST za `returns public.services` može vratiti mapu ili listu sa jednom mapom,
/// zavisno od verzije klijenta/content profilea. Oba oblika su isti RPC ugovor.
@visibleForTesting
Service serviceFromRpc(dynamic value) {
  final dynamic row = value is List && value.length == 1 ? value.single : value;
  if (row is! Map<String, dynamic>) {
    throw MappingError('Neispravan `services` RPC odgovor');
  }
  return servicesFromRows([row]).single;
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
