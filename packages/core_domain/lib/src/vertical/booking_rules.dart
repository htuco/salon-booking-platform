/// Kako klijent bira termin — tačno vrijeme, ili samo datum pa salon dodijeli vrijeme.
///
/// `date_only` nije rubni slučaj nego cijeli poslovni model kod ordinacija
/// ("dođite ujutro, primit ćemo vas") — v. `docs/05-vertical-packs.md` §4.1.
enum BookingGranularity {
  exactSlot('exact_slot'),
  dateOnly('date_only');

  const BookingGranularity(this.wireValue);

  /// Vrijednost kakva stoji u bazi (`snake_case`), ne Dart ime.
  final String wireValue;

  static BookingGranularity fromWire(Object? value) =>
      BookingGranularity.values.firstWhere(
        (granularity) => granularity.wireValue == value,
        orElse: () => BookingGranularity.exactSlot,
      );
}

/// Da li termin potvrđuje salon ručno ili se potvrđuje sam.
enum BookingMode {
  manual('manual'),
  auto('auto');

  const BookingMode(this.wireValue);

  final String wireValue;

  static BookingMode fromWire(Object? value) => BookingMode.values.firstWhere(
    (mode) => mode.wireValue == value,
    orElse: () => BookingMode.manual,
  );
}

/// Booking pravila vertikale — default koji salon može prebiti kroz `salon_settings`.
///
/// **Ovo nije availability engine.** Slobodni termini se računaju isključivo u bazi
/// (`get_available_slots`, task 05) i nijedno od ovih polja se ne koristi da bi se u Dartu
/// izračunao ili filtrirao slot. Ovdje stoje da bi ekran znao šta da *prikaže* — npr. da li
/// nuditi izbor radnika, i koji tekst staviti uz rok za otkazivanje.
///
/// Oblik prati `vertical_packs.default_settings` JSONB; tabela po vertikali: `docs/05 §4`.
class BookingRules {
  const BookingRules({
    required this.mode,
    required this.granularity,
    required this.slotStepMinutes,
    required this.bufferMinutes,
    required this.minAdvanceBookingHours,
    required this.maxAdvanceBookingDays,
    required this.minCancelHours,
    required this.pendingExpiryHours,
    required this.requireStaffChoice,
    required this.showPricesInApp,
    required this.allowGuestBooking,
  });

  /// `generic` red iz `docs/05 §4` — v. obrazloženje uz [VerticalTerms.fallback].
  static const BookingRules fallback = BookingRules(
    mode: BookingMode.manual,
    granularity: BookingGranularity.exactSlot,
    slotStepMinutes: 30,
    bufferMinutes: 10,
    minAdvanceBookingHours: 4,
    maxAdvanceBookingDays: 60,
    minCancelHours: 6,
    pendingExpiryHours: 24,
    requireStaffChoice: false,
    showPricesInApp: true,
    allowGuestBooking: false,
  );

  final BookingMode mode;
  final BookingGranularity granularity;

  /// Granularnost prikaza slotova (npr. 15 min), neovisna o trajanju usluge.
  final int slotStepMinutes;

  /// Pauza prije i poslije termina. Kod ordinacija je sterilizacija, ne ljubaznost.
  final int bufferMinutes;
  final int minAdvanceBookingHours;
  final int maxAdvanceBookingDays;
  final int minCancelHours;
  final int pendingExpiryHours;

  /// `true` znači da "bilo koji dostupan" nije ponuđen — pacijent ide svom doktoru.
  final bool requireStaffChoice;
  final bool showPricesInApp;
  final bool allowGuestBooking;

  factory BookingRules.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallbackValue) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallbackValue;
    }

    bool readBool(String key, bool fallbackValue) {
      final value = json[key];
      return value is bool ? value : fallbackValue;
    }

    return BookingRules(
      mode: BookingMode.fromWire(json['bookingMode']),
      granularity: BookingGranularity.fromWire(json['bookingGranularity']),
      slotStepMinutes: readInt('slotStepMinutes', fallback.slotStepMinutes),
      bufferMinutes: readInt('bufferMinutes', fallback.bufferMinutes),
      minAdvanceBookingHours: readInt(
        'minAdvanceBookingHours',
        fallback.minAdvanceBookingHours,
      ),
      maxAdvanceBookingDays: readInt(
        'maxAdvanceBookingDays',
        fallback.maxAdvanceBookingDays,
      ),
      minCancelHours: readInt('minCancelHours', fallback.minCancelHours),
      pendingExpiryHours: readInt(
        'pendingExpiryHours',
        fallback.pendingExpiryHours,
      ),
      requireStaffChoice: readBool(
        'requireStaffChoice',
        fallback.requireStaffChoice,
      ),
      showPricesInApp: readBool('showPricesInApp', fallback.showPricesInApp),
      allowGuestBooking: readBool(
        'allowGuestBooking',
        fallback.allowGuestBooking,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingRules &&
          other.mode == mode &&
          other.granularity == granularity &&
          other.slotStepMinutes == slotStepMinutes &&
          other.bufferMinutes == bufferMinutes &&
          other.minAdvanceBookingHours == minAdvanceBookingHours &&
          other.maxAdvanceBookingDays == maxAdvanceBookingDays &&
          other.minCancelHours == minCancelHours &&
          other.pendingExpiryHours == pendingExpiryHours &&
          other.requireStaffChoice == requireStaffChoice &&
          other.showPricesInApp == showPricesInApp &&
          other.allowGuestBooking == allowGuestBooking;

  @override
  int get hashCode => Object.hash(
    mode,
    granularity,
    slotStepMinutes,
    bufferMinutes,
    minAdvanceBookingHours,
    maxAdvanceBookingDays,
    minCancelHours,
    pendingExpiryHours,
    requireStaffChoice,
    showPricesInApp,
    allowGuestBooking,
  );
}
