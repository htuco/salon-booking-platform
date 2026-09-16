import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

/// [AuthRepository] koji ne dodiruje mrežu — jedini koji test smije podići.
///
/// Prava implementacija čita `Supabase.instance`, koji u testu nije inicijalizovan i baca
/// prije prvog frejma. Bez ove zamjene bi svaki widget test koji podigne app-u padao na
/// inicijalizaciji, a ne na onome što mjeri.
///
/// Ponašanje se podešava po testu: [prijavaGreska] i [registracijaGreska] puštaju grešku
/// kroz isti put kojim bi prošla prava, pa ekran ne zna razliku.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AuthSession? pocetnaSesija,
    this.prijavaGreska,
    this.registracijaGreska,
    this.brisanjeGreska,
  }) : _sesija = pocetnaSesija {
    _kontroler.add(_sesija);
  }

  /// Sesija koju vraća uspješan email login ili registracija.
  static const sesijaNakonPrijave = AuthSession(
    userId: 'auth-user-1',
    providers: {'email'},
    email: 'test@example.com',
  );

  final _kontroler = StreamController<AuthSession?>.broadcast();
  AuthSession? _sesija;

  /// Greška koju baca [signInWithPassword], ili `null` za uspjeh.
  final ApiError? prijavaGreska;

  /// Greška koju baca [signUpWithPassword], ili `null` za uspjeh.
  final ApiError? registracijaGreska;

  /// Greška koju baca [deleteAccount], ili `null` za uspjeh. Task 17.
  final ApiError? brisanjeGreska;

  /// Koliko je puta brisanje pozvano — dokaz da dijalog stvarno okine akciju, i da
  /// odustajanje **ne** okine ništa.
  int brojBrisanja = 0;

  int brojPrijava = 0;
  int brojRegistracija = 0;

  /// Zadnja adresa poslana Supabase Authu. Lozinka se namjerno ne čuva u test fakeu.
  String? zadnjiEmail;

  void dispose() => _kontroler.close();

  @override
  Stream<AuthSession?> get sessionChanges => _kontroler.stream;

  @override
  AuthSession? get currentSession => _sesija;

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    brojPrijava++;
    zadnjiEmail = email;
    if (prijavaGreska != null) throw prijavaGreska!;
    _sesija = sesijaNakonPrijave;
    _kontroler.add(_sesija);
    return sesijaNakonPrijave;
  }

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    brojRegistracija++;
    zadnjiEmail = email;
    if (registracijaGreska != null) throw registracijaGreska!;
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

  /// Brisanje naloga (task 17).
  ///
  /// **Odjava je dio brisanja**, isto kao u `SupabaseAuthRepository` — ekran se oslanja na
  /// to da nakon uspjeha sesije više nema. Kad brisanje padne, sesija **ostaje**: korisnik
  /// mora moći pokušati ponovo, a odjava bi mu oduzela jedini token kojim to može.
  @override
  Future<void> deleteAccount() async {
    brojBrisanja++;
    if (brisanjeGreska != null) throw brisanjeGreska!;
    _sesija = null;
    _kontroler.add(null);
  }
}
