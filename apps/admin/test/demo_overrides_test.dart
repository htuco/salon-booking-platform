/// Demo ulaz admina pokriva svaki ekran — FE-505.
///
/// FE-504 je na webu našao da Klijenti, Radno vrijeme i Postavke u demou pokazuju grešku
/// učitavanja: njihovi provideri idu u bazu, a demo ih nije punio. Testovi to nisu vidjeli,
/// jer svaki ekran podižu sa **svojim** override-ima.
///
/// Ovaj test podiže app **istom listom** kojom je podiže `lib/demo_main.dart`, na svakoj
/// ruti, na obje širine iz handoffa. Pada kad ekran nacrta `AdminLoadError` ili neku od
/// rečenica kojom ekran javlja da podatak nije stigao.
library;

import 'package:admin/main.dart';
import 'package:admin/src/core/env/app_env.dart';
import 'package:admin/src/core/router/admin_router.dart';
import 'package:admin/src/core/widgets/admin_load_error.dart';
import 'package:admin/src/demo/demo_overrides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sve rute bez parametra, plus detalj demo termina umjesto `:id`. Prijava se preskače:
/// demo je prijavljen, pa router `/login` preusmjeri na pregled.
final _rute = [
  for (final r in AdminRoute.values)
    if (!r.path.contains(':') && r != AdminRoute.login) r.path,
  '/appointments/demo-Tarik Selimović',
];

/// Rečenice kojima ekrani javljaju da izvor nije stigao, a koje nisu `AdminLoadError`.
final _nijeUcitano = RegExp(r'ne može učitati|ne mogu učitati|nije učitan');

void main() {
  for (final (sirina, velicina) in [
    ('desktop', const Size(1440, 900)),
    ('telefon', const Size(402, 874)),
  ]) {
    for (final ruta in _rute) {
      testWidgets('$sirina · $ruta', (tester) async {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
        addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
        );
        tester.view
          ..physicalSize = velicina
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: demoOverrides(
              const AdminEnv(supabaseUrl: '', supabaseAnonKey: ''),
            ),
            child: const SalonAdminApp(),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byType(AdminLoadError),
          findsNothing,
          reason: '$ruta u demou pokazuje grešku učitavanja',
        );
        expect(
          find.textContaining(_nijeUcitano),
          findsNothing,
          reason: '$ruta u demou javlja da podatak nije stigao',
        );
      });
    }
  }
}
