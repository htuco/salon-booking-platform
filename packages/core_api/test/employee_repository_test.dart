import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Katalog filtrira aktivne; admin istorija ostaje nefiltrirana',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon',
        httpClient: MockClient((r) async {
          requests.add(r.url);
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = EmployeeRepository(client);
      await repo.forSalon('salon');
      await repo.forSalon('salon', includeInactive: true);
      expect(requests[0].queryParameters['is_active'], 'eq.true');
      expect(requests[1].queryParameters.containsKey('is_active'), isFalse);
      expect(
        requests.every((r) => r.queryParameters['salon_id'] == 'eq.salon'),
        isTrue,
      );
    },
  );
  test('RPC payload nosi nullable staz i kompletnu listu usluga', () async {
    late http.Request request;
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient((r) async {
        request = r;
        return http.Response(
          jsonEncode({
            'id': 'e',
            'salon_id': 'salon',
            'name': 'Radnik',
            'is_active': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = EmployeeRepository(client);
    final result = await repo.save(
      salonId: 'salon',
      employeeId: 'e',
      name: 'Radnik',
      role: '',
      bio: '',
      serviceIds: [],
    );
    expect(request.url.path, '/rest/v1/rpc/update_employee');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body.containsKey('p_experience_years'), isTrue);
    expect(body['p_experience_years'], isNull);
    expect(body['p_service_ids'], isEmpty);
    expect(result.isActive, isFalse);
    expect(result.experienceYears, isNull);
    await repo.setActive(salonId: 'salon', employeeId: 'e', isActive: true);
    expect(request.url.path, '/rest/v1/rpc/set_employee_active');
  });
}
