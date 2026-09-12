import 'package:client/src/core/auth_config_provider.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokazuje da lanac `tenant.yaml → tenants.g.dart → AuthConfig → login ekran` stvarno
/// spaja krajeve. Jedinični testovi u `core_domain` provjeravaju samo `AuthConfig`; ovdje
/// se provjerava da generisani registar nosi ono što `tenant.yaml` kaže i da runtime
/// override sa backenda radi.
void main() {
  ProviderContainer container({
    required TenantConfig tenant,
    SalonSettings? settings,
  }) {
    final c = ProviderContainer(
      overrides: [
        appEnvProvider.overrideWithValue(_env(tenant.salonId)),
        if (settings != null)
          salonSettingsProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('authConfigProvider', () {
    for (final tenant in kTenants.values) {
      test('lista dolazi iz tenant.yaml — ${tenant.flavor}', () {
        final config = container(tenant: tenant).read(authConfigProvider);

        expect(
          config.enabled.map((p) => p.wireName).toList()..sort(),
          tenant.authProviders.toList()..sort(),
          reason:
              '${tenant.flavor}: registar i AuthConfig se raziđu — '
              'pokreni dart run tool/gen_flavors.dart',
        );
      });

      test(
        'oba demo tenanta nude Apple, Google i email — ${tenant.flavor}',
        () {
          final config = container(tenant: tenant).read(authConfigProvider);

          expect(config.enabled, {
            AuthProvider.apple,
            AuthProvider.google,
            AuthProvider.email,
          });
          expect(config.enabled, isNot(contains(AuthProvider.facebook)));
          expect(config.allowGuest, isFalse);
        },
      );
    }

    test('salon_settings nadjača allowGuestBooking iz tenant.yaml', () async {
      final tenant = kTenants.values.first;
      final c = container(
        tenant: tenant,
        settings: const SalonSettings(
          id: 'x',
          salonId: 'y',
          allowGuestBooking: true,
        ),
      );

      // Prvi frame: backend još nije odgovorio, vrijedi tenant.yaml.
      expect(c.read(authConfigProvider).allowGuest, isFalse);

      await c.read(salonSettingsProvider.future);

      expect(
        c.read(authConfigProvider).allowGuest,
        isTrue,
        reason:
            'izvor istine za gosta je salon_settings — vlasnik ga mijenja bez '
            'novog builda',
      );
    });

    test('SALON_ID van registra pada na AuthConfig.fallback', () {
      final c = ProviderContainer(
        overrides: [
          appEnvProvider.overrideWithValue(
            _env('00000000-0000-0000-0000-000000000000'),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(authConfigProvider), AuthConfig.fallback);
    });
  });

  group('visibleAuthProvidersProvider', () {
    // DoD taska 12, na nivou app-a: isti build, druga platforma, druga lista.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('iOS nudi Apple', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = container(tenant: kTenants.values.first);

      expect(c.read(visibleAuthProvidersProvider), [
        AuthProvider.apple,
        AuthProvider.google,
        AuthProvider.email,
      ]);
    });

    test('Android ne nudi Apple', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final c = container(tenant: kTenants.values.first);

      final vidljivi = c.read(visibleAuthProvidersProvider);

      expect(vidljivi, isNot(contains(AuthProvider.apple)));
      expect(vidljivi, [AuthProvider.google, AuthProvider.email]);
    });
  });
}

AppEnv _env(String salonId) =>
    AppEnv(salonId: salonId, supabaseUrl: '', supabaseAnonKey: '', apiUrl: '');
