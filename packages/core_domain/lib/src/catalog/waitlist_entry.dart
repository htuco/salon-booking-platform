import 'package:meta/meta.dart';

import 'local_date.dart';

/// Jedan upis klijenta na listu čekanja, onako kako ga vrati `my_waitlist` (task 68).
///
/// Upis je dan + usluga, a radnik je opcionalan: [employeeId] je `null` kad je klijent u
/// koraku 2 izabrao „Bilo ko". Upis ne drži termin — kad se mjesto oslobodi, klijent
/// dobija obavijest, a termin dobija ko prvi zakaže (ADR-0031).
@immutable
class WaitlistEntry {
  const WaitlistEntry({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.date,
    this.employeeId,
    this.employeeName,
  });

  /// Mapira jedan red iz `my_waitlist`.
  ///
  /// Baca [FormatException] kad red nije očekivanog oblika — `core_api` ga pretvara u
  /// `MappingError`, kao i kod ostalih modela.
  factory WaitlistEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final service = json['service_id'];
    final name = json['service_name'];
    final date = json['date'];
    if (id is! String ||
        service is! String ||
        name is! String ||
        date is! String) {
      throw FormatException('Upis bez usluge ili dana', '$json');
    }
    return WaitlistEntry(
      id: id,
      serviceId: service,
      serviceName: name,
      date: LocalDate.parse(date),
      employeeId: json['employee_id'] as String?,
      employeeName: json['employee_name'] as String?,
    );
  }

  final String id;
  final String serviceId;
  final String serviceName;

  /// Dan na koji klijent čeka — zidno vrijeme salona.
  final LocalDate date;

  /// `null` za „Bilo ko".
  final String? employeeId;
  final String? employeeName;

  @override
  bool operator ==(Object other) =>
      other is WaitlistEntry &&
      other.id == id &&
      other.serviceId == serviceId &&
      other.serviceName == serviceName &&
      other.date == date &&
      other.employeeId == employeeId &&
      other.employeeName == employeeName;

  @override
  int get hashCode =>
      Object.hash(id, serviceId, serviceName, date, employeeId, employeeName);

  @override
  String toString() => 'WaitlistEntry($serviceName, $date, $employeeName)';
}
