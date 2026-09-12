import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Klijent prijavljenog korisnika u **jednom** salonu.
///
/// ## `insert` sa klijenta ne postoji
///
/// `customers` red nastaje **isključivo kroz `public.ensure_customer`** — `security definer`
/// funkciju iz taska 14. Tabela nema `insert` grant za `authenticated`, pa drugog puta
/// nema ni slučajno (`.claude/docs/security.md`). Funkcija identitet izvodi iz JWT-a i
/// traži da se `p_salon_id` poklopi sa `x-salon-id` headerom; klijent ne bira ni jedno ni
/// drugo.
///
/// [ensureCustomer] je zato jedina metoda koja piše, a [currentCustomerId] ostaje za
/// mjesta koja samo žele znati postoji li red — bez pravljenja novog.
///
/// ## Zašto se ne šalje `auth_identity_id`
///
/// Politika `own_customer` traži `private.owns_identity(auth_identity_id)` i
/// `salon_id = private.client_salon_id()` — oboje izvodi **baza**, iz JWT-a i iz
/// `x-salon-id` headera. Klijent koji bi sam slao `auth_identity_id` ne bi dobio ništa
/// više (RLS ga ionako presijeca), a upit bi izgledao kao da identitet bira pozivalac.
/// To je tačno ona navika zbog koje curenje između salona nastane u sljedećem upitu.
class CustomerRepository {
  const CustomerRepository(this._client);

  final SupabaseClient _client;

  /// `customers.id` prijavljenog korisnika u [salonId], ili `null` ako reda nema.
  ///
  /// `maybeSingle` je namjeran: `unique(salon_id, auth_identity_id)` garantuje najviše
  /// jedan red, a prazan rezultat je očekivano stanje prije prve rezervacije — ne
  /// [NotFoundError], koji bi ekran prikazao kao grešku.
  ///
  /// Nula redova vrati i RLS kad niko nije prijavljen, i to je ispravno: neprijavljen
  /// korisnik **nema** klijenta, pa `null` opisuje oba slučaja tačno.
  Future<String?> currentCustomerId(String salonId) => guard(() async {
    final row = await _client
        .from('customers')
        .select('id')
        .eq('salon_id', salonId)
        .maybeSingle();

    final id = row?['id'];
    return id is String ? id : null;
  });

  /// `customers.id` prijavljenog korisnika u [salonId], praveći red ako ga nema.
  ///
  /// Idempotentna — funkcija radi `on conflict do nothing`, pa je zove svaka prijava bez
  /// straha od duplikata. Ime se šalje samo kao prijedlog: red koji već postoji zadržava
  /// ono što u njemu piše, jer ga je salon možda ispravio u svom adresaru.
  ///
  /// **`salonId` se ne šalje kao dokaz nego kao namjera.** Ono što stvarno ograničava
  /// poziv je `x-salon-id` header, koji `bootstrap()` postavlja na klijentu i koji baza
  /// poredi sa ovim argumentom. Neslaganje je `42501` → [NotFoundError], isto kao tuđi
  /// red — razlika bi bila način da se nabrajaju tuđi saloni.
  Future<String> ensureCustomer(String salonId, {String? name}) =>
      guard(() async {
        final row = await _client.rpc<Map<String, dynamic>>(
          'ensure_customer',
          params: {'p_salon_id': salonId, 'p_name': ?name},
        );

        return customerIdFromRow(row);
      });
}

/// Vadi `id` iz reda koji vraća `public.ensure_customer`.
///
/// Izdvojeno zbog testa i zbog jednog konkretnog ishoda: funkcija je deklarisana kao
/// `returns public.customers`, pa PostgREST na njen `null` vrati **prazan objekat**, ne
/// grešku. Bez ove provjere bi `book_appointment` dobio `null` kao `customerId` i pao
/// kasnije, sa porukom koja ne govori gdje je stvarno puklo.
@visibleForTesting
String customerIdFromRow(Map<String, dynamic>? row) {
  final id = row?['id'];
  if (id is! String || id.isEmpty) {
    throw const ServerError(
      '`ensure_customer` nije vratio klijenta — provjeri x-salon-id header i sesiju',
    );
  }
  return id;
}
