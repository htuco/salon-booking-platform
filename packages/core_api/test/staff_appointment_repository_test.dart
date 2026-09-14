import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin akcije nad terminima — task 24.
///
/// Isti obrazac kao ostali repozitoriji: gađa se **mapiranje i oblik zahtjeva**, ne
/// autorizacija. Da admin salona A ne može dirati termin salona B, da otkazan termin ne može
/// nazad u `confirmed` i da ručni termin poštuje radno vrijeme — sve su to svojstva baze i
/// dokazuju se u `supabase/tests/008_admin_akcije.test.sql`. Dart test koji bi ih „provjerio"
/// nad lažnim klijentom dokazivao bi samo da mock vraća ono što mu je rečeno.
///
/// Ono što se **ovdje** može dokazati, a pgTAP ne može, jeste da Dart pošalje ono što misli
/// da šalje: pravo ime funkcije, `no_show` umjesto `noShow`, i `p_ignore_min_advance` tamo
/// gdje mu je mjesto.
void main() {
  const salon = '550e8400-e29b-41d4-a716-446655440000';
  const termin = '40000000-0000-4000-8000-000000000001';

  Map<String, dynamic> red({
    String status = 'pending',
    String? cancelledBy,
    String? cancelReason,
    String source = 'app',
    String? pendingExpiresAt,
  }) => {
    'id': termin,
    'salon_id': salon,
    'service_id': '10000000-0000-4000-8000-000000000001',
    'employee_id': '20000000-0000-4000-8000-000000000001',
    'customer_id': '30000000-0000-4000-8000-000000000001',
    'auth_identity_id': null,
    'device_id': null,
    'customer_name': 'Amina',
    'customer_phone': null,
    'customer_note': null,
    'date': '2026-09-16',
    'start_time': '10:00:00',
    'end_time': '10:40:00',
    'buffer_minutes': 5,
    'status': status,
    'source': source,
    'cancel_reason': cancelReason,
    'cancelled_by': cancelledBy,
    'pending_expires_at': pendingExpiresAt,
  };

  /// Klijent koji hvata zahtjev i vraća zadani odgovor.
  ///
  /// Vraća i [zahtjevi] listu, da test može tvrditi **šta je poslano** — kod RPC poziva je
  /// to jedina stvar koju Dart strana uopšte kontroliše.
  ({SupabaseClient client, List<http.Request> zahtjevi}) klijentKojiVraca(
    Object? odgovor,
  ) {
    final zahtjevi = <http.Request>[];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'anon',
      httpClient: MockClient((zahtjev) async {
        zahtjevi.add(zahtjev);
        return http.Response(
          jsonEncode(odgovor),
          200,
          // **`request:` je obavezan, iako izgleda kao detalj mocka.** `postgrest` čita
          // `response.request!.method` pri parsiranju (`postgrest_builder.dart:462`), pa
          // odgovor bez njega puca na null check — a `guard` tu grešku pretvori u
          // `MappingError`, koji izgleda kao da se model razišao sa šemom. Traženo je pola
          // sata na pogrešnom mjestu; postojeći test u `appointment_repository_test.dart`
          // to nije primijetio jer namjerno guta grešku i tvrdi samo URL.
          request: zahtjev,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return (client: client, zahtjevi: zahtjevi);
  }

  Map<String, dynamic> tijelo(http.Request zahtjev) =>
      jsonDecode(zahtjev.body) as Map<String, dynamic>;

  group('set_appointment_status', () {
    test('confirm šalje confirmed i mapira odgovor', () async {
      final mock = klijentKojiVraca(red(status: 'confirmed'));
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.confirm(
        salonId: salon,
        appointmentId: termin,
      );

      expect(rezultat.status, AppointmentStatus.confirmed);
      expect(mock.zahtjevi.single.url.path, endsWith('set_appointment_status'));
      expect(tijelo(mock.zahtjevi.single), {
        'p_salon_id': salon,
        'p_appointment_id': termin,
        'p_status': 'confirmed',
        'p_reason': null,
      });
    });

    // **`wireName`, ne `.name`.** `noShow` u bazi stoji kao `no_show`; sa `.name` bi enum
    // kast pukao na strani Postgresa, i poruka bi govorila o neispravnom ulazu umjesto o
    // statusu. Zamka je tiha jer je jedini pogođen status baš onaj sa dvije riječi — ostale
    // tri akcije bi radile.
    test('markNoShow šalje no_show, ne noShow', () async {
      final mock = klijentKojiVraca(
        red(
          status: 'no_show',
          cancelledBy: 'salon',
          cancelReason: 'Nije došao',
        ),
      );
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.markNoShow(
        salonId: salon,
        appointmentId: termin,
        reason: 'Nije došao',
      );

      expect(rezultat.status, AppointmentStatus.noShow);
      expect(tijelo(mock.zahtjevi.single)['p_status'], 'no_show');
      expect(tijelo(mock.zahtjevi.single)['p_reason'], 'Nije došao');
    });

    test('markCompleted šalje completed', () async {
      final mock = klijentKojiVraca(red(status: 'completed'));
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.markCompleted(
        salonId: salon,
        appointmentId: termin,
      );

      expect(rezultat.status, AppointmentStatus.completed);
      expect(tijelo(mock.zahtjevi.single)['p_status'], 'completed');
    });

    test(
      'idempotentan odgovor nije greška — isti status stiže nazad',
      () async {
        // Baza vraća isti red bez izmjene kad je termin već u traženom statusu. Dva uređaja
        // i dva tapa nisu kvar, pa ekran ne smije dobiti grešku.
        final mock = klijentKojiVraca(red(status: 'confirmed'));
        final repo = StaffAppointmentRepository(mock.client);

        final rezultat = await repo.confirm(
          salonId: salon,
          appointmentId: termin,
        );

        expect(rezultat.status, AppointmentStatus.confirmed);
      },
    );
  });

  group('odbijanje i otkazivanje', () {
    // **Obje radnje idu kroz `cancel_appointment`, ne kroz `set_appointment_status`.**
    // Otkazivanje nosi rok iz `min_cancel_hours` i `cancelled_by`; baza to i provodi —
    // `set_appointment_status` sa `cancelled` vraća `PT400`.
    test('reject zove cancel_appointment, ne set_appointment_status', () async {
      final mock = klijentKojiVraca(
        red(
          status: 'cancelled',
          cancelledBy: 'salon',
          cancelReason: 'Radnik na bolovanju',
        ),
      );
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.reject(
        salonId: salon,
        appointmentId: termin,
        reason: 'Radnik na bolovanju',
      );

      expect(rezultat.status, AppointmentStatus.cancelled);
      expect(mock.zahtjevi.single.url.path, endsWith('cancel_appointment'));
      expect(tijelo(mock.zahtjevi.single), {
        'p_salon_id': salon,
        'p_appointment_id': termin,
        'p_reason': 'Radnik na bolovanju',
      });
    });

    test('cancel ide istim putem kao reject', () async {
      final mock = klijentKojiVraca(
        red(status: 'cancelled', cancelledBy: 'salon'),
      );
      final repo = StaffAppointmentRepository(mock.client);

      await repo.cancel(salonId: salon, appointmentId: termin);

      expect(mock.zahtjevi.single.url.path, endsWith('cancel_appointment'));
    });

    test('cancelled_by stiže nazad kao salon, ne customer', () async {
      // Razlika koju admin ekran i statistika trebaju: klijent koji otkaže i salon koji
      // odbije proizvode isti `status`, a različit `cancelled_by`.
      final mock = klijentKojiVraca(
        red(status: 'cancelled', cancelledBy: 'salon'),
      );
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.reject(salonId: salon, appointmentId: termin);

      // `cancelledBy` je `String`, ne enum — za razliku od `status`. Ekran po njemu samo
      // bira tekst („Vi ste otkazali" / „Salon je otkazao"), pa `unknown` fallback koji
      // `AppointmentStatus` treba ovdje nema šta da nosi.
      expect(rezultat.cancelledBy, 'salon');
    });
  });

  group('ručni unos', () {
    test('slotovi za ručni unos šalju p_ignore_min_advance', () async {
      // Jedina razlika od klijentskog poziva, i razlog zbog kojeg admin uopšte može upisati
      // klijenta koji stoji na vratima. Bez ovog polja bi ručni unos tiho radio po pragu
      // od 2 h i salon bi dobio praznu listu za narednih sat vremena.
      final mock = klijentKojiVraca([
        {
          'start_time': '10:00:00',
          'employee_id': '20000000-0000-4000-8000-000000000001',
        },
      ]);
      final repo = StaffAppointmentRepository(mock.client);

      final slotovi = await repo.slotsForManualBooking(
        salonId: salon,
        serviceId: '10000000-0000-4000-8000-000000000001',
        date: LocalDate(2026, 9, 16),
      );

      expect(slotovi, hasLength(1));
      expect(tijelo(mock.zahtjevi.single)['p_ignore_min_advance'], isTrue);
      expect(mock.zahtjevi.single.url.path, endsWith('get_available_slots'));
    });

    test('ručni termin ide kroz book_appointment, ne kroz insert', () async {
      // Ovo je tvrdnja zbog koje task postoji. Direktan `insert` bi zaobišao radno vrijeme
      // i blokade — a od taska 24 ni ne bi prošao, jer je grant oduzet.
      final mock = klijentKojiVraca(red(status: 'confirmed', source: 'manual'));
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.bookManually(
        salonId: salon,
        customerId: '30000000-0000-4000-8000-000000000001',
        serviceId: '10000000-0000-4000-8000-000000000001',
        date: LocalDate(2026, 9, 16),
        startTime: const LocalTime(10, 0),
      );

      expect(mock.zahtjevi.single.url.path, endsWith('book_appointment'));
      expect(rezultat.status, AppointmentStatus.confirmed);
      expect(rezultat.source, 'manual');
    });

    test('status i source ručnog termina bira baza, ne Dart', () async {
      // U tijelu zahtjeva nema ni `p_status` ni `p_source`: baza ih izvodi iz toga ko zove
      // funkciju. Da ih šalje Dart, klijentska app bi ih mogla poslati isto tako.
      final mock = klijentKojiVraca(red(status: 'confirmed', source: 'manual'));
      final repo = StaffAppointmentRepository(mock.client);

      await repo.bookManually(
        salonId: salon,
        customerId: '30000000-0000-4000-8000-000000000001',
        serviceId: '10000000-0000-4000-8000-000000000001',
        date: LocalDate(2026, 9, 16),
        startTime: const LocalTime(10, 0),
      );

      final poslano = tijelo(mock.zahtjevi.single);
      expect(poslano.containsKey('p_status'), isFalse);
      expect(poslano.containsKey('p_source'), isFalse);
    });
  });

  group('telefonski klijent', () {
    Map<String, dynamic> klijentRed({String? authIdentityId, String? phone}) =>
        {
          'id': '30000000-0000-4000-8000-000000000009',
          'salon_id': salon,
          'auth_identity_id': authIdentityId,
          'name': 'Telefonski Mujo',
          'phone': phone,
          'note': null,
          'visit_count': 0,
          'no_show_count': 0,
          'is_vip': false,
          'first_seen_at': '2026-09-14T09:00:00Z',
          'last_visit_at': null,
        };

    test('upsertWalkinCustomer mapira red bez naloga', () async {
      final mock = klijentKojiVraca(klijentRed(phone: '061 000 111'));
      final repo = StaffAppointmentRepository(mock.client);

      final klijent = await repo.upsertWalkinCustomer(
        salonId: salon,
        name: 'Telefonski Mujo',
        phone: '061 000 111',
      );

      expect(klijent.name, 'Telefonski Mujo');
      // **`auth_identity_id` je `null` i to je stanje, ne nedostajući podatak.**
      expect(klijent.authIdentityId, isNull);
      expect(klijent.isWalkin, isTrue);
      expect(klijent.hasPhone, isTrue);
      expect(mock.zahtjevi.single.url.path, endsWith('upsert_walkin_customer'));
    });

    test('klijent sa nalogom nije walkin', () async {
      final mock = klijentKojiVraca(
        klijentRed(authIdentityId: '90000000-0000-4000-8000-000000000001'),
      );
      final repo = StaffAppointmentRepository(mock.client);

      final klijent = await repo.upsertWalkinCustomer(
        salonId: salon,
        name: 'Prijavljena Amina',
      );

      expect(klijent.isWalkin, isFalse);
    });

    test('prazan broj telefona nije broj', () async {
      // Red iz starijeg importa može nositi `''`. Kartica koja kaže „telefon: " i prazninu
      // izgleda kao greška u učitavanju, a pretraga po praznom uzorku pogađa sve redom.
      final mock = klijentKojiVraca(klijentRed(phone: '   '));
      final repo = StaffAppointmentRepository(mock.client);

      final klijent = await repo.upsertWalkinCustomer(
        salonId: salon,
        name: 'Bez broja',
      );

      expect(klijent.hasPhone, isFalse);
    });

    test('prazna pretraga ne ide u bazu', () async {
      // Lista svih klijenata pri otvaranju polja za pretragu je i spor upit i podatak koji
      // niko nije tražio. Tvrdnja je na **odsustvu zahtjeva**, ne na praznoj listi — prazna
      // lista bi prošla i kad bi upit otišao.
      final mock = klijentKojiVraca(const []);
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.searchCustomers(salonId: salon, upit: '   ');

      expect(rezultat, isEmpty);
      expect(mock.zahtjevi, isEmpty);
    });

    test('pretraga traži i po imenu i po telefonu', () async {
      // Salon zna čovjeka na oba načina: „061" mora pogoditi broj, „mujo" ime.
      final mock = klijentKojiVraca([klijentRed(phone: '061 000 111')]);
      final repo = StaffAppointmentRepository(mock.client);

      final rezultat = await repo.searchCustomers(salonId: salon, upit: '061');

      expect(rezultat, hasLength(1));
      final upit = mock.zahtjevi.single.url.query;
      expect(upit, contains('name.ilike.%25061%25'));
      expect(upit, contains('phone.ilike.%25061%25'));
    });
  });

  group('mapiranje RPC odgovora', () {
    test('ime funkcije u grešci je ono koje je stvarno pozvano', () async {
      // Do taska 24 je mapper imao `book_appointment` zakucan u poruci. Sada ga zovu tri
      // pozivaoca, pa bi zakucano ime značilo da greška iz `set_appointment_status` laže o
      // tome ko je pukao — i da se traži na pogrešnom mjestu.
      expect(
        () =>
            appointmentFromRpcRow(const [], funkcija: 'set_appointment_status'),
        throwsA(
          isA<MappingError>().having(
            (e) => e.toString(),
            'poruka',
            contains('set_appointment_status'),
          ),
        ),
      );
    });

    test('prazan odgovor je MappingError, ne tihi null', () {
      expect(
        () => appointmentFromRpcRow(null, funkcija: 'cancel_appointment'),
        throwsA(isA<MappingError>()),
      );
    });

    test('lista od jednog reda se takođe mapira', () {
      // Ako potpis funkcije ikad pređe na `setof`, isti poziv počne vraćati listu.
      final rezultat = appointmentFromRpcRow([
        red(status: 'confirmed'),
      ], funkcija: 'set_appointment_status');

      expect(rezultat.status, AppointmentStatus.confirmed);
    });
  });
}
