/// Demo ulaz pokriva svaki ekran — FE-505.
///
/// FE-504 je na webu našao devet prikaza koje demo nije punio: dva su pucala u sivu
/// površinu (Termini i Postavke — `Supabase.instance` kojeg demo nema), ostali su pokazivali
/// grešku učitavanja. Nijedan test to nije vidio, jer testovi podižu ekrane kroz
/// `support/screen_harness.dart`, a demo ima **svoju** listu override-a.
///
/// Zato ovaj test podiže app **istom listom** kojom je podiže `lib/demo_main.dart`
/// (`demoOverrides`), na svakoj ruti, za svaki tenant iz registra, prijavljen i neprijavljen.
/// Pada kad ekran baci izuzetak ili nacrta `LoadError`. Novi provider koji ide na mrežu, a
/// demo ga ne podmetne, ruši ovaj test umjesto QA prolaza.
library;

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/load_error.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/demo/demo_overrides.dart';
import 'package:client/src/features/legal/about_app_screen.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Sve rute bez parametra, plus detalj demo termina umjesto `:id`.
final _rute = [
  for (final r in ClientRoute.values)
    if (!r.path.contains(':')) r.path,
  '/appointments/demo-a1',
];

void main() {
  for (final tenant in kTenants.values) {
    test('${tenant.flavor} ima demo podatke', () {
      expect(imaDemoPodataka(tenant.salonId), isTrue);
    });

    for (final prijavljen in [true, false]) {
      final stanje = prijavljen ? 'prijavljen' : 'odjavljen';
      for (final ruta in _rute) {
        testWidgets('${tenant.flavor} · $stanje · $ruta', (tester) async {
          tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
          addTearDown(
            tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
          );
          tester.view
            ..physicalSize = const Size(402, 874)
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final env = AppEnv(
            salonId: tenant.salonId,
            supabaseUrl: '',
            supabaseAnonKey: '',
            apiUrl: '',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...demoOverrides(env, prijavljen: prijavljen),
                // Samo za test: `PackageInfo.fromPlatform()` ide na platformski kanal,
                // kojeg u testu nema. Na webu i uređaju ga demo ima.
                appPackageInfoProvider.overrideWith(
                  (ref) async => PackageInfo(
                    appName: tenant.displayName,
                    packageName: 'ba.nasadomena.${tenant.flavor}',
                    version: '1.0.0',
                    buildNumber: '1',
                  ),
                ),
              ],
              child: const SalonClientApp(),
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            find.byType(LoadError),
            findsNothing,
            reason:
                '$ruta u demou pokazuje grešku učitavanja — izvor nije podmetnut',
          );
        });
      }
    }
  }
}
