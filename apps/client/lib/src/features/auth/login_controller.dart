import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Korak prijave. Email login i registracija su eksplicitne radnje: odgovor servera se
/// ne koristi za pogađanje postoji li račun.
enum LoginPhase { providers, signIn, signUp }

/// Stanje login ekrana — greška ostaje na ekranu dok korisnik ne pokrene novu akciju.
@immutable
class LoginState {
  const LoginState({
    this.phase = LoginPhase.providers,
    this.busy = false,
    this.error,
  });

  final LoginPhase phase;
  final bool busy;
  final ApiError? error;

  LoginState kopija({
    LoginPhase? phase,
    bool? busy,
    ApiError? error,
    bool ocistiGresku = false,
  }) => LoginState(
    phase: phase ?? this.phase,
    busy: busy ?? this.busy,
    error: ocistiGresku ? error : (error ?? this.error),
  );
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

class LoginController extends AutoDisposeNotifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Email počinje **registracijom** (task 66). Novi korisnik je češći od postojećeg na
  /// ovom ekranu, a do sada je do forme imao pet tapova: prijava, pa „Nemate račun?".
  void pocniEmail() {
    state = state.kopija(phase: LoginPhase.signUp, ocistiGresku: true);
  }

  void otvoriRegistraciju() {
    state = state.kopija(phase: LoginPhase.signUp, ocistiGresku: true);
  }

  void otvoriPrijavu() {
    state = state.kopija(phase: LoginPhase.signIn, ocistiGresku: true);
  }

  void nazadNaProvidere() {
    state = state.kopija(phase: LoginPhase.providers, ocistiGresku: true);
  }

  /// Email + lozinka. Lozinka se prosljeđuje doslovno; samo email se trimuje.
  Future<AuthSession?> prijaviEmail(String email, String password) async {
    state = state.kopija(busy: true, ocistiGresku: true);
    try {
      final sesija = await _repository.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = state.kopija(busy: false, ocistiGresku: true);
      return sesija;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiGresku: true);
      return null;
    }
  }

  /// Registracija sa imenom, telefonom i prihvatanjem uslova (task 66). Hostovani projekat
  /// nema potvrdu emaila, pa uspjeh odmah vraća sesiju.
  Future<AuthSession?> registrujEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required bool acceptedTerms,
  }) async {
    state = state.kopija(busy: true, ocistiGresku: true);
    try {
      final sesija = await _repository.signUpWithPassword(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
        phone: phone.trim(),
        acceptedTerms: acceptedTerms,
      );
      state = state.kopija(busy: false, ocistiGresku: true);
      return sesija;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiGresku: true);
      return null;
    }
  }

  /// Nativna prijava (Apple, Google).
  Future<AuthSession?> prijaviSe(AuthProvider provider) async {
    state = state.kopija(busy: true, ocistiGresku: true);

    try {
      final sesija = await switch (provider) {
        AuthProvider.apple => _repository.signInWithApple(),
        AuthProvider.google => _repository.signInWithGoogle(),
        AuthProvider.email => throw const ServerError(
          'Email prijava ide kroz password ekran, ne kroz prijaviSe',
        ),
      };
      state = state.kopija(busy: false, ocistiGresku: true);
      return sesija;
    } on ApiError catch (error) {
      state = state.kopija(busy: false, error: error, ocistiGresku: true);
      return null;
    }
  }
}
