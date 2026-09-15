import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'booking_identity.dart';

/// Termin koji je upravo nastao — jedini podatak koji success ekran ima.
///
/// **Nije `autoDispose`, za razliku od ostatka flowa.** Slanje zadnjeg koraka odvede
/// korisnika na `/book/success`, a taj ekran više ne sluša `bookingFlowProvider` (koji se
/// tada i čisti). Kad bi i ovo bilo `autoDispose`, success ekran bi se otvorio praznog
/// sadržaja svaki put kad Riverpod odluči da počisti prije nego što novi ekran stigne da
/// se pretplati.
///
/// Čisti ga izlazak sa success ekrana, ne Riverpod.
final lastBookingProvider = NotifierProvider<LastBookingNotifier, Appointment?>(
  LastBookingNotifier.new,
);

class LastBookingNotifier extends Notifier<Appointment?> {
  @override
  Appointment? build() => null;

  void set(Appointment appointment) => state = appointment;

  void clear() => state = null;
}

/// Slanje zahtjeva — jedini poziv koji piše u bazu iz klijentske aplikacije.
///
/// Stanje je `AsyncValue<void>`: `loading` blokira dugme (drugi tap bi bio drugi termin),
/// `error` nosi `ApiError` koji ekran razlikuje po tipu. Poseban `ConflictError` je
/// očekivan ishod, ne kvar — v. `submit`.
final bookingSubmitProvider =
    AsyncNotifierProvider.autoDispose<BookingSubmitNotifier, void>(
      BookingSubmitNotifier.new,
    );

class BookingSubmitNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Šalje zahtjev i vraća `true` kad je termin nastao.
  ///
  /// Ne navigira i ne prikazuje poruke — to radi ekran, koji jedini ima `context`. Ovdje
  /// je samo poziv, njegov ishod i **jedna posljedica koja ne smije ostati ekranu**:
  /// nakon konflikta se lista slotova invalidira ovdje, da svaki pozivalac ne bi morao
  /// pamtiti isti korak.
  ///
  /// `ConflictError` je jedini ishod zbog kojeg ova metoda dira stanje flowa: slot koji je
  /// u međuvremenu otišao se briše iz izbora, datum ostaje. Bez brisanja bi korisnik
  /// ostao sa vremenom kojeg više nema i dobio isti `409` na sljedeći pokušaj.
  Future<bool> submit() async {
    final flow = ref.read(bookingFlowProvider);
    final dateOnly = ref.read(bookingDateOnlyProvider);

    // Polovičan izbor je guard, ne validacija: ekran ovdje ne smije stići. Kad stigne,
    // tiho slanje bi napravilo termin koji korisnik nije birao.
    if (!flow.isReadyToSubmit(dateOnly: dateOnly)) return false;

    state = const AsyncValue<void>.loading();

    // **Klijent se čeka, ne čita kao snimak.** `ensure_customer` ga pravi pri prvoj
    // prijavi u salon, pa je u trenutku dodira zahtjev cesto još u letu — sinhrono
    // čitanje je tada vraćalo `null` i korisnik je dobijao grešku iako je red nastao
    // (nađeno u browseru, v. status blok taska 14). `await` čeka taj isti poziv.
    final String? customerId;
    try {
      customerId = await ref.read(bookingCustomerIdProvider.future);
    } on ApiError catch (error, stack) {
      state = AsyncValue<void>.error(error, stack);
      return false;
    }

    // `null` ovdje znači samo jedno: niko nije prijavljen. Greške su izašle iznad.
    if (customerId == null) {
      state = AsyncValue<void>.error(
        const NotFoundError('Rezervacija traži prijavu'),
        StackTrace.current,
      );
      return false;
    }

    final date = flow.date!;
    // `date_only`: vrijeme dodjeljuje salon, ali `book_appointment` traži `p_start_time`.
    // Šalje se početak dana i salon ga pomjera pri potvrdi (`docs/05 §4.1`) — availability
    // se ni ovdje ne računa u Dartu.
    final startTime = flow.startTime ?? const LocalTime(0, 0);

    try {
      final deviceId = await ref.read(bookingDeviceIdProvider)();
      final appointment = await ref
          .read(bookingRepositoryProvider)
          .book(
            salonId: ref.read(currentSalonIdProvider),
            customerId: customerId,
            serviceId: flow.serviceId!,
            date: date,
            startTime: startTime,
            employeeId: flow.employeeId,
            note: flow.note,
            deviceId: deviceId,
          );

      ref.read(lastBookingProvider.notifier).set(appointment);
      state = const AsyncValue<void>.data(null);
      return true;
    } on ApiError catch (error, stack) {
      if (error is ConflictError) {
        _osvjeziSlotove(flow, date);
      }
      state = AsyncValue<void>.error(error, stack);
      return false;
    }
  }

  /// Baca zapamćenu listu slotova i vraća izbor na korak sa terminima.
  ///
  /// `ref.invalidate` je jedini način osvježavanja: stanje flowa namjerno ne drži listu
  /// slotova, pa nema kopije koja bi se "ažurirala" (v. `booking_flow_state.dart`).
  void _osvjeziSlotove(BookingFlowState flow, LocalDate date) {
    ref.invalidate(
      availableSlotsProvider(
        SlotQuery(
          serviceId: flow.serviceId!,
          date: date,
          employeeId: flow.employeeId,
        ),
      ),
    );

    // Datum i napomena preživljavaju konflikt: zauzeto je vrijeme, ne dan.
    ref.read(bookingFlowProvider.notifier).clearStartTime();
  }
}
