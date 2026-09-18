import 'auth_platform.dart';

/// Način prijave koji app nudi korisniku.
///
/// [wireName] je isto ime koje nosi Supabase (`auth.identities.provider`) i ključ pod kojim
/// provider stoji u `auth.providers` bloku u `tenant.yaml` — jedno ime kroz cijeli lanac,
/// da se konfiguracija i baza ne moraju prevoditi jedna u drugu.
///
/// **Redoslijed deklaracije je redoslijed prikaza.** [AuthConfig.forPlatform] vraća listu u
/// ovom redu, pa login ekran ne sortira ništa sam. Apple je prvi namjerno: App Review po
/// pravilu 4.8 traži da Sign in with Apple ne bude manje istaknut od ostalih
/// (`docs/06 §7.2`).
enum AuthProvider {
  /// Nativni Sign in with Apple preko `sign_in_with_apple` → `signInWithIdToken`.
  ///
  /// **Obavezan na iOS-u** čim postoji ijedan drugi social provider — bez njega App Review
  /// odbija build (`docs/06 §7.2`). Na Androidu nema šta da radi: tamo ne postoji nativni
  /// tok, a web varijanta bi korisnika izbacila u browser.
  apple('apple', {AuthPlatform.ios}),

  /// Nativni Google Sign-In → `signInWithIdToken`. Client ID je **po flavoru**, ne po
  /// projektu (`docs/06 §7.1`) — jedan zajednički ID znači da korisnik u Google dijalogu
  /// vidi tuđe ime salona.
  google('google', {AuthPlatform.ios, AuthPlatform.android}),

  /// Email + lozinka (`docs/06 §2.1`, [ADR-0010]). Jedini provider koji ne košta ništa po
  /// flavoru i radi na svim platformama.
  ///
  /// Facebook je nekad stajao ovdje i **namjerno ga više nema** — v.
  /// [ADR-0011](../../../../../docs/adr/0011-facebook-login-se-ne-implementira.md).
  email('email', {AuthPlatform.ios, AuthPlatform.android, AuthPlatform.web});

  const AuthProvider(this.wireName, this.platforms);

  /// Ime kako stoji u Supabaseu i u `tenant.yaml`.
  final String wireName;

  /// Platforme na kojima ovaj provider uopšte ima implementaciju.
  final Set<AuthPlatform> platforms;

  /// Mapira ime iz `tenant.yaml` ili sa backenda; `null` za sve što ova verzija ne poznaje.
  ///
  /// Namjerno vraća `null` umjesto `unknown` člana kakav ima `AppointmentStatus`: status se
  /// može prikazati neutralno, a provider se ne može — za nepoznat provider nema ni ikone
  /// ni toka prijave, pa jedino što se s njim može je ispustiti ga iz liste.
  static AuthProvider? fromWire(String? value) => switch (value) {
    'apple' => apple,
    'google' => google,
    'email' => email,
    _ => null,
  };

  /// Da li provider ima implementaciju na [platform].
  bool isAvailableOn(AuthPlatform platform) => platforms.contains(platform);
}
