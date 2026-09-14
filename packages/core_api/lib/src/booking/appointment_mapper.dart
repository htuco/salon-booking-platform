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
