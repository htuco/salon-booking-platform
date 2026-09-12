import 'package:core_api/core_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `customers.id` korisnika koji rezerviše — **asinhrono, jer to stvarno jeste**.
///
/// ## Zašto `FutureProvider`, a ne `String?`
///
/// Red pravi `public.ensure_customer` pri prvoj prijavi u salon (task 14), pa je vrijednost
/// rezultat mrežnog poziva. Dok je bio sinhroni snimak (`.valueOrNull`), `null` je značio
/// dvije različite stvari: „nema klijenta" i „zahtjev je još u letu". Korisnik koji dodirne
/// „Pošalji zahtjev" pola sekunde nakon prijave dobijao je grešku, a red je u bazi već
/// postojao — nađeno u browseru, sa `ensure_customer` u `17:52:11.529` i dodirom odmah
/// iza. `await` na future čeka onaj isti poziv umjesto da čita zastarjeli snimak.
///
/// ## Šta ostaje `null`
///
/// Samo neprijavljen korisnik. Greška (istekla sesija, pogrešan `x-salon-id`) izlazi kao
/// [ApiError] kroz future i ekran je prikaže — ne pretvara se u `null` koji bi izgledao
/// isto kao odjava.
///
/// Override-uje ga test (da bi `409` putanja uopšte mogla da se izazove) i `demo_main.dart`
/// (da bi se flow mogao vidjeti i snimiti bez backenda):
///
/// ```dart
/// bookingCustomerIdProvider.overrideWith((ref) async => '30000000-…')
/// ```
final bookingCustomerIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(currentCustomerIdProvider.future),
);
