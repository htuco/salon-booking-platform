import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Obavijesti prijavljenog klijenta u aktivnom salonu (task 70).
///
/// Neprijavljen korisnik dobija praznu listu, ne grešku: `my_notifications` bi ga odbio
/// sa `42501`, a za njega je „nema obavijesti" tačan odgovor. Zavisi od sesije iz istog
/// razloga kao `myAppointmentsProvider` — odjava mora isprazniti listu.
final myNotificationsProvider = FutureProvider<List<ClientNotification>>((
  ref,
) async {
  if (ref.watch(currentAuthSessionProvider) == null) return const [];
  return ref.watch(notificationRepositoryProvider).mine();
});

/// Trenutak prema kojem se piše „Danas" i „Jučer". Provider, da test zna gdje je granica.
final notificationsNowProvider = Provider<DateTime>((ref) => DateTime.now());
