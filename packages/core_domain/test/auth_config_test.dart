import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AuthProvider', () {
    test('wireName prati imena iz Supabasea i tenant.yaml', () {
      expect(AuthProvider.values.map((p) => p.wireName), [
        'apple',
        'google',
        'email',
      ]);
    });

    test('fromWire vraća null za nepoznato, ne baca', () {
      expect(AuthProvider.fromWire('google'), AuthProvider.google);
      expect(AuthProvider.fromWire('passkey'), isNull);
      expect(AuthProvider.fromWire(null), isNull);
      expect(AuthProvider.fromWire(''), isNull);
    });

    test('Apple ima implementaciju samo na iOS-u', () {
      expect(AuthProvider.apple.isAvailableOn(AuthPlatform.ios), isTrue);
      expect(AuthProvider.apple.isAvailableOn(AuthPlatform.android), isFalse);
      expect(AuthProvider.apple.isAvailableOn(AuthPlatform.web), isFalse);
    });
  });

  group('AuthConfig.forPlatform', () {
    // DoD taska 12: na iOS-u lista sadrži Apple, na Androidu ne.
    test('iOS nudi Apple, Android ne — isti config', () {
      const config = AuthConfig.fallback;

      expect(config.forPlatform(AuthPlatform.ios), [
        AuthProvider.apple,
        AuthProvider.google,
        AuthProvider.email,
      ]);
      expect(config.forPlatform(AuthPlatform.android), [
        AuthProvider.google,
        AuthProvider.email,
      ]);
      expect(
        config.forPlatform(AuthPlatform.android),
        isNot(contains(AuthProvider.apple)),
      );
    });

    test('tenant ne može uključiti Apple na Androidu', () {
      const config = AuthConfig(enabled: {AuthProvider.apple});

      expect(config.forPlatform(AuthPlatform.android), isEmpty);
      expect(config.forPlatform(AuthPlatform.ios), [AuthProvider.apple]);
    });

    test('platforma ne uvodi provider koji tenant nije uključio', () {
      const config = AuthConfig(enabled: {AuthProvider.email});

      expect(config.forPlatform(AuthPlatform.ios), [AuthProvider.email]);
      expect(
        config.forPlatform(AuthPlatform.ios),
        isNot(contains(AuthProvider.google)),
      );
    });

    test('Apple je prvi na iOS-u — App Review 4.8', () {
      const config = AuthConfig(
        enabled: {AuthProvider.google, AuthProvider.email, AuthProvider.apple},
      );

      expect(config.forPlatform(AuthPlatform.ios).first, AuthProvider.apple);
    });

    test('web nudi samo email — nativni tokovi tamo nemaju implementaciju', () {
      const config = AuthConfig(
        enabled: {AuthProvider.apple, AuthProvider.google, AuthProvider.email},
      );

      expect(config.forPlatform(AuthPlatform.web), [AuthProvider.email]);
    });
  });

  group('AuthConfig.fromNames', () {
    test('mapira imena iz tenant.yaml', () {
      final config = AuthConfig.fromNames(const ['apple', 'google', 'email']);

      expect(config, AuthConfig.fallback);
    });

    test('nepoznato ime se ispušta, ostatak preživi', () {
      // `facebook` je namjerno među nepoznatima: bio je validan provider pa je uklonjen
      // (ADR-0011). Zaostao u bazi ili u starom buildu ne smije vaskrsnuti dugme kojem
      // nema implementacije iza.
      final config = AuthConfig.fromNames(const [
        'google',
        'passkey',
        'facebook',
        'email',
      ]);

      expect(config.enabled, {AuthProvider.google, AuthProvider.email});
    });

    test('prazna lista daje prazan config, ne fallback', () {
      final config = AuthConfig.fromNames(const []);

      expect(config.enabled, isEmpty);
      expect(config.forPlatform(AuthPlatform.ios), isEmpty);
    });
  });

  group('AuthConfig jednakost', () {
    test('poredi po sadržaju, ne po identitetu skupa', () {
      const a = AuthConfig(enabled: {AuthProvider.google, AuthProvider.email});
      const b = AuthConfig(enabled: {AuthProvider.email, AuthProvider.google});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith mijenja samo traženo', () {
      final config = AuthConfig.fallback.copyWith(
        enabled: {AuthProvider.email},
      );

      expect(config.enabled, {AuthProvider.email});
    });
  });
}
