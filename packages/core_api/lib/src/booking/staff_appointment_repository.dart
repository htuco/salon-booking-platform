import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'appointment_mapper.dart';

/// Termini salona, čitani iz **admin** aplikacije.
///
/// ## Zašto ne `AppointmentRepository`
///
/// Klijentski repozitorij se oslanja na `x-salon-id` header koji `bootstrap()` postavlja iz
/// `SALON_ID` flavora. **Admin app taj header nema i ne smije ga imati:** jedna je za sve
/// salone, pa bi header značio da admin sam sebi bira kontekst. Njegova prava idu kroz
/// `private.is_admin()`, koji čita JWT claim i red u `public.users`
/// ([ADR-0003](../../../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
///
/// Uz to su i upiti drugi: klijent traži *svoje* termine kroz sva vremena, admin traži
/// *jedan dan* ili *jedan status* kroz sve klijente.
///
/// ## `salonId` se prosljeđuje, ali ne štiti
///
/// Metode primaju [salonId] jer admin app mora znati **koji** salon prikazuje — dobija ga iz
/// `StaffMember.salonId`, ne iz UI-ja. Taj filter je tu da upit bude precizan, a ne da čuva
/// podatak: `staff_manage` politika ionako presijeca na članstvo, pa admin koji bi poslao
/// tuđi `salonId` dobije **praznu listu**, ne tuđe termine. Dokazano u
/// `supabase/tests/rest_admin_login.ts`.
///
/// ## Pisanje ide isključivo kroz `rpc`
///
/// Task 24 je dopisao akcije, i svaka od njih je `rpc` poziv — ne zato što je tako uredno
/// nego zato što **drugog puta više nema**: ista migracija je oduzela `insert` i `update`
/// grant roli `authenticated`. Direktan `from('appointments').update(...)` odavde vraća
/// `42501`, i to je namjerno: dok je grant stajao, validirane funkcije su bile konvencija
/// koju je bilo dovoljno zaboraviti (`.claude/docs/security.md`).
class StaffAppointmentRepository {
  const StaffAppointmentRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '''
id, salon_id, service_id, employee_id, customer_id, auth_identity_id, device_id,
service_name, service_price, service_duration_minutes,
customer_name, customer_phone, customer_note, date, start_time, end_time,
buffer_minutes, status, source, cancel_reason, cancelled_by, pending_expires_at
''';

  /// Jedan termin po `id`-u, ili `null` ako ga nema.
  ///
  /// `null` je **predviđeno stanje**, ne greška: adresa `/appointments/<id>` može stajati u
  /// bookmarku ili u obavijesti, a termin je u međuvremenu obrisan — ili je od tuđeg
  /// salona, u kom slučaju ga `staff_manage` politika ne propusti i upit vrati nula redova.
  /// Ekran oba slučaja prikazuje isto, jer se **ne smiju** razlikovati: poruka „nemate
  /// pravo" bi potvrdila da taj termin postoji.
  ///
  /// [salonId] je, kao i drugdje ovdje, preciznost upita a ne zaštita — v. doc klase.
  Future<Appointment?> byId({
    required String salonId,
    required String appointmentId,
  }) => guard(() async {
    final row = await _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('id', appointmentId)
        .maybeSingle();

    return row == null ? null : appointmentFromRow(row);
  });

  /// Termini jednog dana, po vremenu početka.
  ///
  /// Rastuće, za razliku od klijentske liste: admin gleda **raspored dana** odozgo nadolje,
  /// a klijent svoju historiju od najnovijeg. Isti podatak, druga svrha.
  ///
  /// Otkazani termini **ostaju u listi**. Dan sa tri termina od kojih je jedan otkazan nije
  /// isto što i dan sa dva — vlasnik mora vidjeti da je neko otkazao, inače izgleda kao da
  /// termin nikad nije ni postojao.
  Future<List<Appointment>> forDay({
    required String salonId,
    required DateTime day,
  }) => guard(() async {
    final rows = await _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('date', _datum(day))
        // `ascending: true` je **obavezan**: u ovom paketu `order()` podrazumijeva
        // **descending**, suprotno od SQL-a i od postgrest-js. Bez njega raspored dana
        // ide unatraske, sto na ekranu izgleda kao pogresni podaci, a ne kao propusten
        // parametar (isti propust je vec zabiljezen u `policy_repository.dart`).
        .order('start_time', ascending: true);

    return appointmentsFromRows(rows);
  });

  /// Termini u rasponu dana, po datumu pa po vremenu.
  ///
  /// Oba kraja su **uključena**: `from: danas, to: danas` je jedan dan, ne prazan raspon.
  /// Isključiv kraj bi značio da lista „danas" traži `to: sutra`, što se pogrešno napiše
  /// jednom pa se svaki put nakon toga prepisuje.
  Future<List<Appointment>> forRange({
    required String salonId,
    required DateTime from,
    required DateTime to,
    AppointmentStatus? status,
  }) => guard(() async {
    var upit = _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .gte('date', _datum(from))
        .lte('date', _datum(to));

    // Filter po statusu je opcion: `null` znači „svi", ne „nijedan". Ekran ga šalje samo
    // kad je korisnik izabrao status u filteru.
    if (status != null && status != AppointmentStatus.unknown) {
      // `wireName`, ne `.name`: `noShow` u bazi stoji kao `no_show`, pa bi `.name` tiho
      // filtrirao nula redova umjesto da pukne.
      upit = upit.eq('status', status.wireName);
    }

    final rows = await upit
        .order('date', ascending: true)
        .order('start_time', ascending: true);
    return appointmentsFromRows(rows);
  });

  /// Broj zahtjeva koji čekaju odgovor — brojka na dashboardu.
  ///
  /// Broji **baza**, ne Dart: PostgREST reže odgovor na `max_rows`, pa bi salon sa mnogo
  /// termina dao tih i pogrešan broj da se lista povlači pa broji u app-i. Isti razlog zbog
  /// kojeg prosjek ocjena računa pogled, a ne ekran (task 20).
  ///
  /// **Bez datumskog ograničenja.** `pending` zahtjev od prije tri dana je i dalje zahtjev
  /// koji niko nije pogledao; skrivanje starih bi sakrilo baš one koji su ispali iz vida.
  Future<int> pendingCount({required String salonId}) => guard(() async {
    final odgovor = await _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('status', AppointmentStatus.pending.wireName)
        .count(CountOption.exact);

    return odgovor.count;
  });

  /// Potvrdi zahtjev — `pending` → `confirmed`.
  ///
  /// **Idempotentno**: drugi tap na već potvrđen termin vraća isti red bez greške. Dva
  /// uređaja i dva tapa nisu kvar, a crvena poruka na uspješnu radnju je gora od nijedne.
  Future<Appointment> confirm({
    required String salonId,
    required String appointmentId,
  }) => _postavi(
    salonId: salonId,
    appointmentId: appointmentId,
    status: AppointmentStatus.confirmed,
  );

  /// Odbij zahtjev — termin prelazi u `cancelled`, sa `cancelled_by = 'salon'`.
  ///
  /// **Ide kroz `cancel_appointment`, ne kroz `set_appointment_status`.** Otkazivanje nosi
  /// rok iz `salon_settings.min_cancel_hours` i podatak o tome ko je otkazao; dvije funkcije
  /// koje pišu isti status bile bi dva mjesta na kojima se to pravilo može razići. Baza to i
  /// provodi — `set_appointment_status` sa `cancelled` vraća `PT400`.
  ///
  /// **Rok ne obavezuje salon.** Ista funkcija zaustavlja klijenta koji otkazuje prekasno, a
  /// salon pušta: salon otkazuje kad mora (bolest, kvar), i tada klijent dobije obavijest, ne
  /// zabranu.
  ///
  /// [reason] je ono što klijent vidi kao obrazloženje. Prazan string se u bazi normalizuje
  /// u `null`, pa razmak ne postaje „obrazloženje".
  Future<Appointment> reject({
    required String salonId,
    required String appointmentId,
    String? reason,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'cancel_appointment',
      params: {
        'p_salon_id': salonId,
        'p_appointment_id': appointmentId,
        'p_reason': reason,
      },
    );

    return appointmentFromRpcRow(row, funkcija: 'cancel_appointment');
  });

  /// Otkaži potvrđen termin — isti put kao [reject].
  ///
  /// Razlika je samo u tome iz kojeg stanja termin kreće (`confirmed` umjesto `pending`) i
  /// kako se radnja zove na ekranu. Baza ne razlikuje ta dva slučaja i ne treba: oba su
  /// „salon je otkazao", oba pune `cancelled_by = 'salon'`.
  ///
  /// Metoda postoji da ekran ne bi zvao `reject` za radnju koja se zove „Otkaži" — ime
  /// poziva koje ne odgovara dugmetu je mjesto gdje se sljedeća izmjena pogrešno zakači.
  Future<Appointment> cancel({
    required String salonId,
    required String appointmentId,
    String? reason,
  }) => reject(salonId: salonId, appointmentId: appointmentId, reason: reason);

  /// Klijent se nije pojavio — `no_show`.
  ///
  /// Diže `customers.no_show_count`, koji do taska 24 nije imao nijednog pisca. **Prag
  /// („tri nedolaska u šest mjeseci") nigdje se ne provodi** — to je pravilo vertikale
  /// (`vertical.features.noShowTracking`) i dolazi u Sprintu 3. Brojač se puni sada da
  /// statistika ne počne od nule kad ekran dođe.
  Future<Appointment> markNoShow({
    required String salonId,
    required String appointmentId,
    String? reason,
  }) => _postavi(
    salonId: salonId,
    appointmentId: appointmentId,
    status: AppointmentStatus.noShow,
    reason: reason,
  );

  /// Termin je odrađen — `completed`. Diže `visit_count` i `last_visit_at`.
  Future<Appointment> markCompleted({
    required String salonId,
    required String appointmentId,
  }) => _postavi(
    salonId: salonId,
    appointmentId: appointmentId,
    status: AppointmentStatus.completed,
  );

  /// Zajedničko tijelo za akcije koje idu kroz `set_appointment_status`.
  ///
  /// [AppointmentStatus.cancelled] ovdje **ne prolazi** — baza ga odbija sa `PT400` i upućuje
  /// na `cancel_appointment`. Provjera se namjerno ne duplira u Dartu: pravilo je u bazi, a
  /// druga kopija bi bila mjesto koje zaostane kad se pravilo promijeni.
  Future<Appointment> _postavi({
    required String salonId,
    required String appointmentId,
    required AppointmentStatus status,
    String? reason,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'set_appointment_status',
      params: {
        'p_salon_id': salonId,
        'p_appointment_id': appointmentId,
        // `wireName`, ne `.name`: `noShow` u bazi stoji kao `no_show`. Sa `.name` bi enum
        // kast pukao na strani baze, sa porukom o neispravnom ulazu umjesto o statusu.
        'p_status': status.wireName,
        'p_reason': reason,
      },
    );

    return appointmentFromRpcRow(row, funkcija: 'set_appointment_status');
  });

  /// Telefonski klijent — čovjek koji je salon nazvao i nema nalog u aplikaciji.
  ///
  /// `auth_identity_id` ostaje `null`, i to je suština a ne propust. Ako se ta osoba kasnije
  /// prijavi u klijentskoj app-i, `ensure_customer` napravi **zaseban** red: po telefonu ne
  /// može dokazati da je to ona. Spajanje dva reda je odluka salona iz ekrana, ne baze koja
  /// pogađa po broju telefona.
  ///
  /// Postojeći red se prepoznaje **po broju telefona** i ažurira se. Bez broja svaki poziv
  /// pravi nov red — prihvaćeno svjesno, jer je alternativa spajanje po imenu, a dva Emira
  /// nisu isti čovjek.
  Future<Customer> upsertWalkinCustomer({
    required String salonId,
    required String name,
    String? phone,
    String? note,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'upsert_walkin_customer',
      params: {
        'p_salon_id': salonId,
        'p_name': name,
        'p_phone': phone,
        'p_note': note,
      },
    );

    return _klijentIzRpcReda(row);
  });

  /// Slobodni slotovi za **ručni** unos.
  ///
  /// Razlika od klijentske liste je jedan argument: `p_ignore_min_advance`. Salon upisuje
  /// klijenta koji stoji na vratima, a prag od `min_advance_booking_hours` (2 h po
  /// podrazumijevanoj postavci) to zabranjuje. Prag je pravilo **prema klijentu** („ne
  /// rezerviši mi pet minuta prije"), ne fizičko ograničenje salona — isti oblik kao
  /// `min_cancel_hours`, koji takođe obavezuje klijenta a ne salon.
  ///
  /// **Izuzetak vrijedi samo za taj prag.** Radno vrijeme, pauze, blokade i preklapanje
  /// vrijede i za admina, pa ručni termin u nedjelju u 3 ujutro i dalje nije moguć.
  Future<List<AvailableSlot>> slotsForManualBooking({
    required String salonId,
    required String serviceId,
    required LocalDate date,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'get_available_slots',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_date': date.format(),
        'p_employee_id': employeeId,
        'p_ignore_min_advance': true,
      },
    );

    return _slotoviIzRedova(rows);
  });

  /// Ručni upis termina — **ista funkcija kojom prolazi klijent**.
  ///
  /// Do taska 24 je ovo bila poznata rupa: direktan `insert` sa admin ekrana zaobilazi radno
  /// vrijeme, blokade i `min_advance_booking_hours`, jer ih exclusion constraint ne poznaje
  /// (`.claude/docs/security.md`). Sada tog puta nema — grant je oduzet.
  ///
  /// Termin nastaje odmah kao `confirmed`, sa `source = manual` i bez `pending_expires_at`:
  /// `pending` znači „salon još nije odgovorio", a kad salon sam upisuje termin, odgovor je
  /// sam upis. Taj izbor pravi **baza**, po tome ko zove funkciju — ovdje se ne šalje.
  ///
  /// Baca `ConflictError` (`PT409`) kad slot u međuvremenu ode ili kad traženo vrijeme nije
  /// slobodno. Ekran na to osvježava listu slotova, kao i klijentski flow.
  Future<Appointment> bookManually({
    required String salonId,
    required String customerId,
    required String serviceId,
    required LocalDate date,
    required LocalTime startTime,
    String? employeeId,
    String? note,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'book_appointment',
      params: {
        'p_salon_id': salonId,
        'p_customer_id': customerId,
        'p_service_id': serviceId,
        'p_date': date.format(),
        'p_start_time': startTime.format(),
        'p_employee_id': employeeId,
        'p_note': note,
        'p_device_id': null,
      },
    );

    return appointmentFromRpcRow(row, funkcija: 'book_appointment');
  });

  /// Postojeći klijenti salona, za pretragu pri ručnom unosu.
  ///
  /// Traži po imenu **i** po telefonu, jer salon zna čovjeka na oba načina. `ilike` sa
  /// obostranim `%` je namjerno: „061" mora pogoditi „061 234 567", a „mujo" i „Mujo" su isti
  /// čovjek.
  ///
  /// Prazan [upit] vraća praznu listu, ne cijeli imenik: lista svih klijenata pri otvaranju
  /// polja za pretragu je i spor upit i podatak koji niko nije tražio.
  Future<List<Customer>> searchCustomers({
    required String salonId,
    required String upit,
    int limit = 20,
  }) => guard(() async {
    final trazeno = upit.trim();
    if (trazeno.isEmpty) return const <Customer>[];

    final uzorak = '%$trazeno%';
    final rows = await _client
        .from('customers')
        .select(
          'id, salon_id, auth_identity_id, name, phone, note, '
          'visit_count, no_show_count, is_vip, first_seen_at, last_visit_at',
        )
        .eq('salon_id', salonId)
        .or('name.ilike.$uzorak,phone.ilike.$uzorak')
        .order('name', ascending: true)
        .limit(limit);

    // Bez `is! List` provjere, za razliku od RPC mapera ispod: `.limit()` je statički
    // tipizirana lista, pa je provjera mrtav kod (analizator je i prijavio kao takav).
    // Kod `rpc` je drugačije — tamo je izlaz `dynamic` i oblik se stvarno može promijeniti.
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Customer.fromJson)
        .toList(growable: false);
  });

  /// Mapira jedan red iz `upsert_walkin_customer`.
  ///
  /// Oblik se provjerava iz istog razloga kao kod termina: `returns public.customers` danas
  /// daje mapu, ali `setof` u budućoj verziji bi dao listu.
  static Customer _klijentIzRpcReda(dynamic row) {
    final json = switch (row) {
      Map<String, dynamic>() => row,
      List<dynamic>() when row.length == 1 => row.first as Map<String, dynamic>,
      List<dynamic>() when row.isEmpty => throw const MappingError(
        '`upsert_walkin_customer` nije vratio klijenta',
      ),
      _ => throw MappingError(
        '`upsert_walkin_customer` je vratio neočekivan oblik: ${row.runtimeType}',
      ),
    };

    try {
      return Customer.fromJson(json);
    } catch (error) {
      throw MappingError('Neispravan `customers` red', cause: error);
    }
  }

  /// Mapira izlaz `get_available_slots`.
  ///
  /// Isti oblik kao u `BookingRepository`, ali se **ne dijeli**: tamošnja funkcija je
  /// `@visibleForTesting` u klijentskom paketu i vezana za klijentski poziv. Duplikat je
  /// ovdje svjestan i mali; izvlačenje bi značilo treći fajl za osam linija.
  static List<AvailableSlot> _slotoviIzRedova(dynamic rows) {
    if (rows == null) return const [];
    if (rows is! List) {
      throw const MappingError('`get_available_slots` nije vratio listu');
    }
    try {
      return rows
          .cast<Map<String, dynamic>>()
          .map(AvailableSlot.fromJson)
          .toList(growable: false);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw MappingError(
        'Neispravan red iz `get_available_slots`',
        cause: error,
      );
    }
  }

  /// `date` kolona je `date`, ne `timestamptz` — šalje se `YYYY-MM-DD`, bez zone.
  ///
  /// Zona je namjerno izvan ovoga: `DateTime` sa lokalnom zonom pretvoren u ISO string bi
  /// oko ponoći dao susjedni dan, i lista „danas" bi u 00:30 pokazala jučerašnje termine.
  static String _datum(DateTime dan) =>
      '${dan.year.toString().padLeft(4, '0')}-'
      '${dan.month.toString().padLeft(2, '0')}-'
      '${dan.day.toString().padLeft(2, '0')}';
}
