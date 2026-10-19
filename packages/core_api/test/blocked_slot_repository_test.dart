import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Čitanje blokada za sedmični kalendar — task 69.
///
/// Isti obrazac kao `staff_appointment_repository_test.dart`: gađa se **oblik upita i
/// mapiranje**, ne izolacija. Da admin salona A ne vidi blokade salona B dokazuje
/// `staff_manage` politika u pgTAP-u, ne mock.
void main() {
  const salon = '550e8400-e29b-41d4-a716-446655440000';

  ({SupabaseClient client, List<http.Request> zahtjevi}) klijentKojiVraca(
    Object? odgovor,
  ) {
    final zahtjevi = <http.Request>[];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'anon',
      httpClient: MockClient((zahtjev) async {
        zahtjevi.add(zahtjev);
        // `request:` je obavezan — v. isti komentar u `staff_appointment_repository_test`.
        return http.Response(
          jsonEncode(odgovor),
          200,
          request: zahtjev,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return (client: client, zahtjevi: zahtjevi);
  }

  group('forRange', () {
    test('oba kraja su uključena i poredak je uzlazan', () async {
      final (:client, :zahtjevi) = klijentKojiVraca(const []);

      await BlockedSlotRepository(client).forRange(
        salonId: salon,
        from: DateTime(2026, 5, 18),
        to: DateTime(2026, 5, 24),
      );

      final upit = zahtjevi.single.url.queryParametersAll;
      expect(upit['salon_id'], ['eq.$salon']);
      // Nedjelja mora biti u odgovoru: `lt` umjesto `lte` bi je tiho odsjekao.
      expect(
        upit['date'],
        unorderedEquals(['gte.2026-05-18', 'lte.2026-05-24']),
      );
      expect(upit['order'], ['date.asc.nullslast,start_time.asc.nullslast']);
    });

    test('mapira salonsku i radnikovu blokadu', () async {
      final (:client, zahtjevi: _) = klijentKojiVraca([
        {
          'id': '60000000-0000-4000-8000-000000000001',
          'salon_id': salon,
          'employee_id': null,
          'date': '2026-05-20',
          'start_time': '12:00:00',
          'end_time': '13:00:00',
          'reason': 'Sastanak',
        },
        {
          'id': '60000000-0000-4000-8000-000000000002',
          'salon_id': salon,
          'employee_id': '20000000-0000-4000-8000-000000000001',
          'date': '2026-05-22',
          'start_time': '15:00:00',
          'end_time': '16:00:00',
          'reason': null,
        },
      ]);

      final blokade = await BlockedSlotRepository(client).forRange(
        salonId: salon,
        from: DateTime(2026, 5, 18),
        to: DateTime(2026, 5, 24),
      );

      expect(blokade.map((b) => b.isSalonWide), [true, false]);
      expect(blokade.last.employeeId, '20000000-0000-4000-8000-000000000001');
    });
  });
}
