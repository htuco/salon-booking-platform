import 'package:meta/meta.dart';

import 'local_date.dart';
import 'local_time.dart';

/// Jedna stavka na ekranu „Obavijesti" — onako kako je vrati `my_notifications` (task 70).
///
/// **Stavka je događaj, ne red loga.** `notification_logs` ima red po uređaju; baza ih
/// spaja po (termin, tip), pa ista potvrda poslana na telefon i tablet ovdje stiže jednom.
///
/// [type] ostaje string, a ne enum: baza dodaje tipove (`expired` iz taska 64, podsjetnici
/// iz taska 56) brže nego što stara verzija app-e stigne u store. Nepoznat tip ekran
/// prikazuje opštim naslovom, umjesto da cijela lista padne na parsiranju.
@immutable
class ClientNotification {
  const ClientNotification({
    required this.appointmentId,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.date,
    required this.startTime,
    this.serviceName,
    this.employeeName,
  });

  /// Mapira jedan red iz `my_notifications`.
  ///
  /// Baca [FormatException] kad red nije očekivanog oblika — `core_api` ga pretvara u
  /// `MappingError`, kao i kod ostalih modela.
  factory ClientNotification.fromJson(Map<String, dynamic> json) {
    final id = json['appointment_id'];
    final type = json['type'];
    final created = json['created_at'];
    final date = json['date'];
    final start = json['start_time'];
    if (id is! String || type is! String || created is! String) {
      throw FormatException('Obavijest bez termina, tipa ili vremena', '$json');
    }
    if (date is! String || start is! String) {
      throw FormatException('Obavijest bez datuma termina', '$json');
    }
    return ClientNotification(
      appointmentId: id,
      type: type,
      createdAt: DateTime.parse(created),
      read: json['read'] == true,
      date: LocalDate.parse(date),
      startTime: LocalTime.parse(start),
      serviceName: json['service_name'] as String?,
      employeeName: json['employee_name'] as String?,
    );
  }

  final String appointmentId;

  /// `confirmed`, `rejected`, `cancelled`, `expired`, `reminder_d1`, `reminder_h3`…
  final String type;

  /// Kad je obavijest nastala (UTC iz baze; ekran je prikazuje lokalno).
  final DateTime createdAt;

  /// `true` kad je klijent već otvorio listu u kojoj je stavka bila.
  final bool read;

  /// Termin na koji se obavijest odnosi — zidno vrijeme salona.
  final LocalDate date;
  final LocalTime startTime;

  /// Snimak naziva usluge i radnika na terminu; `null` za stare termine bez snimka.
  final String? serviceName;
  final String? employeeName;

  @override
  bool operator ==(Object other) =>
      other is ClientNotification &&
      other.appointmentId == appointmentId &&
      other.type == type &&
      other.createdAt == createdAt &&
      other.read == read;

  @override
  int get hashCode => Object.hash(appointmentId, type, createdAt, read);

  @override
  String toString() => 'ClientNotification($type, $appointmentId, read: $read)';
}
