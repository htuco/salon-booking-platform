import 'package:core_domain/core_domain.dart';

import '../errors/errors.dart';

/// Ugovor prijave — `docs/06 §6.3`.
///
/// **Nijedan Supabase tip ne prelazi ovu granicu.** Metode primaju i vraćaju tipove iz
/// `core_domain` ([AuthSession]), a greške izlaze kao [ApiError], isto kao iz svakog drugog
/// repozitorija u ovom paketu. Kad se ispod zamijeni backend, mijenja se implementacija —
/// ekran, router i provideri ostaju.
///
/// ## Zašto `Future<AuthSession>` a ne `AuthResult`
///
/// `docs/06 §6.3` je skiciran sa `Future<AuthResult>`. Ovdje se ne uvodi: svaki repozitorij
/// u `core_api` već signalizira grešku bacanjem [ApiError] (pravilo 2 u `core_api.dart`), a
/// drugi način signalizacije u istom paketu znači da ekran mora znati koji repozitorij
/// koristi koji. Otkazivanje od strane korisnika (zatvoren Apple/Google dijalog) nije
/// greška sistema nego očekivan ishod, pa ima vlastiti tip: [AuthCancelledError].
///
/// ## Šta je od ovoga implementirano
///
/// **Ništa — ovo je samo ugovor.** Task 12 postavlja providere i konfiguraciju;
/// `SupabaseAuthRepository` piše [task 13](../../../../tasks/sprint-2/13-client-login-ekran.md),
/// koji je prvi koji ga ima gdje pozvati. Metode koje ni 13 ne treba nose oznaku uz sebe —
/// [continueAsGuest] je task 26, [deleteAccount] task 17.
abstract interface class AuthRepository {
  /// Stanje prijave kroz vrijeme; `null` znači odjavljen.
  ///
  /// Stream, a ne jednokratno čitanje, jer sesija ističe i osvježava se sama
  /// (`jwt_expiry`, refresh token rotacija) — ekran koji bi je pročitao jednom pokazivao bi
  /// prijavljenog korisnika i nakon što token više ne vrijedi.
  Stream<AuthSession?> get sessionChanges;

  /// Trenutna sesija bez čekanja — `null` ako niko nije prijavljen.
  ///
  /// Postoji zbog prvog frejma: router mora sinhrono znati smije li pustiti `/moji-termini`,
  /// a `await` na [sessionChanges] bi tu dao treptaj login ekrana prijavljenom korisniku.
  AuthSession? get currentSession;

  /// Nativni Sign in with Apple (`sign_in_with_apple` → `signInWithIdToken`).
  ///
  /// Nativno, ne web-view: web-view flow radi, ali Apple ga ne voli i izgleda jeftino
  /// (`docs/06 §6.1`).
  Future<AuthSession> signInWithApple();

  /// Nativni Google Sign-In → `signInWithIdToken`. Client ID stiže kroz `--dart-define`
  /// i **razlikuje se po flavoru** (`docs/06 §7.1`).
  Future<AuthSession> signInWithGoogle();

  /// Facebook prijava. Isključena po defaultu u `tenant.yaml` — v.
  /// [AuthProvider.facebook] i `docs/06 §7.4`.
  /// Implementira [task 26](../../../../tasks/sprint-2/26-gost-i-facebook.md).
  Future<AuthSession> signInWithFacebook();

  /// Šalje šestocifreni OTP kod na [email].
  ///
  /// **OTP, nikad magic link.** Link na mobilnom izlazi iz app-a u browser i ne vraća se
  /// pouzdano (`docs/06 §2.1`).
  Future<void> requestEmailOtp(String email);

  /// Provjerava kod iz [requestEmailOtp].
  Future<AuthSession> verifyEmailOtp({
    required String email,
    required String code,
  });

  /// Rezervacija bez naloga; dozvoljeno samo kad je `AuthConfig.allowGuest`.
  /// Implementira [task 26](../../../../tasks/sprint-2/26-gost-i-facebook.md).
  Future<AuthSession> continueAsGuest({required String name});

  Future<void> signOut();

  /// Brisanje naloga — **obavezno za store submission**, ne opciono (`docs/06 §8.2`).
  /// Implementira [task 17](../../../../tasks/sprint-2/17-moj-racun-i-brisanje.md).
  Future<void> deleteAccount();
}
