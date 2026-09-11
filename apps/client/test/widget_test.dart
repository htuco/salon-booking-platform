import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _barberId = '550e8400-e29b-41d4-a716-446655440000';

/// Env kakav bi bootstrap sastavio za barber tenant, bez Supabase vrijednosti —
/// widget test ne dize mrezu.
const _env = AppEnv(
  salonId: _barberId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

Widget _app({AppEnv env = _env}) => ProviderScope(
  overrides: [appEnvProvider.overrideWithValue(env)],
  child: const SalonClientApp(),
);

void main() {
  group('Generisani registar tenanata', () {
    test('sadrži oba demo salona iz seed.sql', () {
      expect(
        kTenants.keys,
        containsAll(<String>[
          _barberId,
          '550e8400-e29b-41d4-a716-446655440001',
        ]),
      );
    });

    test('ključ je salonId svakog tenanta', () {
      for (final entry in kTenants.entries) {
        expect(entry.key, entry.value.salonId);
      }
    });

    test('applicationId je jedinstven po tenantu', () {
      final flavors = kTenants.values.map((t) => t.flavor).toSet();
      expect(flavors.length, kTenants.length);
    });

    test('flavor je validan gradle identifikator', () {
      for (final tenant in kTenants.values) {
        expect(
          RegExp(r'^[a-z][a-z0-9]*$').hasMatch(tenant.flavor),
          isTrue,
          reason: '${tenant.flavor} nije validan gradle flavor',
        );
      }
    });
  });

  group('SalonClientApp', () {
    testWidgets('podize se na pocetnoj ruti i nosi ime tenanta', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // AppBar naslov dolazi iz rute, ne iz tenanta — ime tenanta je naslov prozora.
      expect(
        find.text(ClientRoute.home.title),
        findsNWidgets(2),
      ); // AppBar + tijelo
      expect(find.text(ClientRoute.home.path), findsOneWidget);
    });

    testWidgets('nepoznat SALON_ID ne rusi app — tenant je samo null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          env: const AppEnv(
            salonId: 'nepostojeci',
            supabaseUrl: '',
            supabaseAnonKey: '',
            apiUrl: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(ClientRoute.home.title),
        findsNWidgets(2),
      ); // AppBar + tijelo
    });
  });
}
