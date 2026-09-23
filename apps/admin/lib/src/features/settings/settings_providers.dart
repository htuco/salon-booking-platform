import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kontakt podaci salona — `salons` red koji klijent vidi na Početnoj.
///
/// `autoDispose`: postavke se otvore, promijene i napuste, pa cache preko života ekrana
/// samo znači da se sljedeći ulazak prikaže sa starim podacima.
final postavkeSalonProvider = FutureProvider.autoDispose<Salon?>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref.watch(salonRepositoryProvider).byId(salonId);
});

/// Booking pravila — `salon_settings`, tačno jedan red.
final postavkeBookingProvider = FutureProvider.autoDispose<SalonSettings?>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref.watch(settingsRepositoryProvider).forSalon(salonId);
});

/// Sekcije pravila **koje piše salon**.
///
/// Namjerno `salonSections`, ne `terms`: `terms` spaja i platformske sekcije, a one se iz
/// admina ne mogu promijeniti (ADR-0009). Lista koja bi ih prikazala nudila bi „Uredi" nad
/// tekstom koji `super_manage` neće pustiti.
final postavkeSekcijeProvider = FutureProvider.autoDispose<List<PolicySection>>(
  (ref) async {
    final salonId = ref.watch(adminSalonIdProvider);
    if (salonId == null) return const [];

    return ref.watch(policyRepositoryProvider).salonSections(salonId);
  },
);

/// Vrijednosti forme booking pravila prije RPC poziva.
///
/// Brojevi su `int`, ne tekst: za razliku od cijene usluge (koja putuje kao decimalni
/// tekst da ne prođe kroz binary floating point), ovo su cijeli minuti, sati i dani koje
/// `int.tryParse` iz polja daje bez gubitka.
class BookingSettingsInput {
  const BookingSettingsInput({
    required this.bookingMode,
    required this.bookingGranularity,
    required this.bufferMinutes,
    required this.slotStepMinutes,
    required this.minAdvanceBookingHours,
    required this.maxAdvanceBookingDays,
    required this.minCancelHours,
    required this.requireStaffChoice,
    required this.showPricesInApp,
    required this.allowGuestBooking,
  });

  /// Postojeće postavke kao početno stanje forme.
  factory BookingSettingsInput.from(SalonSettings s) => BookingSettingsInput(
    bookingMode: s.bookingMode,
    bookingGranularity: s.bookingGranularity,
    bufferMinutes: s.bufferMinutes,
    slotStepMinutes: s.slotStepMinutes,
    minAdvanceBookingHours: s.minAdvanceBookingHours,
    maxAdvanceBookingDays: s.maxAdvanceBookingDays,
    minCancelHours: s.minCancelHours,
    requireStaffChoice: s.requireStaffChoice,
    showPricesInApp: s.showPricesInApp,
    allowGuestBooking: s.allowGuestBooking,
  );

  final String bookingMode;
  final String bookingGranularity;
  final int bufferMinutes;
  final int slotStepMinutes;
  final int minAdvanceBookingHours;
  final int maxAdvanceBookingDays;
  final int minCancelHours;
  final bool requireStaffChoice;
  final bool showPricesInApp;
  final bool allowGuestBooking;

  BookingSettingsInput copyWith({
    String? bookingMode,
    String? bookingGranularity,
    int? bufferMinutes,
    int? slotStepMinutes,
    int? minAdvanceBookingHours,
    int? maxAdvanceBookingDays,
    int? minCancelHours,
    bool? requireStaffChoice,
    bool? showPricesInApp,
    bool? allowGuestBooking,
  }) => BookingSettingsInput(
    bookingMode: bookingMode ?? this.bookingMode,
    bookingGranularity: bookingGranularity ?? this.bookingGranularity,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    slotStepMinutes: slotStepMinutes ?? this.slotStepMinutes,
    minAdvanceBookingHours:
        minAdvanceBookingHours ?? this.minAdvanceBookingHours,
    maxAdvanceBookingDays: maxAdvanceBookingDays ?? this.maxAdvanceBookingDays,
    minCancelHours: minCancelHours ?? this.minCancelHours,
    requireStaffChoice: requireStaffChoice ?? this.requireStaffChoice,
    showPricesInApp: showPricesInApp ?? this.showPricesInApp,
    allowGuestBooking: allowGuestBooking ?? this.allowGuestBooking,
  );

  @override
  bool operator ==(Object other) =>
      other is BookingSettingsInput &&
      other.bookingMode == bookingMode &&
      other.bookingGranularity == bookingGranularity &&
      other.bufferMinutes == bufferMinutes &&
      other.slotStepMinutes == slotStepMinutes &&
      other.minAdvanceBookingHours == minAdvanceBookingHours &&
      other.maxAdvanceBookingDays == maxAdvanceBookingDays &&
      other.minCancelHours == minCancelHours &&
      other.requireStaffChoice == requireStaffChoice &&
      other.showPricesInApp == showPricesInApp &&
      other.allowGuestBooking == allowGuestBooking;

  @override
  int get hashCode => Object.hash(
    bookingMode,
    bookingGranularity,
    bufferMinutes,
    slotStepMinutes,
    minAdvanceBookingHours,
    maxAdvanceBookingDays,
    minCancelHours,
    requireStaffChoice,
    showPricesInApp,
    allowGuestBooking,
  );
}

/// Vrijednosti forme kontakt podataka.
class ContactInput {
  const ContactInput({
    required this.expectedName,
    required this.address,
    required this.city,
    required this.description,
    required this.phone,
    required this.email,
    required this.instagramUrl,
    required this.facebookUrl,
  });

  /// Build-time naziv koji je forma učitala; baza odbija svaku drugu vrijednost.
  final String expectedName;
  final String address;
  final String city;
  final String description;
  final String phone;
  final String email;
  final String instagramUrl;

  /// **Stranica salona kao kontakt, ne prijava Facebookom** — ta ne postoji
  /// (`docs/adr/0011-facebook-login-se-ne-implementira.md`).
  final String facebookUrl;
}

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  String get _salon =>
      _ref.read(adminSalonIdProvider) ??
      (throw const ServerError('Salon nije učitan'));

  Future<void> sacuvajKontakt(ContactInput unos) async {
    await _ref
        .read(salonRepositoryProvider)
        .updateContact(
          salonId: _salon,
          expectedName: unos.expectedName,
          address: unos.address,
          city: unos.city,
          description: unos.description,
          phone: unos.phone,
          email: unos.email,
          instagramUrl: unos.instagramUrl,
          facebookUrl: unos.facebookUrl,
        );
    _ref.invalidate(postavkeSalonProvider);
  }

  /// Snima booking pravila.
  ///
  /// **`min_cancel_hours` vrijedi odmah nakon ovoga**, bez novog builda: rok čita
  /// `cancel_appointment` pri svakom pozivu, a ne pri rezervaciji. Zato se ovdje ne kešira
  /// ništa i klijentska app dobije novo pravilo na sljedeće otkazivanje.
  Future<void> sacuvajPravila(BookingSettingsInput unos) async {
    await _ref
        .read(settingsRepositoryProvider)
        .update(
          salonId: _salon,
          bookingMode: unos.bookingMode,
          bookingGranularity: unos.bookingGranularity,
          bufferMinutes: unos.bufferMinutes,
          slotStepMinutes: unos.slotStepMinutes,
          minAdvanceBookingHours: unos.minAdvanceBookingHours,
          maxAdvanceBookingDays: unos.maxAdvanceBookingDays,
          minCancelHours: unos.minCancelHours,
          requireStaffChoice: unos.requireStaffChoice,
          showPricesInApp: unos.showPricesInApp,
          allowGuestBooking: unos.allowGuestBooking,
        );
    _ref.invalidate(postavkeBookingProvider);
  }

  Future<void> sacuvajSekciju({
    String? sekcijaId,
    required int sortOrder,
    required String naslov,
    required String tijelo,
  }) async {
    await _ref
        .read(policyRepositoryProvider)
        .saveSalonSection(
          salonId: _salon,
          sectionId: sekcijaId,
          sortOrder: sortOrder,
          title: naslov,
          body: tijelo,
        );
    _ref.invalidate(postavkeSekcijeProvider);
  }

  Future<void> obrisiSekciju(String sekcijaId) async {
    await _ref
        .read(policyRepositoryProvider)
        .deleteSalonSection(salonId: _salon, sectionId: sekcijaId);
    _ref.invalidate(postavkeSekcijeProvider);
  }
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);

/// Sljedeći slobodan `sort_order` za novu salonsku sekciju.
///
/// **Rijedak korak (10, 20, 30…) je namjeran**, kao u seedu: platformske sekcije stoje na
/// 10/20/30, pa salonska koja se doda na `max + 10` padne iza njih, a razmak ostavlja
/// mjesta da se kasnije jedna ubaci između bez preračunavanja cijele liste.
///
/// Broj koji korisnik vidi (`01`, `02`) se i dalje **ne čuva** — računa ga ekran iz
/// pozicije u spojenoj listi (ADR-0009).
int sljedeciSortOrder(List<PolicySection> postojece) {
  if (postojece.isEmpty) return 10;
  final najveci = postojece
      .map((s) => s.sortOrder)
      .reduce((a, b) => a > b ? a : b);
  return najveci + 10;
}
