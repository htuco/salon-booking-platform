import 'package:core_api/core_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Da li klijent vidi cijene (task 44).
///
/// Dva uslova, i oba moraju stajati: **vertikala** mora uopšte imati cijene
/// (`features.prices` — ordinacija ih npr. ne pokazuje), a **salon** ih nije sakrio u admin
/// Postavkama (`salon_settings.show_prices_in_app`). Do taska 44 je ekran čitao samo prvi
/// uslov, pa prekidač „Prikaži cijene u aplikaciji" nije mijenjao ništa.
///
/// Dok postavke ne stignu, odlučuje vertikala — ista rezerva kao `minCancelHoursProvider`.
final prikaziCijeneProvider = Provider<bool>((ref) {
  final vertical = ref.watch(verticalProvider).valueOrNull;
  if (vertical != null && !vertical.features.prices) return false;
  final postavke = ref.watch(salonSettingsProvider).valueOrNull;
  return postavke?.showPricesInApp ?? vertical?.rules.showPricesInApp ?? true;
});
