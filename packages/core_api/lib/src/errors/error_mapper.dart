import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_error.dart';

/// Pretvara sve što Supabase i `dart:io` mogu baciti u [ApiError].
///
/// Ovo je jedino mjesto u repou koje zna kako izgleda `PostgrestException` — sve iznad
/// radi sa [ApiError]. Repozitoriji ga koriste kroz [guard], ne direktno.
ApiError mapError(Object error, [StackTrace? stackTrace]) {
  // Vec mapirano — desi se kad guard obavije poziv koji je i sam prosao kroz guard.
  if (error is ApiError) return error;

  if (error is PostgrestException) return _mapPostgrest(error);

  // AuthException nasljeduje vlastitu hijerarhiju, ne PostgrestException.
  if (error is AuthException) return _mapAuth(error);

  // Edge Function (task 17, `delete-account`). Bez ovog reda bi greska iz funkcije pala u
  // fallback na dnu i izasla kao "Neocekivana greska: Instance of 'FunctionException'" —
  // tekst koji korisnik vidi, a koji ne kaze nista ni njemu ni onome ko cita prijavu.
  if (error is FunctionException) return _mapFunction(error);

  // Storage (task 49). Bucket sam odbija tip i veličinu, a politika tuđi salon — sve tri
  // stižu ovdje, ne kao PostgrestException.
  if (error is StorageException) return _mapStorage(error);

  if (error is SocketException || error is HttpException) {
    return NetworkError('Nema veze sa serverom', cause: error);
  }

  if (error is TimeoutException) {
    return NetworkError('Isteklo vrijeme čekanja odgovora', cause: error);
  }

  // `ClientException` iz package:http stize kao tip koji core_api ne uvozi direktno;
  // prepoznaje se po imenu da paket ne bi dobio zavisnost samo zbog jednog `is`.
  if (error.runtimeType.toString() == 'ClientException') {
    return NetworkError('Prekinuta veza sa serverom', cause: error);
  }

  if (error is FormatException || error is TypeError) {
    return MappingError(
      'Odgovor nije očekivanog oblika — provjeri da šema i model nisu razišli',
      cause: error,
    );
  }

  return ServerError('Neočekivana greška: $error', cause: error);
}

/// `AuthException` nosi i `code` (stabilno ime greške) i `statusCode` (HTTP, kao string).
///
/// **Gleda se `code` prvo.** `statusCode` je `400` i za pogrešan OTP kod i za neispravan
/// zahtjev, pa bi mapiranje po njemu obje stvari spojilo u istu poruku. `code` razlikuje
/// `otp_expired` od `over_email_send_rate_limit`, a to je razlika između "prekucajte kod"
/// i "sačekajte minut" — jedine dvije akcije koje korisnik na login ekranu uopšte ima.
///
/// Lista kodova: <https://supabase.com/docs/guides/auth/debugging/error-codes>.
ApiError _mapAuth(AuthException error) {
  // Mreza je pala prije nego sto je zahtjev stigao do Auth servera. Gotrue ga zamota u
  // vlastiti tip, pa bez ove grane "nema interneta" izlazi kao greska prijave.
  if (error is AuthRetryableFetchException) {
    return NetworkError('Nema veze sa serverom', cause: error);
  }

  return switch (error.code) {
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' ||
    'over_sms_send_rate_limit' => RateLimitError(
      'Previše zahtjeva — sačekajte prije novog pokušaja',
      cause: error,
    ),
    'otp_expired' ||
    'otp_disabled' ||
    'invalid_credentials' ||
    'email_not_confirmed' ||
    'user_not_found' ||
    'validation_failed' => AuthRejectedError(error.message, cause: error),
    // Kod ne stize uvijek (starije verzije Auth servera, greske prije odgovora).
    // Tada je HTTP status jedino sto postoji: 429 je rate limit, 400/401/403 su
    // odbijanje, ostalo je nas problem.
    _ => switch (error.statusCode) {
      '429' => RateLimitError(
        'Previše zahtjeva — sačekajte prije novog pokušaja',
        cause: error,
      ),
      '400' || '401' || '403' => AuthRejectedError(error.message, cause: error),
      _ => ServerError('Greška autentikacije: ${error.message}', cause: error),
    },
  };
}

/// PostgREST nosi i SQLSTATE i HTTP status u istom polju `code`, kao string.
///
/// Zato se gleda oboje: `23P01` je exclusion constraint (`appointments_no_overlap` iz taska
/// 05), `23505` je unique violation — oba su "neko te pretekao" iz ugla korisnika. `409`
/// stiže kad `book_appointment` sam digne konflikt.
///
/// **`PT409` je oblik u kojem konflikt stvarno stiže.** `book_appointment` ga diže
/// eksplicitno (`raise exception ... using errcode = 'PT409'`), na oba mjesta: kad
/// re-validacija slota ne nađe slobodnog radnika i kad utrku uhvati `exclusion_violation`.
/// Postgres klasu `PT` tretira kao "prenesi HTTP status iz zadnja tri znaka", pa PostgREST
/// odgovori statusom `409` — ali u tijelu odgovora, a time i u `PostgrestException.code`,
/// ostaje `PT409`. Bez ovog koda bi konflikt ispao `ServerError` i korisnik bi na zauzet
/// termin dobio "nešto nije u redu" umjesto osvježene liste slotova.
ApiError _mapPostgrest(PostgrestException error) {
  final code = error.code;

  if (code == 'PT409' || code == '23P01' || code == '23505' || code == '409') {
    return ConflictError('Termin je u međuvremenu zauzet', cause: error);
  }

  // PGRST116: "Results contain 0 rows" — `.single()` nad praznim rezultatom.
  // PT404: `book_appointment` kad usluga ne postoji ili nije aktivna.
  if (code == 'PGRST116' || code == 'PT404' || code == '404') {
    return NotFoundError('Traženi zapis ne postoji', cause: error);
  }

  // 42501 = insufficient_privilege, 401/403 = RLS je odbio.
  // Namjerno NotFound, ne poseban "zabranjeno": v. dokumentaciju NotFoundError.
  if (code == '42501' || code == '401' || code == '403') {
    return NotFoundError('Traženi zapis ne postoji', cause: error);
  }

  return ServerError(
    error.message.isEmpty
        ? 'Greška baze (${code ?? 'bez koda'})'
        : error.message,
    cause: error,
  );
}

/// `StorageException.statusCode` je HTTP status kao tekst. Tuđi salon (`403`) je
/// [NotFoundError] iz istog razloga kao `42501` kod PostgREST-a.
ApiError _mapStorage(StorageException error) {
  final poruka = error.message.toLowerCase();
  if (error.statusCode == '413' || poruka.contains('maximum allowed size')) {
    return ServerError('Slika je veća od 5 MB.', cause: error);
  }
  if (error.statusCode == '415' || poruka.contains('mime type')) {
    return ServerError('Podržane su JPG, PNG i WebP slike.', cause: error);
  }
  // Nema tuđeg zapisa čije postojanje bi poruka odala (putanju gradi aplikacija), pa ovdje
  // može reći šta se desilo — „Traženi zapis ne postoji" ispod slike ne kaže ništa.
  if (error.statusCode == '401') {
    return ServerError('Sesija je istekla. Prijavite se ponovo.', cause: error);
  }
  if (error.statusCode == '403' || poruka.contains('row-level security')) {
    return ServerError(
      'Nemate pravo da mijenjate slike ovog salona.',
      cause: error,
    );
  }
  return ServerError(
    'Slika se ne može poslati. Pokušajte ponovo.',
    cause: error,
  );
}

/// `FunctionException` nosi HTTP status i tijelo odgovora Edge Function-a.
///
/// Status se cita iz `status`, a poruka iz tijela — funkcije u ovom repou vracaju
/// `{"error": "..."}`, pa se ta poruka koristi kad postoji. `details` je `dynamic`: kad
/// funkcija padne prije nego sto stigne odgovoriti JSON-om, tu je goli tekst.
ApiError _mapFunction(FunctionException error) {
  final tijelo = error.details;
  final poruka = tijelo is Map && tijelo['error'] is String
      ? tijelo['error'] as String
      : null;

  // 401/403 iz funkcije znaci "nisi to smio" — isto znacenje kao `42501` iz baze, pa
  // dobija isti tip greske. Ekran ih time obradjuje na jednom mjestu.
  if (error.status == 401 || error.status == 403) {
    return AuthRejectedError(poruka ?? 'Zahtjev nije dozvoljen', cause: error);
  }

  return ServerError(
    poruka ?? 'Greška servera (${error.status})',
    cause: error,
  );
}

/// Obavija poziv ka bazi i garantuje da iz njega izađe samo [ApiError].
///
/// Repozitorij ga koristi umjesto golog `try/catch`, da mapiranje ne bi bilo prepisano
/// po pet puta i da nijedan poziv ne ostane nepokriven.
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error, stackTrace) {
    throw mapError(error, stackTrace);
  }
}

/// Poruka koju smije vidjeti korisnik — ili `null` kad je [ApiError.message] tekst za
/// razvoj (FE-501).
///
/// [ApiError.message] je po ugovoru poruka za log. Dio njih je ipak pisan za čovjeka i
/// ima smisla na ekranu: tekstovi koje `mapError` sam sastavi za mrežu, konflikt i
/// nepostojeći zapis, i validacije koje SQL funkcije dižu sa `errcode = 'PT…'`
/// (`'Kraj mora biti poslije pocetka'`). Ostatak, poput `'Neočekivana greška: $error'`,
/// `'Greška baze (…)'` i `MappingError` o šemi, je dijagnoza i korisniku ne govori ništa.
///
/// Odluka stoji ovdje, a ne u ekranu, jer samo ovaj fajl zna kako izgleda
/// `PostgrestException`. Ekran uz `null` stavlja svoju opštu rečenicu i „Pokušaj ponovo".
extension ApiErrorDisplay on ApiError {
  String? get displayMessage => switch (this) {
    NetworkError() || ConflictError() || NotFoundError() => message,
    ServerError(:final cause)
        when cause is PostgrestException &&
            (cause.code?.startsWith('PT') ?? false) =>
      message,
    // Storage poruke sastavlja `_mapStorage` na bosanskom (task 49).
    ServerError(:final cause) when cause is StorageException => message,
    // Auth poruke dolaze od Supabase Autha na engleskom; ekran prijave ih prevodi po
    // tipu. Rate limit i otkazivanje takođe obrađuje ekran, ne ovaj tekst.
    ServerError() ||
    MappingError() ||
    AuthRejectedError() ||
    AuthCancelledError() ||
    RateLimitError() => null,
  };
}
