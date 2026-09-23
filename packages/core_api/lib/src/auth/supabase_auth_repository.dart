import 'dart:convert';
import 'dart:math';

import 'package:core_domain/core_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'auth_repository.dart';

/// [AuthRepository] nad Supabase Authom — jedino mjesto koje zna za `GoTrueClient`.
///
/// Task 12 je ostavio ugovor i konfiguraciju; ovo je prva implementacija
/// ([task 13](../../../../../tasks/sprint-2/13-client-login-ekran.md)).
///
/// Email koristi klasični `signUp`/`signInWithPassword`. Demo okruženje ne šalje email:
/// confirmation je isključen, pa registracija mora odmah vratiti sesiju. Ako hostovani
/// projekat još traži potvrdu, repozitorij to prijavi kao konfiguracijsku grešku umjesto
/// da ekran obeća poruku koju demo ne šalje.
///
/// ## Zašto se ne koristi `supabase.auth.currentUser` iznad ovog sloja
///
/// `User` nosi `appMetadata`, `identities` i još desetak polja vezanih za konkretan
/// backend. Granica je u `AuthSession` (`core_domain`) i drži se ovdje, jednom funkcijom
/// [_sesija] — v. `core_api.dart`, pravilo 2.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    this.google = bezGoogleKlijenata,
    this.beforeSignOut,
  });

  final Future<void> Function()? beforeSignOut;

  final SupabaseClient _client;

  /// Google client ID-evi ovog builda. V. [GoogleClientIds].
  ///
  /// Nije privatno samo zato što imenovani parametar u Dartu ne smije počinjati donjom
  /// crtom, pa `this._google` nije moguć. Čita se nigdje izvan ove klase.
  final GoogleClientIds google;

  /// `GoogleSignIn.instance` se inicijalizuje **jednom po procesu** (v7 API). Drugi
  /// `initialize` nije greška, ali je i nepotreban rad na svakom tapu.
  bool _googleSpreman = false;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthSession?> get sessionChanges =>
      _auth.onAuthStateChange.map((state) => _sesija(state.session));

  @override
  AuthSession? get currentSession => _sesija(_auth.currentSession);

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) => guard(() async {
    final odgovor = await _auth.signInWithPassword(
      email: email.trim(),
      // Lozinka se namjerno ne trimuje. Razmak može biti njen stvarni znak, a tiha
      // promjena bi korisniku napravila lozinku različitu od one koju je unio.
      password: password,
    );
    return _obaveznaSesija(odgovor.session, 'Email');
  });

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) => guard(() async {
    final odgovor = await _auth.signUp(email: email.trim(), password: password);

    final sesija = _sesija(odgovor.session);
    if (sesija == null) {
      // `signUp` bez sesije znači da je confirmation uključen. To je valjan produkcijski
      // odgovor, ali nije valjan za demo bez SMTP-a: korisnik bi ostao zaključan na
      // računu kojem potvrda nikad neće stići.
      throw const ServerError(
        'Supabase traži potvrdu emaila. Za demo isključi Confirm email prije registracije.',
      );
    }
    return sesija;
  });

  @override
  Future<void> signOut() => guard(() async {
    await beforeSignOut?.call();
    await _auth.signOut();
  });

  /// Nativni Sign in with Apple → `signInWithIdToken`.
  ///
  /// ## Nonce ide u dva oblika, i to nije formalnost
  ///
  /// Appleu se šalje **SHA-256 heš**, Supabaseu **sirova** vrijednost. Supabase hešira ono
  /// što dobije i poredi sa `nonce` claimom u tokenu; ako mu pošalješ heš, poredi heš heša
  /// i odbija prijavu. Ovo je najčešći način da Apple tok „radi do zadnjeg koraka".
  ///
  /// Bez nonce-a bi tok radio, ali bi bio ranjiv na replay: presretnut `identityToken` se
  /// može poslati drugi put. Nonce ga veže za **ovaj** pokušaj prijave.
  ///
  /// ## Ime dolazi samo prvi put
  ///
  /// Apple vraća `givenName`/`familyName` **isključivo pri prvoj autorizaciji** te app-e.
  /// Svaka sljedeća prijava vraća `null`, i to zauvijek — ni brisanje app-e ne pomaže,
  /// samo uklanjanje app-e iz Apple ID postavki. Zato se ime odmah upisuje u
  /// `user_metadata`: propušteno prvi put znači nalog bez imena trajno.
  @override
  Future<AuthSession> signInWithApple() => guard(() async {
    final sirovNonce = _noviNonce();
    final hesiranNonce = sha256.convert(utf8.encode(sirovNonce)).toString();

    final AuthorizationCredentialAppleID kredencijal;
    try {
      kredencijal = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hesiranNonce,
      );
    } on SignInWithAppleAuthorizationException catch (greska) {
      // Korisnik koji zatvori Apple dijalog **nije greška sistema** nego očekivan ishod, i
      // ekran ga ne smije prikazati kao crvenu poruku (`auth_repository.dart`).
      if (greska.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledError('Prijava je otkazana');
      }
      rethrow;
    }

    final token = kredencijal.identityToken;
    if (token == null) {
      throw const ServerError('Apple nije vratio identity token');
    }

    final odgovor = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token,
      nonce: sirovNonce,
    );

    await _upisiImeAkoGaNema(
      [
        kredencijal.givenName,
        kredencijal.familyName,
      ].where((d) => d != null && d.trim().isNotEmpty).join(' ').trim(),
    );

    return _obaveznaSesija(odgovor.session, 'Apple');
  });

  /// Nativni Google Sign-In → `signInWithIdToken`.
  ///
  /// ## Zašto se `serverClientId` traži, a `clientId` samo na iOS-u
  ///
  /// `serverClientId` je **web** client ID i ono što Supabase provjerava kao `aud`. Bez
  /// njega ID token nosi `aud` koji Supabase ne prepoznaje i prijava padne na zadnjem
  /// koraku, nakon što je korisnik već prošao kroz dijalog — najgore mjesto za pad.
  ///
  /// `clientId` je potreban samo na iOS-u; na Androidu plugin izvodi klijenta iz **potpisa
  /// APK-a**, zbog čega debug i release traže odvojene OAuth klijente sa svojim SHA-1
  /// otiscima (`docs/06 §7.1` to zove najčešćom greškom: radi u debugu, padne u produkciji).
  @override
  Future<AuthSession> signInWithGoogle() => guard(() async {
    // Prazan `serverClientId` znači da build nije konfigurisan. Baca se **prije** dijaloga:
    // pad poslije njega izgleda korisniku kao da je Google odbio njegov nalog.
    if (google.web.isEmpty) {
      throw const ServerError(
        'Google prijava nije konfigurisana za ovaj build — nedostaje GOOGLE_WEB_CLIENT_ID '
        '(v. tasks/sprint-2/12-konzole-checklist.md)',
      );
    }

    final klijent = GoogleSignIn.instance;
    if (!_googleSpreman) {
      await klijent.initialize(
        serverClientId: google.web,
        clientId: google.ios.isEmpty ? null : google.ios,
      );
      _googleSpreman = true;
    }

    // `authenticate()` ne postoji na svim platformama (v7 razdvaja autentikaciju i
    // autorizaciju). Web ide drugim tokom i nije ciljna platforma — provjera je ovdje da
    // web build ne padne sa `MissingPluginException`, nego sa porukom koja se može čitati.
    if (!klijent.supportsAuthenticate()) {
      throw const ServerError(
        'Google prijava na ovoj platformi traži drugi tok — v. docs/06 §7.1',
      );
    }

    final GoogleSignInAccount nalog;
    try {
      nalog = await klijent.authenticate();
    } on GoogleSignInException catch (greska) {
      if (greska.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledError('Prijava je otkazana');
      }
      rethrow;
    }

    final token = nalog.authentication.idToken;
    if (token == null) {
      throw const ServerError('Google nije vratio ID token');
    }

    final odgovor = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token,
    );

    return _obaveznaSesija(odgovor.session, 'Google');
  });

  /// Kriptografski nasumičan nonce. `Random.secure()`, ne obični `Random`: obični je
  /// predvidiv iz nekoliko uzoraka, a ovo je vrijednost koja brani od replaya.
  String _noviNonce() {
    final random = Random.secure();
    final bajtovi = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bajtovi).replaceAll('=', '');
  }

  /// Upisuje ime u `user_metadata` samo ako ga tamo još nema.
  ///
  /// „Samo ako nema" je bitno: Apple ime daje jednom, pa bi drugi poziv sa praznim imenom
  /// prebrisao ono što je prvi sačuvao. Trigger `sync_auth_identity` (task 02) odatle puni
  /// `auth_identities.display_name`, a `ensure_customer` (task 14) ga koristi kao ime
  /// klijenta.
  Future<void> _upisiImeAkoGaNema(String ime) async {
    if (ime.isEmpty) return;
    final postojece = _auth.currentUser?.userMetadata?['full_name'];
    if (postojece is String && postojece.trim().isNotEmpty) return;

    await _auth.updateUser(UserAttributes(data: {'full_name': ime}));
  }

  /// Sesija koja **mora** postojati nakon uspješnog `signInWithIdToken`.
  AuthSession _obaveznaSesija(Session? session, String provider) {
    final sesija = _sesija(session);
    if (sesija == null) {
      throw ServerError('$provider prijava nije vratila sesiju');
    }
    return sesija;
  }

  /// Brisanje naloga kroz Edge Function `delete-account` (task 17).
  ///
  /// **Ne zove se `auth.admin.deleteUser` odavde, i nikad neće.** To je admin API koji radi
  /// samo sa service role ključem, a taj ključ zaobilazi RLS u potpunosti i ne smije
  /// postojati u app-i (`.claude/docs/security.md`, „Tajne"). Funkcija na serveru radi oba
  /// koraka: RPC `delete_my_account` pod korisnikovim tokenom, pa `auth.admin.deleteUser`
  /// pod servisnim.
  ///
  /// **Odjava je dio brisanja, ne poseban korak koji ekran smije zaboraviti.** Bez nje
  /// `supabase_flutter` zadrži sesiju u lokalnom storageu, pa bi sljedeće otvaranje app-e
  /// izgledalo kao prijava — sa tokenom koji više nema identitet iza sebe. Korisnik bi
  /// vidio prijavljeno stanje u kojem ništa ne radi. DoD taska to zove „bez zaostalog
  /// tokena", i ovo je jedino mjesto gdje se to može garantovati za svakog pozivaoca.
  ///
  /// Odjava ide i kad brisanje padne? **Ne.** Neuspjelo brisanje mora ostaviti korisnika
  /// prijavljenim, da može pokušati ponovo — odjava bi mu oduzela jedini token kojim to
  /// može, i nalog bi ostao neobrisan zauvijek.
  @override
  Future<void> deleteAccount() => guard(() async {
    await _client.functions.invoke('delete-account');

    // **Odjava se namjerno ne pušta da obori uspješno brisanje.**
    //
    // `auth.users` red je u ovom trenutku već obrisan, pa GoTrue na `POST /auth/v1/logout`
    // vraća **403** — vidi se u konzoli i pri dokazivanju u browseru. Danas ga
    // `supabase_flutter` proguta i svejedno očisti lokalnu sesiju, pa sve radi. Ali to je
    // ponašanje biblioteke, ne ugovor: kad bi sljedeća verzija počela bacati, korisnik
    // čiji je nalog **stvarno obrisan** dobio bi poruku da brisanje nije uspjelo, i
    // pokušao bi ponovo sa tokenom iza kojeg više nema naloga.
    //
    // Zato se greška odjave guta ovdje, svjesno i na jednom mjestu. Lokalna sesija se ne
    // gubi time što je zahtjev pao — `signOut` je briše prije nego što mrežu i dotakne.
    try {
      await _auth.signOut();
    } on Object catch (_) {
      // Namjerno prazno: brisanje je prošlo, a odjava nema šta da spasi.
    }
  });

  /// Supabaseova `Session` → domenski [AuthSession]. Jedina tačka prevoda.
  AuthSession? _sesija(Session? session) {
    final user = session?.user;
    // Supabase anonymous auth izdaje pravi JWT sa rolom `authenticated`. Takva sesija
    // više nije prijava u proizvodu: ne puštamo je u router ni u `ensure_customer`, a baza
    // nezavisno ponavlja istu zabranu u `book_appointment` (task 41).
    if (user == null || user.isAnonymous) return null;

    return AuthSession(
      userId: user.id,
      providers: _provideri(user),
      email: user.email,
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
