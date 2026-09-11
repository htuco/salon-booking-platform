import 'package:freezed_annotation/freezed_annotation.dart';

import 'appointment_status.dart';
import 'local_date.dart';
import 'local_time.dart';

part 'appointment.freezed.dart';
part 'appointment.g.dart';

/// Termin — jedan red u `public.appointments`.
///
/// **Ovaj model se ne čita kao `anon`.** `appointments` nema politiku za anonimnu rolu;
/// čitaju ga prijavljeni klijent (`own_appointments`) i osoblje salona (`staff_manage`).
/// Zato u ovom tasku nema `AppointmentRepository` — model postoji za booking flow (task 11,
/// odgovor `book_appointment`) i admin ekrane koji dolaze u Sprintu 2.
///
/// **Upisi idu isključivo kroz `book_appointment` RPC.** Nema `insert` sa klijenta: RPC
/// re-validira slot u istoj transakciji i vraća `409` kad ga je neko pretekao
/// (v. `tasks/05-availability-engine.md` i `.claude/docs/security.md`).
///
/// Zamka na koju pazi [deviceId]: ovo je FK na `devices.id`, **nije** `devices.device_id`
/// (instalacioni identifikator koji šalje uređaj). Zamjena prolazi tipove — oba su uuid —
/// i tiho slomi push notifikacije.
@freezed
abstract class Appointment with _$Appointment {
  const factory Appointment({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,
    @JsonKey(name: 'service_id') required String serviceId,

    /// `null` kad salon ne traži izbor radnika (`require_staff_choice = false`).
    @JsonKey(name: 'employee_id') String? employeeId,
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'auth_identity_id') String? authIdentityId,

    /// FK na `devices.id` — **ne** `devices.device_id`.
    @JsonKey(name: 'device_id') String? deviceId,
    @JsonKey(name: 'customer_name') required String customerName,
    @JsonKey(name: 'customer_phone') String? customerPhone,
    @JsonKey(name: 'customer_note') String? customerNote,

    /// Datum i vremena su **lokalno zidno vrijeme salona**, bez zone —
    /// v. [LocalDate] i [LocalTime].
    @LocalDateConverter() required LocalDate date,
    @JsonKey(name: 'start_time')
    @LocalTimeConverter()
    required LocalTime startTime,
    @JsonKey(name: 'end_time') @LocalTimeConverter() required LocalTime endTime,

    /// Pauza nakon termina, kopirana iz `salon_settings` u trenutku rezervacije.
    /// Stoji na redu, a ne čita se iz postavki, da promjena postavke ne pomjeri
    /// termine koji su već rezervisani.
    @JsonKey(name: 'buffer_minutes') @Default(0) int bufferMinutes,
    @JsonKey(
      name: 'status',
      unknownEnumValue: AppointmentStatus.unknown,
      defaultValue: AppointmentStatus.unknown,
    )
    required AppointmentStatus status,

    /// `app` · `web` · `manual` · `guest` — odakle je termin stigao.
    @Default('app') String source,
    @JsonKey(name: 'cancel_reason') String? cancelReason,

    /// `customer` · `salon` · `system`. `system` je istekao `pending`.
    @JsonKey(name: 'cancelled_by') String? cancelledBy,
    @JsonKey(name: 'pending_expires_at') DateTime? pendingExpiresAt,
  }) = _Appointment;

  const Appointment._();

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      _$AppointmentFromJson(json);

  /// Termin još drži svoj slot zauzetim.
  bool get blocksSlot => status.blocksSlot;

  /// Trajanje same usluge, bez [bufferMinutes].
  int get durationMinutes =>
      endTime.minutesFromMidnight - startTime.minutesFromMidnight;
}
