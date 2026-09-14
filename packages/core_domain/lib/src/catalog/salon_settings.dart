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
    @JsonKey(name: 'allow_guest_booking')
    @Default(false)
    bool allowGuestBooking,

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
}
