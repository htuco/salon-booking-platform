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
    await _odbaciMrtvuSesiju(Supabase.instance.client.auth);
  }

  return resolved;
}

/// Sesija iz browsera koja se više ne može obnoviti briše se odmah, lokalno.
///
/// **Ovo je našao login koji se vrtio.** Poslije restarta aplikacije `supabase_flutter`
/// vrati sačuvanu sesiju, pokuša obnoviti istekao token i dobije `refresh_token_not_found`
/// — ali je ne obriše. Router tada ispravno pokaže prijavu (članstvo se ne može pročitati),
/// a `signInWithPassword` visi iza obnove koja nikad ne uspije: dugme „Prijavi se" se vrti
/// bez kraja. Ista prijava u čistom browseru prolazi odmah.
///
/// `SignOutScope.local` ne zove server: token koji server ne poznaje nema šta odjaviti, a
/// globalna odjava bi odjavila i ostale uređaje tog korisnika.
Future<void> _odbaciMrtvuSesiju(GoTrueClient auth) async {
  final sesija = auth.currentSession;
  if (sesija == null || !sesija.isExpired) return;
  try {
    await auth.refreshSession();
  } on AuthApiException {
    // Samo kad **server** odbije token. Bez mreže obnova padne kao „retryable" greška, a
    // sesija je tada možda i dalje dobra — briše se tek kad server kaže da je nema.
    await auth.signOut(scope: SignOutScope.local);
  }
}
