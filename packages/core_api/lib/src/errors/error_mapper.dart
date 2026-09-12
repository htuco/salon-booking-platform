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
  if (error is AuthException) {
    return ServerError('Greška autentikacije: ${error.message}', cause: error);
  }

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
