import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../generated/tenants.g.dart';

/// `SALON_ID` je jedini `--dart-define` koji build prosljeđuje; ostalo se traži u
/// generisanom registru (`tenants.g.dart`) i, u runtime-u, na backendu.
const kSalonId = String.fromEnvironment('SALON_ID');

/// Tenant iz build-time registra — fallback vrijednosti dostupne prije prvog odgovora.
final tenantProvider = Provider<TenantConfig?>((ref) => kTenants[kSalonId]);

/// Supabase klijent. Prava inicijalizacija (`Supabase.initialize`) dolazi u tasku 07;
/// dok je nema, test i preview override-uju ovaj provider i nikad ne dodirnu mrežu.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final verticalRepositoryProvider = Provider<VerticalRepository>(
  (ref) => VerticalRepository(ref.watch(supabaseClientProvider)),
);

/// Vertikala salona, učitana sa backenda.
///
/// `AsyncValue` namjerno ostaje vidljiv pozivaocu umjesto da se sakrije iza fallbacka —
/// ekran razlikuje "još učitavam" od "učitano". Za sam tekst se koristi [verticalOf],
/// koji do prvog odgovora vraća [Vertical.fallback].
final verticalProvider = FutureProvider<Vertical>((ref) async {
  final repository = ref.watch(verticalRepositoryProvider);
  return repository.fetchForSalon(kSalonId);
});

/// Trenutna vertikala — nikad `null`, nikad `throw`.
///
/// Ovo je jedini ulaz koji ekran koristi za terminologiju. Dok podaci stižu (ili ako
/// upit padne) vraća [Vertical.fallback], jer je generic tekst na ekranu bolji od
/// spinnera preko cijelog ekrana i mnogo bolji od `null`-a koji se provlači kroz svaki
/// `Text`. Greška ostaje čitljiva kroz [verticalProvider] za ekrane koje zanima.
Vertical verticalOf(WidgetRef ref) =>
    ref.watch(verticalProvider).valueOrNull ?? Vertical.fallback;

/// Isto, ali iz `build` metode koja ima samo `BuildContext` (npr. u `MaterialApp.builder`).
extension VerticalContext on WidgetRef {
  Vertical get vertical => verticalOf(this);
}
