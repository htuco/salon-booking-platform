import 'auth_platform.dart';
import 'auth_provider.dart';

/// Koji se provideri nude na login ekranu — **podatak, ne `if` u widgetu**.
///
/// Isto pravilo kao za vertikale (`docs/05 §2`): ekran renderuje
/// [forPlatform] i ne zna koji provideri uopšte postoje. Isključivanje providera za jednog
/// tenanta je time promjena konfiguracije, ne novi store submission.
///
/// ## Odakle vrijednosti dolaze
///
/// Isti fallback lanac kao boje u `appThemeProvider`-u, iz istog razloga — nešto mora biti
/// poznato prije prvog odgovora backenda:
///
/// 1. `auth:` blok iz `tenant.yaml`, kroz generisani registar (`tenants.g.dart`);
/// 2. [fallback] — samo za build bez tenanta u registru.
///
/// Lista providera danas ima samo korake 2–3: backend nema kolonu koja bi je nosila.
/// Kad je dobije, dodaje se kao korak 1 i ništa iznad ovog tipa se ne mijenja.
class AuthConfig {
  const AuthConfig({required this.enabled});

  /// Ono što svaki tenant dobija dok ne kaže drugačije: Apple, Google i email + lozinka, bez
  /// gosta. To su ujedno i svi provideri koji postoje — v. [AuthProvider].
  static const AuthConfig fallback = AuthConfig(
    enabled: {AuthProvider.apple, AuthProvider.google, AuthProvider.email},
  );

  /// Provideri koje je tenant uključio, **bez obzira na platformu**. Filtriranje po
  /// platformi je [forPlatform] — ova lista je konfiguracija, ne ono što se crta.
  final Set<AuthProvider> enabled;

  /// Provideri koje treba prikazati na [platform], u redoslijedu deklaracije
  /// [AuthProvider] — Apple prvi na iOS-u, kako App Review traži (`docs/06 §7.2`).
  ///
  /// Presjek je namjeran u oba smjera: tenant ne može uključiti provider koji na toj
  /// platformi nema implementaciju (Apple na Androidu), niti platforma sama uvodi provider
  /// koji tenant nije uključio.
  List<AuthProvider> forPlatform(AuthPlatform platform) => AuthProvider.values
      .where((p) => enabled.contains(p) && p.isAvailableOn(platform))
      .toList(growable: false);

  /// Gradi config iz imena kakva stoje u `tenant.yaml` i u bazi.
  ///
  /// Nepoznata imena se **ispuštaju bez greške**. Registar je validiran pri generisanju
  /// (`tool/gen_flavors.dart` pada na nepoznat ključ u `auth.providers`), pa odatle ne može
  /// stići smeće; ovaj put ostaje otvoren za vrijednosti sa backenda, gdje je app u storeu
  /// uvijek starija od podataka — isti razlog zbog kojeg `AppointmentStatus` ima `unknown`.
  factory AuthConfig.fromNames(Iterable<String> names) => AuthConfig(
    enabled: names.map(AuthProvider.fromWire).nonNulls.toSet(),
  );

  AuthConfig copyWith({Set<AuthProvider>? enabled}) =>
      AuthConfig(enabled: enabled ?? this.enabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthConfig &&
          _isteVrijednosti(other.enabled, enabled);

  @override
  int get hashCode =>
      // Set nema stabilan hash po sadržaju; enum indeksi sortirani daju ga.
      Object.hashAll(enabled.map((p) => p.index).toList()..sort());

  static bool _isteVrijednosti(Set<AuthProvider> a, Set<AuthProvider> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  String toString() =>
      'AuthConfig(enabled: ${enabled.map((p) => p.wireName).toList()..sort()})';
}
