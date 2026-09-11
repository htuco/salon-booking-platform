import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jedino mjesto koje čita `--dart-define` vrijednosti.
///
/// Imena se poklapaju sa onima koje `tool/build_tenant.sh` prosljeđuje (`SALON_ID`,
/// `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_URL`) — ako se ovdje preimenuju, build tiho
/// proslijedi vrijednost koju niko ne čita, a app se ponaša kao da define nije ni dat.
///
/// Ključevi se **ne** commituju. Anon key jeste javan po dizajnu (RLS je taj koji štiti
/// podatke), ali URL i key se mijenjaju po okruženju — dev, staging, produkcija — pa u repo
/// ne ide nijedan od njih. Lokalno se pokreće sa `--dart-define-from-file`.
class AppEnv {
  const AppEnv({
    required this.salonId,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiUrl,
  });

  /// Čita okruženje iz `--dart-define` vrijednosti i **odmah** validira.
  ///
  /// Baca [MissingEnvError] samo za `SALON_ID` — jedini define bez kojeg build nema smisla,
  /// jer app ne zna koji salon prikazuje. Pogrešno konfigurisan build tako pada na startu,
  /// uz ime varijable koja fali; ranije se to vidjelo tek kao tekst na ekranu testera.
  ///
  /// Supabase vrijednosti **nisu** obavezne, i to je namjerno. Bez njih se klijent ne diže
  /// (`bootstrapClient` to provjerava kroz [hasSupabase]) i app radi na fallback podacima —
  /// što je upravo ono što `flutter run` bez backenda i `flutter build web` za preview
  /// trebaju. Dok su bile obavezne, web build sa ispravnim `SALON_ID`-om je padao prije
  /// `runApp` i davao **praznu bijelu stranicu** bez ijedne poruke.
  factory AppEnv.fromDefines() {
    if (_salonId.isEmpty) {
      throw MissingEnvError('SALON_ID');
    }

    return AppEnv(
      salonId: _salonId,
      supabaseUrl: _supabaseUrl,
      supabaseAnonKey: _supabaseAnonKey,
      apiUrl: _apiUrl,
    );
  }

  static const _salonId = String.fromEnvironment('SALON_ID');
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _apiUrl = String.fromEnvironment('API_URL');

  /// UUID salona — jedini `--dart-define` koji svaki build **mora** imati.
  final String salonId;

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Opciono; prazan string znači "koristi Supabase URL", ne "greška".
  final String apiUrl;

  /// `true` kad su Supabase vrijednosti stigle i ima smisla dizati klijenta.
  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// `--dart-define` koji nedostaje. Nosi ime varijable, jer je to jedino što popravlja build.
class MissingEnvError extends Error {
  MissingEnvError(this.variable);

  final String variable;

  @override
  String toString() =>
      'Nedostaje --dart-define=$variable. Build se pokreće kroz '
      'tool/build_tenant.sh, koji ga prosljeđuje; lokalno koristi '
      '--dart-define-from-file=env.json.';
}

/// Okruzenje aplikacije, postavljeno u `main`-u kroz override.
///
/// Baca ako ga niko nije override-ovao: `AppEnv` se cita **jednom**, u bootstrapu, i odatle
/// ulazi u stablo. Provider koji bi ga sam procitao iz `String.fromEnvironment` vratio bi
/// testu prazne vrijednosti umjesto jasne greske.
final appEnvProvider = Provider<AppEnv>(
  (ref) => throw StateError(
    'appEnvProvider nije override-ovan. Pokreni app kroz main() ili, u testu, '
    'proslijedi overrides: [appEnvProvider.overrideWithValue(...)].',
  ),
);
