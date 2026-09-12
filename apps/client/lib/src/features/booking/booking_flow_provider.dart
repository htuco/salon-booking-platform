import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'booking_flow_state.dart';

/// Stanje booking flowa — **jedan provider za sva četiri koraka**.
///
/// Alternativa bi bila da svaki ekran prima izbore prethodnih kroz konstruktor ili query
/// parametre. To izgleda uredno do trećeg koraka, a na četvrtom znači šest parametara koje
/// svaki ekran mora proslijediti dalje i koje `go_router` mora serijalizovati u URL. Uz to,
/// povratak nazad tada gubi izbor — ekran se rekonstruiše iz rute, a ruta nosi samo ono što
/// je neko ručno upisao.
///
/// Provider je zato `autoDispose`: flow živi dok je korisnik u njemu, a izlazak iz `/book/*`
/// ga čisti sam. Bez `autoDispose` bi izbor prošlog booking pokušaja dočekao korisnika
/// sljedeći put kad krene iznova — sa datumom koji je u međuvremenu prošao.
final bookingFlowProvider =
    NotifierProvider.autoDispose<BookingFlowNotifier, BookingFlowState>(
      BookingFlowNotifier.new,
    );

/// Mijenja [BookingFlowState] — jedini put kojim izbor ulazi u flow.
///
/// Metode su imenovane po koraku koji ih poziva, a ne kao generički `set`: `chooseService`
/// mora obrisati radnika i termin, a `setServiceId` ne bi sugerisao da to radi.
class BookingFlowNotifier extends AutoDisposeNotifier<BookingFlowState> {
  @override
  BookingFlowState build() => BookingFlowState.empty;

  /// Bira uslugu i **briše sve nakon nje**.
  ///
  /// Druga usluga znači drugo trajanje i moguće druge radnike, pa prethodno izabrani slot
  /// više ne postoji u listi koju vraća `get_available_slots`. Zadržan slot bi preživio do
  /// potvrde i tamo pao kao `409` — greška koja izgleda kao utrka, a zapravo je naša.
  ///
  /// Ponovni izbor iste usluge ne dira ostalo: korisnik koji se vrati na prvi korak i
  /// potvrdi isti izbor ne smije izgubiti termin.
  void chooseService(String serviceId) {
    if (state.serviceId == serviceId) return;
    state = BookingFlowState(serviceId: serviceId);
  }

  /// Bira radnika i briše termin — slobodna vremena se razlikuju po radniku.
  void chooseEmployee(String employeeId) {
    if (state.employeeId == employeeId && state.employeeChosen) return;
    state = state
        .clearFrom(BookingStep.slot)
        .copyWith(employeeId: employeeId, employeeChosen: true);
  }

  /// Bira "bilo koji radnik" — dozvoljeno kad `requireStaffChoice` nije uključen.
  ///
  /// Radnika tada dodjeljuje `book_appointment` pri re-validaciji slota. Ekran ga ne bira
  /// sam iz liste "slobodnih" jer bi ta lista do potvrde zastarjela.
  void chooseAnyEmployee() {
    state = state.clearFrom(BookingStep.slot).withAnyEmployee();
  }

  /// Bira datum i briše vrijeme — vremena su vezana za dan.
  void chooseDate(LocalDate date) {
    if (state.date == date) return;
    state = state.clearFrom(BookingStep.slot).copyWith(date: date);
  }

  /// Bira tačan termin. U `date_only` modu se ne poziva.
  void chooseSlot({required LocalDate date, required LocalTime startTime}) {
    state = state
        .clearFrom(BookingStep.slot)
        .copyWith(date: date, startTime: startTime);
  }

  /// Napomena salonu iz zadnjeg koraka.
  ///
  /// Prazan tekst se pamti kao `null`, da se ne šalje prazan string u `p_note`.
  void setNote(String? note) {
    final trimmed = note?.trim();
    state = state.copyWith(
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  /// Briše samo izabrano vrijeme, zadržava dan — v. [BookingFlowState.withoutStartTime].
  void clearStartTime() {
    state = state.withoutStartTime();
  }

  /// Briše korak i sve nakon njega — koristi ga povratak nazad kad izbor prestane važiti.
  void clearFrom(BookingStep step) {
    state = state.clearFrom(step);
  }

  /// Prazan flow. Zove se sa success ekrana i sa "kreni ispočetka".
  void reset() {
    state = BookingFlowState.empty;
  }
}

/// Da li salon bira samo datum (`date_only`), bez tačnog vremena.
///
/// Čita se iz vertikale, ne iz konstante: isti build služi i frizera (`exact_slot`) i
/// ordinaciju (`date_only`) — v. `docs/05 §4.1`.
final bookingDateOnlyProvider = Provider.autoDispose<bool>((ref) {
  final vertical = ref.watch(verticalProvider).valueOrNull;
  return vertical?.rules.granularity == BookingGranularity.dateOnly;
});

/// Traži li vertikala izbor radnika — kad ne traži, korak nudi i "bilo koji".
final bookingRequiresStaffChoiceProvider = Provider.autoDispose<bool>((ref) {
  final vertical = ref.watch(verticalProvider).valueOrNull;
  return vertical?.rules.requireStaffChoice ?? false;
});

/// Današnji dan u zidnom vremenu — početak raspona koji nudi traka datuma.
///
/// Provider, a ne `DateTime.now()` u ekranu, iz jednog razloga: test koji podiže korak sa
/// terminima mora znati koji su dani na ekranu. Sa direktnim pozivom bi isti test prolazio
/// danas a padao prvog u mjesecu.
final bookingTodayProvider = Provider<LocalDate>((ref) {
  final sada = DateTime.now();
  return LocalDate(sada.year, sada.month, sada.day);
});

/// Argument za upit slobodnih termina — usluga, datum i (opciono) radnik.
///
/// Zaseban tip, a ne `record` u `family`-ju, zbog `==`: `family` keš ključa poredi argument,
/// pa bi bez ispravnog `==` svaki rebuild pravio novi upit ka bazi.
@immutable
class SlotQuery {
  const SlotQuery({
    required this.serviceId,
    required this.date,
    this.employeeId,
  });

  final String serviceId;
  final LocalDate date;
  final String? employeeId;

  @override
  bool operator ==(Object other) =>
      other is SlotQuery &&
      other.serviceId == serviceId &&
      other.date == date &&
      other.employeeId == employeeId;

  @override
  int get hashCode => Object.hash(serviceId, date, employeeId);
}

/// Slobodni termini za zadanu uslugu, datum i radnika — direktno iz baze.
///
/// **Osvježava se `ref.invalidate(availableSlotsProvider(query))`**, i to je jedini način:
/// nema lokalne kopije koja bi se "ažurirala". Ekran ga invalidira pri povratku na korak i
/// nakon `409`, pa korisnik bira iz liste koja je trenutna, a ne iz one koju je zapamtio
/// prije pet minuta.
final availableSlotsProvider = FutureProvider.autoDispose
    .family<List<AvailableSlot>, SlotQuery>((ref, query) {
      return ref
          .watch(bookingRepositoryProvider)
          .availableSlots(
            salonId: ref.watch(currentSalonIdProvider),
            serviceId: query.serviceId,
            date: query.date,
            employeeId: query.employeeId,
          );
    });

/// Raspon datuma za traku datuma — od danas do `maxAdvanceBookingDays`.
@immutable
class DateRangeQuery {
  const DateRangeQuery({
    required this.serviceId,
    required this.from,
    required this.to,
    this.employeeId,
  });

  final String serviceId;
  final LocalDate from;
  final LocalDate to;
  final String? employeeId;

  @override
  bool operator ==(Object other) =>
      other is DateRangeQuery &&
      other.serviceId == serviceId &&
      other.from == from &&
      other.to == to &&
      other.employeeId == employeeId;

  @override
  int get hashCode => Object.hash(serviceId, from, to, employeeId);
}

/// Dani u rasponu koji imaju bar jedan slobodan termin.
///
/// Koristi se u oba moda: u `date_only` kao jedini izbor, u `exact_slot` da traka datuma
/// odmah zasivi pune dane.
final availableDatesProvider = FutureProvider.autoDispose
    .family<List<LocalDate>, DateRangeQuery>((ref, query) {
      return ref
          .watch(bookingRepositoryProvider)
          .availableDates(
            salonId: ref.watch(currentSalonIdProvider),
            serviceId: query.serviceId,
            from: query.from,
            to: query.to,
            employeeId: query.employeeId,
          );
    });
