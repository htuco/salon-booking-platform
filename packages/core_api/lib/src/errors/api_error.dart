/// Greška repozitorija — jedini tip greške koji sloj iznad `core_api` treba poznavati.
///
/// **Ekran nikad ne hvata `PostgrestException`.** Taj tip je detalj PostgREST-a: nosi
/// `code` kao string koji je čas SQLSTATE (`23P01`), čas HTTP status (`409`), i mijenja se
/// sa verzijom biblioteke. Kad bi ekran hvatao njega, svaki `catch` u aplikaciji bi zavisio
/// od oblika tuđeg odgovora — a booking flow (task 11) mora razlikovati "slot je upravo
/// zauzet" od "nema mreže" da bi uopšte znao šta ponuditi korisniku.
///
/// Zato `catch` u ekranu izgleda ovako:
///
/// ```dart
/// try {
///   await repository.byId(salonId);
/// } on ApiError catch (error) {
///   switch (error) {
///     case NetworkError():  // ponudi "pokušaj ponovo"
///     case ConflictError(): // slot je otišao, vrati na izbor termina
///     case NotFoundError(): // prazno stanje, ne greška
///     case ServerError():   // generička poruka
///   }
/// }
/// ```
///
/// `sealed` je namjerno: novi tip greške obori build na svakom `switch`-u koji ga ne
/// obrađuje, umjesto da se provuče u `default` i pojavi se kao pogrešna poruka u produkciji.
sealed class ApiError implements Exception {
  const ApiError(this.message, {this.cause});

  /// Poruka za log i za razvoj. **Nije tekst za korisnika** — taj ide kroz `.arb`, jer se
  /// prevodi i jer se razlikuje po ekranu.
  final String message;

  /// Izvorna greška, zadržana za log. Ekran je ne dodiruje.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Zahtjev nije stigao do baze — nema mreže, DNS, timeout, TLS.
///
/// Jedina greška kod koje "pokušaj ponovo" ima smisla bez ikakve druge akcije korisnika.
final class NetworkError extends ApiError {
  const NetworkError(super.message, {super.cause});
}

/// Red ne postoji, ili ga RLS ne propušta ovom pozivaocu.
///
/// **Ta dva slučaja se namjerno ne razlikuju.** RLS ne vraća "zabranjeno" nego prazan
/// rezultat — i tako i treba: razlika između "salon ne postoji" i "salon postoji ali ga ne
/// smiješ vidjeti" je curenje podatka o tuđem tenantu. Ako ti treba razlika, ne treba ti.
final class NotFoundError extends ApiError {
  const NotFoundError(super.message, {super.cause});
}

/// Neko je pretekao — slot je zauzet između prikaza i potvrde.
///
/// Ovo je `409` iz `book_appointment` (task 05), koji slot re-validira u istoj transakciji,
/// i exclusion constraint `appointments_no_overlap` koji ga podupire na nivou baze.
/// Treba ga booking flow (task 11): ekran se vraća na izbor termina sa osvježenom listom,
/// a ne prikazuje generičku grešku.
final class ConflictError extends ApiError {
  const ConflictError(super.message, {super.cause});
}

/// Sve ostalo sa strane baze — neispravan upit, pala politika, 5xx.
///
/// Za korisnika je to "nešto nije u redu, pokušajte kasnije"; za nas je stavka u logu sa
/// [cause] koji nosi originalni `code`.
final class ServerError extends ApiError {
  const ServerError(super.message, {super.cause});
}

/// Odgovor je stigao, ali nije onog oblika koji model očekuje.
///
/// Skoro uvijek znači da su se šema i model raziđu — kolona preimenovana u migraciji, a
/// `@JsonKey` ostao stari. Izdvojeno iz [ServerError] jer se rješava drugačije: ovo je bug
/// u našem kodu, ne kvar u tuđem sistemu.
final class MappingError extends ApiError {
  const MappingError(super.message, {super.cause});
}
