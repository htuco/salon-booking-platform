/// Demo ulaz za vizuelni dokaz home ekrana — **nije production entry point.**
///
/// Store build ide kroz `lib/main.dart` i `tool/build_tenant.sh`; ovaj fajl postoji da se
/// ekran može otvoriti i snimiti bez pristupa backendu. Podaci su prepisani iz
/// `supabase/seed.sql` i vrijede tačno onoliko koliko im seed odgovara.
///
/// Ono što se ovim dokazuje je upravo ono što task 10 traži: **isti kod, drugi
/// `SALON_ID`, drugi salon, druge boje, druga terminologija.** Provideri se pune iz
/// registra po `SALON_ID`-u, isto kao što bi ih napunio repozitorij — mijenja se izvor
/// podataka, ne ekran.
///
/// ```sh
/// flutter run -d chrome -t lib/demo_main.dart \
///   --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'src/core/env/bootstrap.dart';
import 'src/demo/demo_overrides.dart';

Future<void> main() async {
  // Isti bootstrap kao production: `usePathUrlStrategy` i `AppEnv.fromDefines`. Bez
  // `SUPABASE_URL`-a `hasSupabase` je `false`, pa se `Supabase.initialize` preskače i
  // mreža se nikad ne dodirne.
  final env = await bootstrapClient();

  // Podaci i override-i su u `src/demo/demo_overrides.dart` (FE-505), da ih test može
  // podići istom listom kojom ih podiže ovaj ulaz.
  runApp(
    ProviderScope(overrides: demoOverrides(env), child: const SalonClientApp()),
  );
}
