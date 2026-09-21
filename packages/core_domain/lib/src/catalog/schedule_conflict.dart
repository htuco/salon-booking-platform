import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date.dart';
import 'local_time.dart';

part 'schedule_conflict.freezed.dart';
part 'schedule_conflict.g.dart';

/// Postojeći termin koji bi ispao van rasporeda koji se **tek sprema da bude snimljen**.
///
/// Vraćaju ga `working_hours_conflicts` i `blocked_slot_conflicts` — obje `stable`
/// funkcije koje ništa ne mijenjaju. To je cijela poenta tipa: salon koji skrati radno
/// vrijeme ne smije tiho ostati sa terminima izvan njega, ali ih aplikacija **ne briše i
/// ne pomjera** umjesto njega. Odluka je vlasnikova; ovo je samo lista koju vidi prije
/// nego što potvrdi.
///
/// Zato ovdje nema ni `status` ni `serviceId`: ovo nije termin nego upozorenje o terminu.
/// Kad adminu zatreba više od imena i vremena, ima `appointment_id` i ekran termina.
@freezed
abstract class ScheduleConflict with _$ScheduleConflict {
  const factory ScheduleConflict({
    @JsonKey(name: 'appointment_id') required String appointmentId,
    @LocalDateConverter() required LocalDate date,
    @JsonKey(name: 'start_time')
    @LocalTimeConverter()
    required LocalTime startTime,
    @JsonKey(name: 'end_time') @LocalTimeConverter() required LocalTime endTime,
    @JsonKey(name: 'customer_name') required String customerName,

    /// Snapshot imena radnika sa termina — `null` za termin bez dodijeljenog radnika.
    @JsonKey(name: 'employee_name') String? employeeName,

    /// Zašto termin ispada: `Dan je zatvoren`, `Van radnog vremena` ili `Unutar pauze`.
    ///
    /// **Dolazi iz baze i `blocked_slot_conflicts` ga ne vraća** — kod blokade je razlog
    /// očigledan iz konteksta (termin je ispod blokade koja se upravo dodaje), pa kolona
    /// ne postoji i polje ostaje `null`.
    String? reason,
  }) = _ScheduleConflict;

  factory ScheduleConflict.fromJson(Map<String, dynamic> json) =>
      _$ScheduleConflictFromJson(json);
}
