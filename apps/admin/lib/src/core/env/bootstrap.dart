import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_env.dart';

/// Async inicijalizacija admin app-e prije `runApp`.
Future<AdminEnv> bootstrapAdmin({AdminEnv? env}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // V. klijentski bootstrap: bez ovoga web deep link tiho ne radi.
  usePathUrlStrategy();

  final resolved = env ?? AdminEnv.fromDefines();

  if (resolved.hasSupabase) {
    await Supabase.initialize(
      url: resolved.supabaseUrl,
      // `publishableKey`, ne deprecated `anonKey`; ime define-a ostaje SUPABASE_ANON_KEY.
      publishableKey: resolved.supabaseAnonKey,
      // Namjerno **bez** `x-salon-id`. Admin nije vezan za jedan salon, a header koji bira
      // kontekst kod admina bi znacio da pozivalac bira svoj opseg. Prava idu kroz
      // `private.is_admin()` i clanstvo u `public.users` (ADR-0003).
    );
  }

  return resolved;
}
