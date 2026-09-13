import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// `SupabaseAuthRepository` — ono što se može dokazati **bez tuđih konzola**. Task 12/13.
///
/// Sam Apple i Google tok se odavde ne može odigrati: traži nativni dijalog, potpisan
/// build i client ID-eve iz `tasks/sprint-2/12-konzole-checklist.md`. Ali jedna stvar se
/// može, i baš ona je najlakša za propustiti — **da build bez konfiguracije padne prije
/// dijaloga, sa porukom koja imenuje šta fali**.
void main() {
  group('Google prijava bez konfiguracije', () {
    test('prazan web client ID baca prije nego što dijalog otvori', () async {
      final repo = SupabaseAuthRepository(_MockSupabaseClient());

      // Pad **prije** dijaloga je cijela poenta. Kad bi se pucalo poslije, korisnik bi
      // prošao kroz Google ekran, izabrao nalog, i tek onda dobio grešku — što izgleda
      // kao da je Google odbio njegov nalog, a ne kao da je build pogrešno konfigurisan.
      await expectLater(
        repo.signInWithGoogle(),
        throwsA(
          isA<ServerError>().having(
            (e) => e.message,
            'poruka imenuje varijablu i checklist',
            allOf(
              contains('GOOGLE_WEB_CLIENT_ID'),
              contains('12-konzole-checklist'),
            ),
          ),
        ),
      );
    });

    test('podrazumijevano nema Google konfiguracije', () {
      final repo = SupabaseAuthRepository(_MockSupabaseClient());

      // Prazno je **ispravno stanje**, ne greška pri konstrukciji: većina buildova danas
      // nema Google, a app mora raditi sa email OTP-om.
      expect(repo.google, bezGoogleKlijenata);
      expect(repo.google.web, isEmpty);
    });

    test('client ID-evi stižu kroz konstruktor, ne iz `--dart-define`', () {
      // `core_api` ne zna za `--dart-define` — most je `googleClientIdsProvider`, koji app
      // override-uje (v. `coreApiOverrides`). Ovaj test drži tu granicu: kad bi repozitorij
      // sam čitao okruženje, admin app bi dobila barberove client ID-eve.
      final repo = SupabaseAuthRepository(
        _MockSupabaseClient(),
        google: (web: 'web-id.apps.googleusercontent.com', ios: 'ios-id'),
      );

      expect(repo.google.web, 'web-id.apps.googleusercontent.com');
      expect(repo.google.ios, 'ios-id');
    });
  });

  group('AuthProvider i platforma', () {
    // Ovo nije test paketa nego **politike App Review-a**, zapisane kao kod. Apple na
    // Androidu nema nativni tok, a Google ga ima na obje.
    test('Apple postoji samo na iOS-u', () {
      expect(AuthProvider.apple.isAvailableOn(AuthPlatform.ios), isTrue);
      expect(AuthProvider.apple.isAvailableOn(AuthPlatform.android), isFalse);
    });

    test('Apple je prvi u listi za iOS — pravilo 4.8', () {
      const config = AuthConfig(
        enabled: {AuthProvider.google, AuthProvider.apple, AuthProvider.email},
        allowGuest: false,
      );

      // Redoslijed dolazi iz deklaracije enuma, ne iz redoslijeda u `enabled` setu —
      // zato je `google` ovdje namjerno naveden prvi.
      expect(config.forPlatform(AuthPlatform.ios).first, AuthProvider.apple);
    });

    test('na Androidu Apple ispada iz liste, bez greške', () {
      const config = AuthConfig(
        enabled: {AuthProvider.apple, AuthProvider.google, AuthProvider.email},
        allowGuest: false,
      );

      expect(config.forPlatform(AuthPlatform.android), [
        AuthProvider.google,
        AuthProvider.email,
      ]);
    });
  });
}
