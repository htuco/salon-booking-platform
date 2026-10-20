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
