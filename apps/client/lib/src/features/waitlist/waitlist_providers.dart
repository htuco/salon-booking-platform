import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../booking/booking_flow_provider.dart';

/// Puni dani u rasponu kalendara (task 68): dan radi, a nema slobodnog vremena.
///
/// Računa ih baza (`waitlist_full_dates`), kao i slobodne dane — ekran ne zaključuje „pun"
/// iz prazne liste slotova, jer je prazna lista i neradni dan.
final waitlistFullDatesProvider = FutureProvider.autoDispose
    .family<Set<LocalDate>, DateRangeQuery>((ref, query) {
      return ref
          .watch(waitlistRepositoryProvider)
          .fullDates(
            salonId: ref.watch(currentSalonIdProvider),
            serviceId: query.serviceId,
            from: query.from,
            to: query.to,
            employeeId: query.employeeId,
          );
    });

/// Aktivni upisi prijavljenog klijenta u ovom salonu.
///
/// Neprijavljen korisnik dobija praznu listu, ne grešku — isti razlog kao
/// `myNotificationsProvider`: `my_waitlist` bi ga odbio sa `42501`, a odjava mora
/// isprazniti listu.
final myWaitlistProvider = FutureProvider<List<WaitlistEntry>>((ref) async {
  if (ref.watch(currentAuthSessionProvider) == null) return const [];
  return ref.watch(waitlistRepositoryProvider).mine();
});

/// Upis na listu čekanja i odjava sa nje.
///
/// `family` po ključu: panel punog dana i svaka kartica upisa imaju svoje `loading`, pa
/// „Ukloni" na jednoj kartici ne vrti indikator na drugoj. Ključ je proizvoljan string koji
/// bira ekran ([waitlistDayKey] za panel, `id` upisa za karticu).
///
/// Isti obrazac kao `CancelAppointmentNotifier`: poziv, njegov ishod i invalidacija liste.
/// Poruke i navigaciju radi ekran, jer jedini ima `context`.
final waitlistActionProvider = AsyncNotifierProvider.autoDispose
    .family<WaitlistActionNotifier, void, String>(WaitlistActionNotifier.new);

/// Ključ panela punog dana u [waitlistActionProvider].
String waitlistDayKey({
  required String serviceId,
  required LocalDate date,
  String? employeeId,
}) => 'dan:$serviceId:${date.format()}:${employeeId ?? '-'}';

class WaitlistActionNotifier
    extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  Future<void> build(String arg) async {}

  /// Upisuje prijavljenog klijenta; `true` kad je prošlo.
  Future<bool> join({
    required String serviceId,
    required LocalDate date,
    String? employeeId,
  }) => _izvrsi(
    () => ref
        .read(waitlistRepositoryProvider)
        .join(serviceId: serviceId, date: date, employeeId: employeeId),
  );

  /// Odjavljuje upis [entryId]; `true` kad je prošlo.
  Future<bool> leave(String entryId) =>
      _izvrsi(() => ref.read(waitlistRepositoryProvider).leave(entryId));

  Future<bool> _izvrsi(Future<void> Function() akcija) async {
    state = const AsyncValue<void>.loading();
    try {
      await akcija();
    } on ApiError catch (error, stack) {
      state = AsyncValue<void>.error(error, stack);
      return false;
    }

    // Lista se baca, ne „ažurira": jedina istina o upisima je u bazi. Čeka se novo čitanje,
    // da panel promijeni stanje tek kad lista to kaže, a ne da trepne na staro. Pad tog
    // čitanja ovdje ne mijenja ishod — upis ili odjava su prošli, a sekcija sama crta grešku.
    ref.invalidate(myWaitlistProvider);
    try {
      await ref.read(myWaitlistProvider.future);
    } on ApiError {
      // Namjerno prazno, v. komentar iznad.
    }
    state = const AsyncValue<void>.data(null);
    return true;
  }
}
