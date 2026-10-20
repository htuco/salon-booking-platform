import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ugovor sa RPC-ovima liste čekanja (task 68): imena parametara, mapiranje i greške.
/// Samu izolaciju drži `supabase/tests/033_lista_cekanja.test.sql`.
void main() {
  const salonId = '550e8400-e29b-41d4-a716-446655440000';
  final utorak = LocalDate(2026, 10, 27);

  late List<http.Request> zahtjevi;

  WaitlistRepository repo(
    Object? Function(http.Request) odgovor, {
    int status = 200,
  }) {
    zahtjevi = [];
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'anon',
      httpClient: MockClient((zahtjev) async {
        zahtjevi.add(zahtjev);
        return http.Response(
          jsonEncode(odgovor(zahtjev)),
          status,
          request: zahtjev,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return WaitlistRepository(client);
  }

  Map<String, dynamic> tijelo(int i) =>
      jsonDecode(zahtjevi[i].body) as Map<String, dynamic>;

  test('fullDates šalje raspon i radnika i daje skup dana', () async {
    final r = repo(
      (_) => [
        {'full_date': '2026-10-27'},
      ],
    );
    final puni = await r.fullDates(
      salonId: salonId,
      serviceId: 's1',
      from: utorak,
      to: LocalDate(2026, 11, 26),
      employeeId: 'e1',
    );

    expect(puni, {utorak});
    expect(zahtjevi.single.url.path, endsWith('/rpc/waitlist_full_dates'));
    expect(tijelo(0), {
      'p_salon_id': salonId,
      'p_service_id': 's1',
      'p_from': '2026-10-27',
      'p_to': '2026-11-26',
      'p_employee_id': 'e1',
    });
  });

  test('join ne šalje ni salon ni klijenta', () async {
    final r = repo((_) => 'w1');
    final id = await r.join(serviceId: 's1', date: utorak);

    expect(id, 'w1');
    expect(
      tijelo(0).keys,
      unorderedEquals(['p_service_id', 'p_date', 'p_employee_id']),
    );
  });

  test('četvrti upis je RateLimitError sa porukom iz baze', () async {
    final r = repo(
      (_) => {
        'code': 'PT429',
        'message': 'Već čekate na tri dana. Odjavite jedan da biste se upisali na novi.',
      },
      status: 429,
    );

    await expectLater(
      r.join(serviceId: 's1', date: utorak),
      throwsA(
        isA<RateLimitError>().having(
          (e) => e.displayMessage,
          'poruka',
          contains('tri dana'),
        ),
      ),
    );
  });

  test('mine mapira upis sa radnikom i bez njega', () async {
    final r = repo(
      (_) => [
        {
          'id': 'w1',
          'service_id': 's1',
          'service_name': 'Fade',
          'employee_id': null,
          'employee_name': null,
          'date': '2026-10-27',
          'created_at': '2026-10-20T10:00:00Z',
        },
        {
          'id': 'w2',
          'service_id': 's1',
          'service_name': 'Fade',
          'employee_id': 'e1',
          'employee_name': 'Emir',
          'date': '2026-10-28',
          'created_at': '2026-10-20T10:00:00Z',
        },
      ],
    );
    final upisi = await r.mine();

    expect(upisi, hasLength(2));
    expect(upisi.first.employeeName, isNull);
    expect(upisi.last.employeeName, 'Emir');
    expect(upisi.last.date, LocalDate(2026, 10, 28));
  });

  test('pokvaren red je MappingError, ne pad ekrana', () async {
    final r = repo(
      (_) => [
        {'id': 'w1'},
      ],
    );
    await expectLater(r.mine(), throwsA(isA<MappingError>()));
  });

  test('demand daje mapu dan → broj', () async {
    final r = repo(
      (_) => [
        {'date': '2026-10-27', 'waiting': 3},
      ],
    );
    final broj = await r.demand(
      salonId: salonId,
      from: utorak,
      to: LocalDate(2026, 11, 2),
    );

    expect(broj, {utorak: 3});
    expect(tijelo(0)['p_to'], '2026-11-02');
  });
}
