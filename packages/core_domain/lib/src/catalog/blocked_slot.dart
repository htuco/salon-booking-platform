import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date.dart';
import 'local_time.dart';

part 'blocked_slot.freezed.dart';
part 'blocked_slot.g.dart';

/// Vrijeme koje salon sam zauzme — `public.blocked_slots`.
///
/// Nije termin i nema klijenta: godišnji odmor, servis opreme, sastanak, „danas ranije
/// zatvaramo". Availability engine ga oduzima od slobodnog vremena isto kao termin
/// (`get_available_slots`), pa je za klijenta razlika nevidljiva — a za vlasnika je to
/// jedina razlika koja ga zanima kad gleda raspored.
///
/// **[employeeId] je `null` kad je blokiran cijeli salon**, isto pravilo kao u
/// [WorkingHour]. Blokada jednog radnika ne dira ostale.
///
/// **[reason] je slobodan tekst i smije biti prazan.** Kolona je nullable, pa ekran mora
/// imati šta pisati kad razloga nema — v. `blokadaNaslov` u admin kalendaru.
///
/// Vremena su [LocalTime] iz istog razloga kao svugdje u ovom sloju: `time` kolona nema
/// zonu, a salon koji „ne radi do 12" misli dvanaest po satu na svom zidu.
@freezed
abstract class BlockedSlot with _$BlockedSlot {
  const factory BlockedSlot({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,

    /// `null` = blokiran cijeli salon, inače samo taj radnik.
    @JsonKey(name: 'employee_id') String? employeeId,
    @LocalDateConverter() required LocalDate date,
    @JsonKey(name: 'start_time')
    @LocalTimeConverter()
    required LocalTime startTime,
    @JsonKey(name: 'end_time') @LocalTimeConverter() required LocalTime endTime,
    String? reason,
  }) = _BlockedSlot;

  const BlockedSlot._();

  factory BlockedSlot.fromJson(Map<String, dynamic> json) =>
      _$BlockedSlotFromJson(json);

  /// Blokada cijelog salona, a ne pojedinog radnika.
  bool get isSalonWide => employeeId == null;

  /// Trajanje u minutama. Baza garantuje `end_time > start_time`.
  int get durationMinutes =>
      endTime.minutesFromMidnight - startTime.minutesFromMidnight;
}
