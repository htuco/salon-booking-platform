import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vertical_provider.dart';

/// Koji se provideri prijave nude u ovom buildu — **nikad `null`, nikad `AsyncLoading`**.
///
/// Isti fallback lanac i isti razlog kao `appThemeProvider`: login ekran mora imati šta
/// iscrtati u prvom frejmu, prije nego što backend odgovori.
///
/// 1. `auth:` blok iz `tenant.yaml`, kroz generisani registar (`tenants.g.dart`);
/// 2. [AuthConfig.fallback] — build bez tenanta u registru (test, `SALON_ID` koji nije
///    regenerisan).
///
final authConfigProvider = Provider<AuthConfig>((ref) {
  final tenant = ref.watch(tenantProvider);
  return tenant == null
      ? AuthConfig.fallback
      : AuthConfig.fromNames(tenant.authProviders);
});

/// Provideri koje login ekran stvarno crta — filtrirani po platformi na kojoj app radi.
///
/// Ekran čita **ovo**, ne [authConfigProvider]: `forPlatform` je jedino mjesto koje zna da
/// Apple na Androidu ne postoji, i to znanje ne smije završiti kao `if` u widgetu
/// (`docs/06 §6.2`).
final visibleAuthProvidersProvider = Provider<List<AuthProvider>>(
  (ref) => ref.watch(authConfigProvider).forPlatform(currentAuthPlatform),
);
