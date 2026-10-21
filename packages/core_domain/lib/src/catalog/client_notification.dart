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
///
/// **Ponuda liste čekanja (task 68) nema termin.** Vezana je za upis, ne za tuđi termin koji
/// se oslobodio, pa [appointmentId] i [startTime] su `null`, a [date] je dan upisa.
@immutable
class ClientNotification {
  const ClientNotification({
    required this.type,
    required this.createdAt,
    required this.read,
    required this.date,
    this.appointmentId,
    this.startTime,
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
    if (type is! String || created is! String) {
      throw FormatException('Obavijest bez tipa ili vremena', '$json');
    }
    if (date is! String) {
      throw FormatException('Obavijest bez datuma', '$json');
    }
    // Termin nosi oba, ponuda liste čekanja nijedno. Pola termina je pokvaren red.
    final termin = id is String && start is String;
    final ponuda = id == null && start == null;
    if (!termin && !ponuda) {
      throw FormatException('Obavijest sa pola termina', '$json');
    }
    return ClientNotification(
      appointmentId: id as String?,
      type: type,
      createdAt: DateTime.parse(created),
      read: json['read'] == true,
      date: LocalDate.parse(date),
      startTime: start is String ? LocalTime.parse(start) : null,
      serviceName: json['service_name'] as String?,
      employeeName: json['employee_name'] as String?,
    );
  }

  /// `null` za ponudu liste čekanja.
  final String? appointmentId;

  /// `confirmed`, `rejected`, `cancelled`, `expired`, `reminder_d1`, `reminder_h3`…
  final String type;

  /// Kad je obavijest nastala (UTC iz baze; ekran je prikazuje lokalno).
  final DateTime createdAt;

  /// `true` kad je klijent već otvorio listu u kojoj je stavka bila.
  final bool read;

  /// Dan termina (ili upisa na listu čekanja) — zidno vrijeme salona.
  final LocalDate date;

  /// Početak termina; `null` za ponudu liste čekanja.
  final LocalTime? startTime;

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
