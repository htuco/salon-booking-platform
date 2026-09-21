import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../booking/appointment_mapper.dart';
import '../errors/errors.dart';

/// Adresar salona — `public.customers`, čitan iz **admin** aplikacije.
///
/// ## Zašto ne `CustomerRepository`
///
/// Klijentski repozitorij traži **svoj** red i oslanja se na `x-salon-id` header koji
/// `bootstrap()` postavlja iz `SALON_ID` flavora. Admin app taj header nema i ne smije ga
/// imati: jedna je za sve salone, pa bi header značio da admin sam sebi bira kontekst.
/// Njegova prava idu kroz `private.is_admin()`
/// ([ADR-0003](../../../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
/// Isti razlog i ista podjela kao kod `StaffAppointmentRepository`.
///
/// ## Ovaj repozitorij samo čita
///
/// Za razliku od `appointments` (task 24), `employees` (33) i `working_hours` (34), tabela
/// `customers` je **zadržala** `insert`/`update` grant za `authenticated` — task 24 ga je
/// izričito ostavio jer admin ispravlja ime i bilježi napomenu. Uprkos tome ovdje nema
/// nijedne metode koja piše: ručni unos klijenta ide kroz `upsert_walkin_customer`, koji uz
/// upis radi i normalizaciju telefona i `on conflict do update` po `unique(salon_id, phone)`.
/// Direktan `insert` odavde bi zaobišao oboje i napravio duplikat koji se poslije ne da
/// spojiti.
///
/// ## `salonId` se prosljeđuje, ali ne štiti
///
/// Metode primaju [salonId] jer admin app mora znati **koji** salon prikazuje — dobija ga iz
/// `StaffMember.salonId`, ne iz UI-ja. Taj filter je preciznost upita, ne zaštita:
/// `staff_manage` politika presijeca na članstvo, pa admin koji bi poslao tuđi `salonId`
/// dobije **praznu listu**, ne tuđi adresar.
///
/// **Ovo je modul sa najvećim rizikom curenja** (task 35): klijent je jedini entitet koji
/// stvarno postoji u dva salona — isti čovjek kod dva salona su **dva** `customers` reda,
/// sa odvojenim brojačima. Da se ta dva reda nikad ne spoje dokazuje
/// `supabase/tests/rest_cross_salon_isolation.ts`, kroz stvaran JWT i stvaran PostgREST.
class StaffCustomerRepository {
  const StaffCustomerRepository(this._client);

  final SupabaseClient _client;

  /// `auth_identity_id` se **čita**, ali nikad ne šalje kao filter iz UI-ja.
  ///
  /// Ekranu treba samo da razlikuje telefonskog klijenta od onog sa nalogom
  /// (`Customer.isWalkin`). Upit po tuđem identitetu je put kojim bi admin salona A
  /// nabrojao salone u kojima je njegov klijent — RLS ga presijeca, i test to drži
  /// dokazanim, ali repozitorij mu ni ne nudi metodu.
  static const _columns = '''
id, salon_id, auth_identity_id, name, phone, note,
visit_count, no_show_count, is_vip, first_seen_at, last_visit_at
''';

  /// Adresar salona, najskoriji dolazak prvi.
  ///
  /// **Klijent bez ijednog dolaska ne ispada s liste.** `last_visit_at` je `null` dok
  /// `set_appointment_status` ne zabilježi prvi `completed`, a novoupisan klijent je baš
  /// onaj kojeg salon traži da bi mu zakazao termin. `nullsFirst: false` ga zato spušta na
  /// dno, umjesto da ga sortiranje po `null`-u digne na vrh ili izbaci.
  ///
  /// [pretraga] filtrira po imenu **i** telefonu, jer salon jedno ili drugo ima pri ruci.
  /// Prazan i `null` znače „svi" — ne „nijedan".
  Future<List<Customer>> list({
    required String salonId,
    String? pretraga,
    int limit = 200,
  }) => guard(() async {
    var upit = _client
        .from('customers')
        .select(_columns)
        .eq('salon_id', salonId);

    final izraz = pretraga?.trim() ?? '';
    if (izraz.isNotEmpty) {
      upit = upit.or(_uzorak(izraz));
    }

    final rows = await upit
        // `ascending: false` je ovdje namjera, ne propust: adresar se gleda od zadnjeg
        // dolaska unatrag. Suprotno od `forDay` u terminima, gdje dan ide odozgo nadolje.
        .order('last_visit_at', ascending: false, nullsFirst: false)
        .order('name', ascending: true)
        .limit(limit);

    return _redovi(rows);
  });

  /// Jedan klijent po `id`-u, ili `null` ako ga nema.
  ///
  /// `null` je **predviđeno stanje**, ne greška — kao i kod termina: adresa profila može
  /// stajati u bookmarku, a klijent je u međuvremenu obrisan ili je od tuđeg salona. Ekran
  /// oba slučaja prikazuje isto, jer se **ne smiju** razlikovati: poruka „nemate pravo" bi
  /// potvrdila da taj klijent postoji, a kod baš ove tabele to je podatak o konkurenciji.
  Future<Customer?> byId({
    required String salonId,
    required String customerId,
  }) => guard(() async {
    final row = await _client
        .from('customers')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('id', customerId)
        .maybeSingle();

    return row == null ? null : _red(row);
  });

  /// Istorija dolazaka jednog klijenta — najskoriji termin prvi.
  ///
  /// **Zaseban upit, ne embed.** `customers?select=*,appointments(...)` je dvosmislen: veza
  /// ima **dva** kompozitna FK-a (`salon_id,customer_id` i `salon_id,customer_id,
  /// auth_identity_id`), pa PostgREST vrati **300** sa `PGRST201`. Imenovana veza bi radila,
  /// ali bi listu adresara vezala za istoriju svakog reda u njoj — profil je jedan klijent,
  /// i njegova istorija se traži tek kad se profil otvori.
  ///
  /// **Otkazani i nedošli termini ostaju u listi.** Istorija koja pokazuje samo održane
  /// termine ne bi objasnila `no_show_count` u istom profilu, a vlasnik gleda baš to:
  /// dolazi li ovaj čovjek kad kaže da dolazi.
  Future<List<Appointment>> istorija({
    required String salonId,
    required String customerId,
    int limit = 50,
  }) => guard(() async {
    final rows = await _client
        .from('appointments')
        .select(_appointmentColumns)
        .eq('salon_id', salonId)
        .eq('customer_id', customerId)
        .order('date', ascending: false)
        .order('start_time', ascending: false)
        .limit(limit);

    return appointmentsFromRows(rows);
  });

  /// Kolone termina za istoriju — isti skup kao u `StaffAppointmentRepository`.
  ///
  /// Prepisan namjerno: `appointmentsFromRows` traži pun red, a dijeljena konstanta između
  /// dva repozitorija bi značila da promjena kolona u jednom tiho mijenja upit u drugom.
  static const _appointmentColumns = '''
id, salon_id, service_id, employee_id, customer_id, auth_identity_id, device_id,
service_name, service_price, service_duration_minutes, employee_name,
customer_name, customer_phone, customer_note, date, start_time, end_time,
buffer_minutes, status, source, cancel_reason, cancelled_by, pending_expires_at
''';

  /// `or` uzorak za pretragu po imenu i telefonu.
  ///
  /// Dvije stvari koje se lako propuste:
  ///
  /// - **`,` i `)` se moraju ukloniti**, ne samo pobjeći. PostgREST `or=(...)` razdvaja
  ///   uslove zarezom, pa ime sa zarezom raspadne izraz u dva uslova i upit vrati red koji
  ///   pretraga nije tražila — ili padne sa `PGRST100`.
  /// - **`%` i `_` u unosu** su `like` džokeri. Bez njih bi `_` pogodio bilo koji znak, pa
  ///   bi pretraga izgledala kao da vraća nasumične ljude.
  /// - **`"` je znak citiranja operanda.** Neuparen navodnik obara izraz sa `PGRST100`, pa
  ///   ekran pokaže „Klijenti se ne mogu učitati." dok čovjek kuca ime sa navodnikom;
  ///   uparen mijenja parsiranje operanda. Nije put ka tuđem redu — RLS se primjenjuje
  ///   prije `where`-a — nego tiho pogrešan rezultat.
  @visibleForTesting
  static String uzorakZaTest(String izraz) => _uzorak(izraz);

  static String _uzorak(String izraz) {
    final ocisceno = izraz
        .replaceAll(RegExp(r'[,()"]'), ' ')
        .replaceAll(RegExp(r'[%_\\]'), '')
        .trim();

    // Sve uklonjeno — ostaje uzorak koji ne pogađa ništa, umjesto `*%*` koji pogađa sve.
    // Pretraga po `,,,` mora dati praznu listu, ne cijeli adresar.
    if (ocisceno.isEmpty) return 'name.eq.,phone.eq.';

    return 'name.ilike.*$ocisceno*,phone.ilike.*$ocisceno*';
  }

  static List<Customer> _redovi(List<Map<String, dynamic>> rows) =>
      rows.map(_red).toList(growable: false);

  static Customer _red(Map<String, dynamic> row) {
    try {
      return Customer.fromJson(row);
    } catch (error) {
      throw MappingError('Neispravan red iz `customers`', cause: error);
    }
  }
}
