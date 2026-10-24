import 'package:freezed_annotation/freezed_annotation.dart';

part 'salon_settings.freezed.dart';
part 'salon_settings.g.dart';

/// Booking pravila jednog salona — `salon_settings`, tačno jedan red po salonu.
///
/// **Ovo su iste postavke koje availability engine već primjenjuje u bazi**
/// (`get_available_slots`, `book_appointment` iz taska 05). App ih čita da bi znao **šta da
/// prikaže** — da li nuditi izbor radnika, da li prikazati cijene, koliko unaprijed pustiti
/// kalendar. Ne da bi sam računao slobodne termine: ta logika je isključivo u bazi i tu
/// ostaje (v. `tasks/sprint-0/05-availability-engine.md`).
@freezed
abstract class SalonSettings with _$SalonSettings {
  const factory SalonSettings({
    required String id,
    @JsonKey(name: 'salon_id') required String salonId,

    /// `manual` — salon potvrđuje svaki termin; `auto` — termin je odmah potvrđen.
    /// Određuje da li klijent nakon rezervacije vidi "čeka potvrdu" ili "potvrđeno".
    @JsonKey(name: 'booking_mode') @Default('manual') String bookingMode,

    /// `exact_slot` — klijent bira vrijeme; `date_only` — bira samo datum, a salon
    /// rasporedi. U `date_only` modu se zove `get_available_dates`, ne `get_available_slots`.
    @JsonKey(name: 'booking_granularity')
    @Default('exact_slot')
    String bookingGranularity,
    @JsonKey(name: 'buffer_minutes') @Default(5) int bufferMinutes,
    @JsonKey(name: 'slot_step_minutes') @Default(15) int slotStepMinutes,
    @JsonKey(name: 'min_advance_booking_hours')
    @Default(2)
    int minAdvanceBookingHours,
    @JsonKey(name: 'max_advance_booking_days')
    @Default(30)
    int maxAdvanceBookingDays,
    @JsonKey(name: 'pending_expiry_hours') @Default(12) int pendingExpiryHours,
    @JsonKey(name: 'min_cancel_hours') @Default(3) int minCancelHours,

    /// Kad je `true`, korak "izaberi radnika" se ne smije preskočiti u booking flowu.
    @JsonKey(name: 'require_staff_choice')
    @Default(false)
    bool requireStaffChoice,
    @JsonKey(name: 'show_prices_in_app') @Default(true) bool showPricesInApp,

    /// Dnevni podsjetnik (`reminder_d1`): push klijentu tačno 24 h prije početka termina
    /// (ADR-0033). Kolona se zove `reminders_enabled` iz vremena kad je bila jedina.
    @JsonKey(name: 'reminders_enabled') @Default(true) bool remindersEnabled,

    /// Satni podsjetnik (`reminder_h3`): push [hourlyReminderHours] sati prije početka.
    @JsonKey(name: 'hourly_reminder_enabled')
    @Default(true)
    bool hourlyReminderEnabled,

    /// N za satni podsjetnik, 1–12 ([minHourlyReminderHours]–[maxHourlyReminderHours]).
    /// Enum ostaje `reminder_h3` i kad N nije 3.
    @JsonKey(name: 'hourly_reminder_hours') @Default(3) int hourlyReminderHours,

    /// IANA zona (`Europe/Sarajevo`). Jedino mjesto gdje `LocalTime` postaje stvarni
    /// trenutak — i to tek na prikazu, ne u ovom sloju.
    @Default('Europe/Sarajevo') String timezone,
    @Default('bs') String language,
  }) = _SalonSettings;

  const SalonSettings._();

  factory SalonSettings.fromJson(Map<String, dynamic> json) =>
      _$SalonSettingsFromJson(json);

  /// Klijent bira samo datum, salon rasporedi vrijeme.
  bool get isDateOnly => bookingGranularity == 'date_only';

  /// Termin je odmah potvrđen, bez čekanja na salon.
  bool get confirmsAutomatically => bookingMode == 'auto';

  /// Klijent dobija bar jedan podsjetnik.
  bool get sendsReminders => remindersEnabled || hourlyReminderEnabled;

  /// Granice N iz `salon_settings_hourly_reminder_hours_check` (ADR-0033).
  static const minHourlyReminderHours = 1;
  static const maxHourlyReminderHours = 12;
}
