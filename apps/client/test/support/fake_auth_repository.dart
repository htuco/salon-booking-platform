import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

/// [AuthRepository] koji ne dodiruje mrežu — jedini koji test smije podići.
///
/// Prava implementacija čita `Supabase.instance`, koji u testu nije inicijalizovan i baca
/// prije prvog frejma. Bez ove zamjene bi svaki widget test koji podigne app-u padao na
/// inicijalizaciji, a ne na onome što mjeri.
///
/// Ponašanje se podešava po testu: [otpGreska] i [prijavaGreska] puštaju grešku kroz isti
/// put kojim bi prošla prava, pa ekran ne zna razliku.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AuthSession? pocetnaSesija,
    this.otpGreska,
    this.prijavaGreska,
  }) : _sesija = pocetnaSesija {
    _kontroler.add(_sesija);
  }

  /// Sesija koju vraća uspješna `verifyEmailOtp`.
  static const sesijaNakonPrijave = AuthSession(
    userId: 'auth-user-1',
    providers: {'email'},
    email: 'test@example.com',
  );

  final _kontroler = StreamController<AuthSession?>.broadcast();
  AuthSession? _sesija;

  /// Greška koju baca [requestEmailOtp], ili `null` za uspjeh.
  final ApiError? otpGreska;

  /// Greška koju baca [verifyEmailOtp], ili `null` za uspjeh.
  final ApiError? prijavaGreska;

  /// Koliko je puta kod zatražen — dokaz da „Pošalji ponovo" stvarno šalje.
  int brojZahtjevaZaKod = 0;

  /// Zadnja adresa na koju je kod tražen.
  String? zadnjiEmail;

  void dispose() => _kontroler.close();

  @override
  Stream<AuthSession?> get sessionChanges => _kontroler.stream;

  @override
  AuthSession? get currentSession => _sesija;

  @override
  Future<void> requestEmailOtp(String email) async {
    brojZahtjevaZaKod++;
    zadnjiEmail = email;
    if (otpGreska != null) throw otpGreska!;
  }

  @override
  Future<AuthSession> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    if (prijavaGreska != null) throw prijavaGreska!;
    _sesija = sesijaNakonPrijave;
    _kontroler.add(_sesija);
    return sesijaNakonPrijave;
  }

  @override
  Future<void> signOut() async {
    _sesija = null;
    _kontroler.add(null);
  }

  // Nativni provideri se u testu ne odigravaju — ponašaju se kao i u pravoj app-i danas:
  // bacaju grešku sa imenom paketa koji fali (v. `SupabaseAuthRepository`).
  @override
  Future<AuthSession> signInWithApple() async =>
      throw prijavaGreska ?? const ServerError('Apple prijava nije dostupna');

  @override
  Future<AuthSession> signInWithGoogle() async =>
      throw prijavaGreska ?? const ServerError('Google prijava nije dostupna');

  @override
  Future<AuthSession> signInWithFacebook() async =>
      throw prijavaGreska ??
          const ServerError('Facebook prijava nije dostupna');

  @override
  Future<AuthSession> continueAsGuest({required String name}) async =>
      throw const ServerError('Tok gosta je task 26');

  @override
  Future<void> deleteAccount() async =>
      throw const ServerError('Brisanje naloga je task 17');
}
