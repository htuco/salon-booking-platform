import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
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

/// Svi podatkovni provideri se override-uju, i to **praznim listama umjesto da se ostave
/// na miru**: bez override-a bi repozitorij nastao i pozvao `Supabase.instance`, koji u
/// testu ne postoji. Od taska 10 `/` je pravi ekran, pa ovo vise nije opcija kao dok je
/// tijelo rute bio placeholder.
Widget _app({AppEnv env = _env, Salon? salon}) => ProviderScope(
  overrides: [
    appEnvProvider.overrideWithValue(env),
    currentSalonIdProvider.overrideWithValue(env.salonId),
    salonProvider.overrideWith((ref) async => salon ?? _salon(env.salonId)),
    servicesProvider.overrideWith((ref) async => const <Service>[]),
    employeesProvider.overrideWith((ref) async => const <Employee>[]),
    workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
    verticalProvider.overrideWith((ref) async => Vertical.fallback),
  ],
  child: const SalonClientApp(),
);

Salon _salon(String id) => Salon(
  id: id,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
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
    testWidgets('podize se na pocetnoj ruti i prikazuje ime salona', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      // `pump`, ne `pumpAndSettle`: skeleton puls je beskonacna animacija, pa
      // `pumpAndSettle` istekne cak i kad ekran radi ispravno. Dva `pump`-a su
      // dovoljna da `FutureProvider` isporuci vrijednost.
      await tester.pump();
      await tester.pump();

      expect(find.text('Barber Studio Vitez'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
