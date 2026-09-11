import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Okruzenje admin aplikacije.
///
/// **Nema `SALON_ID`.** Admin app je jedna, genericka za sve salone: vlasnik se prijavi i
/// vidi svoj salon na osnovu clanstva u `public.users`, ne na osnovu builda. Zato ovdje
/// nema ni `x-salon-id` headera — kad bi ga bilo, admin bi sam sebi birao kontekst, a
/// njegova prava idu kroz `private.is_admin()` (v. ADR-0003 i `.claude/docs/security.md`).
class AdminEnv {
  const AdminEnv({required this.supabaseUrl, required this.supabaseAnonKey});

  /// Admin nema obavezan define: bez Supabase vrijednosti klijent se ne dize i app pokaze
  /// prazne ekrane, umjesto da padne prije `runApp` i da bijelu stranicu.
  factory AdminEnv.fromDefines() {
    return const AdminEnv(
      supabaseUrl: _supabaseUrl,
      supabaseAnonKey: _supabaseAnonKey,
    );
  }

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Postavlja se u `main`-u kroz override — v. obrazlozenje uz klijentski `appEnvProvider`.
final adminEnvProvider = Provider<AdminEnv>(
  (ref) => throw StateError(
    'adminEnvProvider nije override-ovan. Pokreni app kroz main() ili, u testu, '
    'proslijedi overrides: [adminEnvProvider.overrideWithValue(...)].',
  ),
);
