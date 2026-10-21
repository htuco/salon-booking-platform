import 'package:meta/meta.dart';

import 'local_date.dart';

/// Jedan upis klijenta na listu čekanja, onako kako ga vrati `my_waitlist` (task 68 i 91).
///
/// Upis je usluga + raspon dana, a radnik je opcionalan: [employeeId] je `null` kad je klijent
/// u koraku 2 izabrao „Bilo ko". Raspon računa baza — od dana na koji se klijent upisao do dana
/// prije prvog slobodnog termina — i ne pomjera se sam. Upis ne drži termin: kad se mjesto u
/// rasponu oslobodi, klijent dobija obavijest, a termin dobija ko prvi zakaže (ADR-0031).
@immutable
class WaitlistEntry {
  const WaitlistEntry({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.dateFrom,
    required this.dateTo,
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
    final from = json['date_from'];
    final to = json['date_to'];
    if (id is! String ||
        service is! String ||
        name is! String ||
        from is! String ||
        to is! String) {
      throw FormatException('Upis bez usluge ili raspona', '$json');
    }
    return WaitlistEntry(
      id: id,
      serviceId: service,
      serviceName: name,
      dateFrom: LocalDate.parse(from),
      dateTo: LocalDate.parse(to),
      employeeId: json['employee_id'] as String?,
      employeeName: json['employee_name'] as String?,
    );
  }

  final String id;
  final String serviceId;
  final String serviceName;

  /// Prvi dan na koji klijent čeka — zidno vrijeme salona. Baza ga vraća bez prošlih dana:
  /// upis koji je počeo juče danas počinje danas.
  final LocalDate dateFrom;

  /// Zadnji dan na koji klijent čeka: dan prije prvog slobodnog termina u trenutku upisa, ili
  /// kraj prozora rezervacije.
  final LocalDate dateTo;

  /// `null` za „Bilo ko".
  final String? employeeId;
  final String? employeeName;

  /// Je li [date] u rasponu upisa, oba kraja uključena.
  bool covers(LocalDate date) =>
      dateFrom.compareTo(date) <= 0 && date.compareTo(dateTo) <= 0;

  @override
  bool operator ==(Object other) =>
      other is WaitlistEntry &&
      other.id == id &&
      other.serviceId == serviceId &&
      other.serviceName == serviceName &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.employeeId == employeeId &&
      other.employeeName == employeeName;

  @override
  int get hashCode => Object.hash(
    id,
    serviceId,
    serviceName,
    dateFrom,
    dateTo,
    employeeId,
    employeeName,
  );

  @override
  String toString() =>
      'WaitlistEntry($serviceName, $dateFrom–$dateTo, $employeeName)';
}
