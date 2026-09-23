import 'package:core_api/core_api.dart';

/// Opšta rečenica kad greška nema poruku za korisnika.
const opstaPorukaGreske = 'Nešto nije u redu. Pokušajte ponovo.';

/// Tekst greške za admin ekran (FE-501).
///
/// `ApiError.message` je poruka za log i ponekad nosi SQL kod ili ime tabele. Ovdje ide
/// samo ono što `displayMessage` propusti: validacije iz SQL-a (`PT400`), mreža,
/// konflikt. Za sve ostalo ekran kaže [opsta], jer vlasnik salona sa „Greška baze
/// (42P01)" ne može ništa.
String porukaGreske(Object greska, {String opsta = opstaPorukaGreske}) =>
    greska is ApiError ? (greska.displayMessage ?? opsta) : opsta;
