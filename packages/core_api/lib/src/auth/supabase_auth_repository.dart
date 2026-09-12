import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'auth_repository.dart';

/// [AuthRepository] nad Supabase Authom — jedino mjesto koje zna za `GoTrueClient`.
///
/// Task 12 je ostavio ugovor i konfiguraciju; ovo je prva implementacija
/// ([task 13](../../../../../tasks/sprint-2/13-client-login-ekran.md)).
///
/// ## Šta ovdje stvarno radi, a šta ne
///
/// **Email OTP radi u cijelosti** — `signInWithOtp` pa `verifyOTP`, oboje kroz
/// `supabase_flutter`, koji je već zavisnost ovog paketa. To je i jedini provider koji se
/// može dokazati bez tuđih konzola (`docs/06 §7.3`: nula minuta po flavoru).
///
/// **Apple, Google i Facebook bacaju, ne vraćaju praznu sesiju.** Nativni tok traži pakete
/// kojih u `pubspec.yaml` nema (`sign_in_with_apple`, `google_sign_in`,
/// `flutter_facebook_auth` — `docs/06 §6.1`), a i sa njima bi ostao nedokazan: client
/// ID-evi iz `tasks/sprint-2/12-konzole-checklist.md` nisu upisani, pa bi prvi poziv pao u
/// Google/Apple dijalogu. Tiho vraćanje `null`-a bi to sakrilo do prvog uređaja; baca se
/// [ServerError] sa imenom paketa koji fali.
///
/// ## Zašto se ne koristi `supabase.auth.currentUser` iznad ovog sloja
///
/// `User` nosi `appMetadata`, `identities` i još desetak polja vezanih za konkretan
/// backend. Granica je u `AuthSession` (`core_domain`) i drži se ovdje, jednom funkcijom
/// [_sesija] — v. `core_api.dart`, pravilo 2.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthSession?> get sessionChanges =>
      _auth.onAuthStateChange.map((state) => _sesija(state.session));

  @override
  AuthSession? get currentSession => _sesija(_auth.currentSession);

  @override
  Future<void> requestEmailOtp(String email) => guard(() async {
    await _auth.signInWithOtp(
      email: email.trim(),
      // Klijent salona nema gdje da se "registruje" prije prve rezervacije — prva
      // prijava **jeste** registracija (`docs/06 §1.1`: nikad forma za registraciju).
      shouldCreateUser: true,
    );
  });

  @override
  Future<AuthSession> verifyEmailOtp({
    required String email,
    required String code,
  }) => guard(() async {
    final odgovor = await _auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      // `OtpType.email`, ne `signup`: isti tip pokriva i prvu prijavu i svaku sljedeću,
      // jer `shouldCreateUser` iznad već odlučuje hoće li nalog nastati. Sa `signup` bi
      // postojeći korisnik dobio "Token has expired or is invalid" na tačan kod.
      type: OtpType.email,
    );

    final sesija = _sesija(odgovor.session);
    if (sesija == null) {
      // Ne bi trebalo da se desi: `verifyOTP` bez sesije, a bez greške. Ako se desi,
      // ekran mora dobiti grešku — inače bi korisnik ostao na login ekranu bez poruke.
      throw const ServerError('Prijava nije vratila sesiju');
    }
    return sesija;
  });

  @override
  Future<void> signOut() => guard(() => _auth.signOut());

  @override
  Future<AuthSession> signInWithApple() =>
      throw _nedostajePaket('Apple', 'sign_in_with_apple');

  @override
  Future<AuthSession> signInWithGoogle() =>
      throw _nedostajePaket('Google', 'google_sign_in');

  @override
  Future<AuthSession> signInWithFacebook() =>
      throw _nedostajePaket('Facebook', 'flutter_facebook_auth');

  @override
  Future<AuthSession> continueAsGuest({required String name}) =>
      throw ServerError(
        'Tok gosta nije implementiran — task 26 (tasks/sprint-2/26-gost-i-facebook.md)',
      );

  @override
  Future<void> deleteAccount() => throw ServerError(
    'Brisanje naloga nije implementirano — task 17 '
    '(tasks/sprint-2/17-moj-racun-i-brisanje.md)',
  );

  /// Greška sa imenom paketa koji fali, umjesto `UnimplementedError`.
  ///
  /// [ApiError] zato što ekran hvata samo njega (`core_api.dart`, pravilo 2): sa
  /// `UnimplementedError` bi nativno dugme rušilo ekran umjesto da prikaže poruku.
  ApiError _nedostajePaket(String provider, String paket) => ServerError(
    '$provider prijava još nije dostupna — traži paket `$paket` i client ID iz '
    'tasks/sprint-2/12-konzole-checklist.md',
  );

  /// Supabaseova `Session` → domenski [AuthSession]. Jedina tačka prevoda.
  AuthSession? _sesija(Session? session) {
    final user = session?.user;
    if (user == null) return null;

    return AuthSession(
      userId: user.id,
      providers: _provideri(user),
      email: user.email,
      isAnonymous: user.isAnonymous,
    );
  }

  /// Provideri povezani sa nalogom.
  ///
  /// Čita se `identities` kad postoji, jer je to stvarna lista veza; `app_metadata` je
  /// fallback za odgovore koji identitete ne uključuju (npr. osvježen token). Oba su
  /// `dynamic` sa strane Supabasea, pa se filtriraju na `String` prije nego izađu — u
  /// `AuthSession` ulazi `Set<String>`, ne `Set<dynamic>` koji bi pukao tek pri upotrebi.
  Set<String> _provideri(User user) {
    final identiteti = user.identities;
    if (identiteti != null && identiteti.isNotEmpty) {
      return identiteti.map((i) => i.provider).toSet();
    }

    final iz = user.appMetadata['providers'];
    if (iz is List) return iz.whereType<String>().toSet();

    final jedan = user.appMetadata['provider'];
    return jedan is String ? {jedan} : const <String>{};
  }
}
