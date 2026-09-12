import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Klijent prijavljenog korisnika u **jednom** salonu.
///
/// ## Zašto samo čitanje, i zašto `null` nije greška
///
/// `customers` red nastaje tek kad se korisnik prvi put prijavi u konkretan salon, i
/// nastaje **kroz `security definer` funkciju**, nikad kroz `insert` sa klijenta
/// (`.claude/docs/security.md`). Ta funkcija je
/// [task 14](../../../../../tasks/sprint-2/14-identitet-i-klijent-upsert.md); ovdje je
/// samo strana koja čita, jer je to sve što politika `own_customer` danas dozvoljava.
///
/// Do taska 14 odgovor je zato **redovno `null`** — ali to je izmjerena činjenica o bazi,
/// a ne konstanta u kodu: isti poziv vratiće `id` onog trenutka kad upsert počne praviti
/// red, bez ijedne izmjene iznad ovog sloja.
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
}
