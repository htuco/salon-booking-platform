/// Demo ulaz za vizuelni dokaz admin ljuske — **nije production entry point.**
///
/// Production build ide kroz `lib/main.dart`. Ovaj fajl postoji jer se admin ekran
/// **ne može vidjeti bez prijave**, a prijava traži backend: router pušta dalje tek kad
/// `currentStaffProvider` vrati `salon_admin`. Bez lokalnog stacka (Docker, `supabase`
/// CLI) to znači da se ljuska ne bi vidjela nijednom — task 28 je iz tog razloga ostavio
/// „dashboard nije viđen na ekranu" kao dug.
///
/// Isti obrazac kao `apps/client/lib/demo_main.dart` iz taska 11: provideri se pune
/// ručno, mreža se ne dodiruje.
///
/// **Šta ovo dokazuje, a šta ne.** Dokazuje raspored, breakpoint, navigaciju i temu —
/// ono što task 29 tvrdi. Ne dokazuje prijavu, RLS ni prave podatke; to traži živi
/// backend i `tool/run_live_demo.sh admin`.
///
/// ```sh
/// # desktop ljuska
/// flutter run -d chrome -t lib/demo_main.dart
/// # telefonska ljuska — suzi prozor ispod 840 px, ili
/// flutter build web -t lib/demo_main.dart
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'src/core/env/bootstrap.dart';
import 'src/demo/demo_overrides.dart';

Future<void> main() async {
  // Isti bootstrap kao production. Bez `SUPABASE_URL`-a `hasSupabase` je `false`, pa se
  // `Supabase.initialize` preskače i mreža se nikad ne dodirne.
  final env = await bootstrapAdmin();

  // Podaci i override-i su u `src/demo/demo_overrides.dart` (FE-505).
  runApp(
    ProviderScope(overrides: demoOverrides(env), child: const SalonAdminApp()),
  );
}
