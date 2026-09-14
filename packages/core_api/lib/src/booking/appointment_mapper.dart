/// Mapiranje `appointments` redova u modele.
///
/// Stoji u zasebnom fajlu jer ga koriste **dva** repozitorija: `AppointmentRepository`
/// (klijent čita svoje termine) i `StaffAppointmentRepository` (admin čita termine salona).
/// Red iz `appointments` je isti red bez obzira ko ga čita, pa bi drugi mapper značio dva
/// mjesta koja tumače istu tabelu — i dvije prilike da se raziđu kad tabela dobije kolonu.
///
/// Do taska 23 su ove funkcije stajale uz klijentski repozitorij, označene
/// `@visibleForTesting`. Ta oznaka je bila tačna dok je korisnik bio jedan; sada nije, pa su
/// izvučene ovdje umjesto da se oznaka zaobiđe ili da se mapiranje prepiše.
library;

import 'package:core_domain/core_domain.dart';

import '../errors/errors.dart';

/// Mapira listu redova `appointments` u modele.
List<Appointment> appointmentsFromRows(dynamic rows) {
  if (rows is! List) {
    throw MappingError(
      '`appointments` nije vratio listu nego ${rows.runtimeType}',
    );
  }
  return rows
      .whereType<Map<String, dynamic>>()
      .map(appointmentFromRow)
      .toList(growable: false);
}

/// Mapira jedan `appointments` red.
///
/// Nepoznat `status` ne ruši listu nego pada na `AppointmentStatus.unknown` — app u storeu
/// je uvijek starija od baze, a `alter type ... add value` niko ne prati po verzijama
/// storea (v. `appointment_status.dart`).
Appointment appointmentFromRow(Map<String, dynamic>? row) {
  if (row == null || row.isEmpty) {
    throw const MappingError('`appointments` red je prazan');
  }
  try {
    return Appointment.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan `appointments` red', cause: error);
  }
}

/// Mapira izlaz RPC funkcije koja vraća **jedan** `appointments` red.
///
/// Koriste ga `book_appointment` (klijent i ručni admin unos), `set_appointment_status` i
/// `cancel_appointment` — sve tri su `returns public.appointments`. Do taska 24 je stajao uz
/// `BookingRepository` i imao ime funkcije zakucano u poruci greške; sada ga zovu tri
/// pozivaoca, pa ime stiže kao [funkcija] umjesto da tri poruke lažu o tome koja je pukla.
///
/// Oblik se **provjerava, ne kastuje naslijepo**: PostgREST vraća mapu za `returns <tabela>`,
/// ali isti poziv počne vraćati listu čim potpis funkcije pređe u `setof`.
Appointment appointmentFromRpcRow(dynamic row, {required String funkcija}) {
  final json = switch (row) {
    Map<String, dynamic>() => row,
    List<dynamic>() when row.length == 1 => row.first as Map<String, dynamic>,
    List<dynamic>() when row.isEmpty => throw MappingError(
      '`$funkcija` nije vratio termin',
    ),
    _ => throw MappingError(
      '`$funkcija` je vratio neočekivan oblik: ${row.runtimeType}',
    ),
  };

  try {
    return Appointment.fromJson(json);
  } catch (error) {
    throw MappingError('Neispravan `appointments` red', cause: error);
  }
}
