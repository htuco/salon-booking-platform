import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env/app_env.dart';
import '../generated/tenants.g.dart';

/// Tenant iz build-time registra — fallback vrijednosti dostupne prije prvog odgovora.
final tenantProvider = Provider<TenantConfig?>(
  (ref) => kTenants[ref.watch(appEnvProvider).salonId],
);

/// Veže `core_api` na ovaj build: `currentSalonIdProvider` tamo je namjerno bez
/// implementacije, jer paket ne zna za `--dart-define` ni za generisani tenant registar.
///
/// Ide u `ProviderScope(overrides: ...)` u `main.dart`. Bez njega svaki repozitorij baca
/// `UnimplementedError` na prvom pozivu.
final coreApiOverrides = <Override>[
  currentSalonIdProvider.overrideWith(
    (ref) => ref.watch(appEnvProvider).salonId,
  ),
];

/// Trenutna vertikala — nikad `null`, nikad `throw`.
///
/// Ovo je jedini ulaz koji ekran koristi za terminologiju. Dok podaci stizu (ili ako
/// upit padne) vraca [Vertical.fallback], jer je generic tekst na ekranu bolji od
/// spinnera preko cijelog ekrana i mnogo bolji od `null`-a koji se provlaci kroz svaki
/// `Text`. Greska ostaje citljiva kroz `verticalProvider` za ekrane koje zanima.
///
/// `verticalProvider` i `verticalRepositoryProvider` sada zive u `core_api` — ovaj fajl
/// ih vise ne definise, samo ih koristi. Import `core_api.dart` ih donosi sa sobom.
Vertical verticalOf(WidgetRef ref) =>
    ref.watch(verticalProvider).valueOrNull ?? Vertical.fallback;
