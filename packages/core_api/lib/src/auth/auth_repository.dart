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
/// Google OAuth client ID-evi za jedan build (`docs/06 §7.1`).
///
/// Dva su, ne jedan:
/// - [web] je `serverClientId` — ono što Supabase provjerava kao `aud` u ID tokenu, i
///   **isto je za sve flavore**, jer ga korisnik nikad ne vidi;
/// - [ios] je client ID te konkretne iOS app-e, **po flavoru**, jer ga Google veže za
///   bundle ID. Android ga ne traži: tamo plugin izvodi klijenta iz potpisa APK-a.
///
/// Prazne vrijednosti su ispravno stanje — znače „Google nije konfigurisan za ovaj build".
typedef GoogleClientIds = ({String web, String ios});

/// Build bez Google konfiguracije. Ne baca pri konstrukciji: greška se javlja tek kad
/// korisnik stvarno pokuša Google prijavu, sa porukom koja imenuje šta fali.
const GoogleClientIds bezGoogleKlijenata = (web: '', ios: '');

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

  /// Prijava postojećeg korisnika email adresom i lozinkom.
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  /// Registracija email adresom i lozinkom.
  ///
  /// Demo Supabase projekat privremeno ima isključenu potvrdu emaila, pa uspješan poziv
  /// mora odmah vratiti sesiju. Produkcijski confirmation tok je zasebna faza taska 27.
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  });

  /// Rezervacija bez naloga; dozvoljeno samo kad je `AuthConfig.allowGuest`.
  ///
  /// **Nema task iza sebe.** Task 26 je nosio i tok gosta i Facebook; skinut je sa plana kad
  /// je Facebook otpao ([ADR-0011](../../../../docs/adr/0011-facebook-login-se-ne-implementira.md)),
  /// pa gost čeka novi raspis. Dotle implementacija baca grešku.
  Future<AuthSession> continueAsGuest({required String name});

  Future<void> signOut();

  /// Brisanje naloga — **obavezno za store submission**, ne opciono (`docs/06 §8.2`).
  /// Implementira [task 17](../../../../tasks/sprint-2/17-moj-racun-i-brisanje.md).
  Future<void> deleteAccount();
}
