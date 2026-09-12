import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// U kojem je koraku prijava. Email OTP je jedini tok sa više od jednog ekrana.
enum LoginPhase {
  /// Izbor načina prijave — dugmad iz `visibleAuthProvidersProvider`.
  providers,

  /// Unos email adrese; odavde ide `requestEmailOtp`.
  email,

  /// Unos šestocifrenog koda; odavde ide `verifyEmailOtp`.
  code,
}

/// Stanje login ekrana — **greška je polje, ne događaj**.
///
/// Task 13 to traži doslovno: „greška prijave je stanje ekrana, ne `SnackBar` koji
/// nestane". Razlog je konkretan: pogrešno prekucan kod je najčešći ishod na ovom ekranu,
/// a `SnackBar` nestane prije nego što korisnik stigne da pogleda mail po drugi put.
@immutable
class LoginState {
  const LoginState({
    this.phase = LoginPhase.providers,
    this.email = '',
    this.busy = false,
    this.error,
    this.notice,
  });

  final LoginPhase phase;

  /// Adresa na koju je kod poslan. Nosi je stanje, ne polje za unos — korak sa kodom je
  /// mora prikazati („Kod smo poslali na …"), a `TextEditingController` prethodnog koraka
  /// do tada više ne postoji.
  final String email;

  /// Zahtjev je u letu. Blokira CTA — drugi tap bi poslao drugi kod i poništio prvi.
  final bool busy;

  /// Zadnja greška, ili `null`. Briše se pri svakoj novoj akciji, ne po isteku vremena.
  final ApiError? error;

  /// Poruka koja nije greška („Novi kod je poslan"). Odvojena od [error] da se ne bi
  /// crtala u istoj, crvenoj kutiji.
  final String? notice;

  LoginState kopija({
    LoginPhase? phase,
    String? email,
    bool? busy,
    ApiError? error,
    String? notice,
    bool ocistiPoruke = false,
  }) => LoginState(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    busy: busy ?? this.busy,
    error: ocistiPoruke ? error : (error ?? this.error),
    notice: ocistiPoruke ? notice : (notice ?? this.notice),
  );
}

/// Vodi prijavu kroz korake i drži jedini izvor istine za ono što ekran crta.
///
/// **Ekran ne zove `supabase.auth` i ne poznaje `AuthRepository` direktno** — korak 2 iz
/// taska 13. Kad se ispod zamijeni backend, mijenja se repozitorij; ovaj notifier i ekran
/// ostaju.
final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

class LoginController extends AutoDisposeNotifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Prelazak na unos emaila. Zove ga dugme „Nastavi sa emailom".
  void pocniEmail() {
    state = state.kopija(phase: LoginPhase.email, ocistiPoruke: true);
  }

  /// Nazad na izbor providera sa bilo kojeg koraka.
  void nazadNaProvidere() {
    state = state.kopija(phase: LoginPhase.providers, ocistiPoruke: true);
  }

  /// Nazad na unos emaila sa koraka sa kodom — korisnik je promašio adresu.
  void promijeniEmail() {
    state = state.kopija(phase: LoginPhase.email, ocistiPoruke: true);
  }

  /// Šalje OTP kod na [email] i prelazi na korak sa kodom.
  ///
  /// Vraća `true` kad je kod otišao. Pri ponovnom slanju ([ponovoPosalji]) korak ostaje
  /// isti, pa poziv nosi `prelazi`.
  Future<bool> posaljiKod(String email, {bool prelazi = true}) async {
    final adresa = email.trim();
    state = state.kopija(busy: true, ocistiPoruke: true);

    try {
      await _repository.requestEmailOtp(adresa);
      state = state.kopija(
        phase: prelazi ? LoginPhase.code : null,
        email: adresa,
        busy: false,
        ocistiPoruke: true,
      );
      return true;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiPoruke: true);
      return false;
    }
  }

  /// Ponovno slanje koda na već poznatu adresu.
  Future<void> ponovoPosalji(String poruka) async {
    if (await posaljiKod(state.email, prelazi: false)) {
      state = state.kopija(notice: poruka, ocistiPoruke: true);
    }
  }

  /// Provjerava kod. Vraća sesiju kad je prijava prošla, `null` kad nije.
  ///
  /// Ekran na osnovu toga navigira — ne notifier: navigacija traži `context`, a ovdje ga
  /// nema. Isti razlog kao u `BookingSubmitNotifier.submit`.
  Future<AuthSession?> potvrdiKod(String code) async {
    state = state.kopija(busy: true, ocistiPoruke: true);

    try {
      final sesija = await _repository.verifyEmailOtp(
        email: state.email,
        code: code.trim(),
      );
      state = state.kopija(busy: false, ocistiPoruke: true);
      return sesija;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiPoruke: true);
      return null;
    }
  }

  /// Nativna prijava (Apple, Google, Facebook).
  ///
  /// Danas svaki od njih završi greškom — paketi iz `docs/06 §6.1` nisu u `pubspec.yaml`,
  /// a client ID-evi iz `12-konzole-checklist.md` nisu upisani. Poziv ipak ide kroz
  /// repozitorij, ne kroz `if` u ekranu: kad paket stigne, mijenja se jedna implementacija
  /// i ovaj kod ostaje.
  Future<AuthSession?> prijaviSe(AuthProvider provider) async {
    state = state.kopija(busy: true, ocistiPoruke: true);

    try {
      final sesija = await switch (provider) {
        AuthProvider.apple => _repository.signInWithApple(),
        AuthProvider.google => _repository.signInWithGoogle(),
        AuthProvider.facebook => _repository.signInWithFacebook(),
        // Email nije nativan tok — do ovdje ne stiže, ekran ga vodi na `pocniEmail`.
        AuthProvider.email => throw const ServerError(
          'Email prijava ide kroz OTP korake, ne kroz prijaviSe',
        ),
      };
      state = state.kopija(busy: false, ocistiPoruke: true);
      return sesija;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiPoruke: true);
      return null;
    }
  }
}
