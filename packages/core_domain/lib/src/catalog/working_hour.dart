import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_time.dart';

part 'working_hour.freezed.dart';
part 'working_hour.g.dart';

/// Radno vrijeme za jedan dan u sedmici — salonsko ili radnikovo.
///
/// **[employeeId] je `null` za raspored cijelog salona.** Red sa radnikom nadjačava
/// salonski za tog radnika; unique constraint je `nulls not distinct(salon_id, employee_id,
/// day_of_week)`, pa po danu postoji najviše jedan salonski i najviše jedan po radniku.
///
/// **[dayOfWeek] je ISO: 1 = ponedjeljak … 7 = nedjelja.** Ne poklapa se sa Dartovim
/// `DateTime.weekday`? Poklapa — i to je jedini razlog zašto ovdje nema konverzije. Ne
/// dodaj je "za svaki slučaj"; oba su ISO 8601.
///
/// Sva vremena su [LocalTime] — lokalno zidno vrijeme salona, bez zone. Zašto to nije
/// `DateTime`: v. dokumentaciju [LocalTime].
@freezed
abstract class WorkingHour with _$WorkingHour {
  const factory WorkingHour({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,

    /// `null` = raspored salona, inače raspored tog radnika.
    @JsonKey(name: 'employee_id') String? employeeId,

    /// ISO 1–7 (ponedjeljak–nedjelja), isto kao `DateTime.weekday`.
    @JsonKey(name: 'day_of_week') required int dayOfWeek,
    @JsonKey(name: 'start_time')
    @LocalTimeConverter()
    required LocalTime startTime,
    @JsonKey(name: 'end_time') @LocalTimeConverter() required LocalTime endTime,

    /// Pauza unutar smjene. Baza garantuje da su oba polja `null` ili oba postavljena,
    /// pa ih [hasBreak] čita zajedno.
    @JsonKey(name: 'break_start_time')
    @NullableLocalTimeConverter()
    LocalTime? breakStartTime,
    @JsonKey(name: 'break_end_time')
    @NullableLocalTimeConverter()
    LocalTime? breakEndTime,

    /// Neradni dan. Kad je `true`, [startTime]/[endTime] i dalje nose default iz baze
    /// (`09:00`–`17:00`) — ne čitaj ih bez provjere ovog flaga.
    @JsonKey(name: 'is_closed') @Default(false) bool isClosed,
  }) = _WorkingHour;

  const WorkingHour._();

  factory WorkingHour.fromJson(Map<String, dynamic> json) =>
      _$WorkingHourFromJson(json);

  /// Raspored cijelog salona, a ne pojedinog radnika.
  bool get isSalonWide => employeeId == null;

  bool get hasBreak => breakStartTime != null && breakEndTime != null;
}
