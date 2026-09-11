import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_env.dart';

/// Async inicijalizacija koja mora proći prije `runApp`.
///
/// Postoji kao zasebna funkcija, a ne kao `await` u `main`-u, da bi je test mogao pozvati sa
/// svojim [env]-om. Vraća [AppEnv] umjesto da ga upisuje u globalnu varijablu — globalni
/// singleton je ono što kasnije natjera svaki test da diže cijeli bootstrap.
Future<AppEnv> bootstrapClient({AppEnv? env}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final resolved = env ?? AppEnv.fromDefines();

  if (resolved.hasSupabase) {
    await Supabase.initialize(
      url: resolved.supabaseUrl,
      // `publishableKey`, ne `anonKey`: isti ključ, ali je `anonKey` deprecated i nestaje u
      // sljedećem major-u. Ime `--dart-define`-a ostaje `SUPABASE_ANON_KEY` jer ga
      // `tool/build_tenant.sh` i CI tako prosljeđuju.
      publishableKey: resolved.supabaseAnonKey,
      // `x-salon-id` ide na **svaki** zahtjev klijentske app-e. Nije sigurnosna mjera:
      // header bira kontekst, a RLS odlučuje o pristupu (ADR-0003). Zato stoji ovdje,
      // na klijentu, umjesto da ga svaki repozitorij pamti i poneki zaboravi —
      // zaboravljen header ne daje grešku, nego **prazan rezultat**, što izgleda kao
      // "nema mojih termina" i traži se satima.
      headers: {'x-salon-id': resolved.salonId},
    );
  }

  return resolved;
}
