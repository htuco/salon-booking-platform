import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env/app_env.dart';
import '../generated/tenants.g.dart';

/// Tenant iz build-time registra — fallback vrijednosti dostupne prije prvog odgovora.
final tenantProvider = Provider<TenantConfig?>(
  (ref) => kTenants[ref.watch(appEnvProvider).salonId],
);

/// Supabase klijent. `bootstrapClient()` ga inicijalizuje prije `runApp`; test override-uje
/// ovaj provider i nikad ne dodirne mrezu.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final verticalRepositoryProvider = Provider<VerticalRepository>(
  (ref) => VerticalRepository(ref.watch(supabaseClientProvider)),
);

/// Vertikala salona, ucitana sa backenda.
///
/// `AsyncValue` namjerno ostaje vidljiv pozivaocu umjesto da se sakrije iza fallbacka —
/// ekran razlikuje "jos ucitavam" od "ucitano". Za sam tekst se koristi [verticalOf],
/// koji do prvog odgovora vraca [Vertical.fallback].
final verticalProvider = FutureProvider<Vertical>((ref) async {
  final repository = ref.watch(verticalRepositoryProvider);
  return repository.fetchForSalon(ref.watch(appEnvProvider).salonId);
});

/// Trenutna vertikala — nikad `null`, nikad `throw`.
///
/// Ovo je jedini ulaz koji ekran koristi za terminologiju. Dok podaci stizu (ili ako
/// upit padne) vraca [Vertical.fallback], jer je generic tekst na ekranu bolji od
/// spinnera preko cijelog ekrana i mnogo bolji od `null`-a koji se provlaci kroz svaki
/// `Text`. Greska ostaje citljiva kroz [verticalProvider] za ekrane koje zanima.
Vertical verticalOf(WidgetRef ref) =>
    ref.watch(verticalProvider).valueOrNull ?? Vertical.fallback;
