import 'package:client/src/core/auth_config_provider.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokazuje da lanac `tenant.yaml → tenants.g.dart → AuthConfig → login ekran` stvarno
/// spaja krajeve. Jedinični testovi u `core_domain` provjeravaju samo `AuthConfig`; ovdje
/// se provjerava da generisani registar nosi ono što `tenant.yaml` kaže.
void main() {
  ProviderContainer container({
    required TenantConfig tenant,
    String googleWebClientId = 'web-client-id',
    bool appleSignIn = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        appEnvProvider.overrideWithValue(
          _env(
            tenant.salonId,
            googleWebClientId: googleWebClientId,
            appleSignIn: appleSignIn,
          ),
        ),
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
        },
      );
    }

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

    // Bez Google client ID-a dugme bi palo na prvom tapu („nije dostupan"), a stajalo bi
    // iznad emaila koji radi. Build bez ID-a ga zato ne nudi (`docs/08` §2.1).
    test('build bez Google client ID-a ne nudi Google', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = container(tenant: kTenants.values.first, googleWebClientId: '');

      expect(c.read(visibleAuthProvidersProvider), [
        AuthProvider.apple,
        AuthProvider.email,
      ]);
    });

    // iOS build potpisan ličnim Apple timom nema Sign in with Apple capability.
    test('APPLE_SIGN_IN=false skida Apple i na iOS-u', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = container(
        tenant: kTenants.values.first,
        googleWebClientId: '',
        appleSignIn: false,
      );

      expect(c.read(visibleAuthProvidersProvider), [AuthProvider.email]);
    });
  });
}

AppEnv _env(
  String salonId, {
  String googleWebClientId = '',
  bool appleSignIn = true,
}) => AppEnv(
  salonId: salonId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
  googleWebClientId: googleWebClientId,
  appleSignIn: appleSignIn,
);
