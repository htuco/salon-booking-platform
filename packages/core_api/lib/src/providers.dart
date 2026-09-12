import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_repository.dart';
import 'auth/customer_repository.dart';
import 'auth/supabase_auth_repository.dart';
import 'booking/appointment_repository.dart';
import 'booking/booking_repository.dart';
import 'catalog/employee_repository.dart';
import 'catalog/salon_repository.dart';
import 'catalog/service_repository.dart';
import 'catalog/settings_repository.dart';
import 'catalog/working_hours_repository.dart';
import 'vertical/vertical_repository.dart';

/// Supabase klijent. `bootstrap()` u aplikaciji ga inicijalizuje prije `runApp`.
///
/// Stoji u `core_api`, a ne u aplikaciji, da `supabase_flutter` ostane uvezen samo u ovom
/// sloju — inače svaki app koji doda repozitorij doda i import Supabasea, i granica sloja
/// postoji samo u dokumentu.
///
/// Test override-uje ovaj provider i nikad ne dodirne mrežu.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// `id` salona za koji je ovaj build napravljen (`SALON_ID`).
///
/// **Aplikacija ga mora override-ovati** — `core_api` ne zna za `--dart-define` ni za
/// generisani tenant registar, i ne smije znati: isti paket koristi i admin app, koji
/// nema jedan fiksni salon nego bira onaj kojim upravlja.
///
/// ```dart
/// ProviderScope(
///   overrides: [currentSalonIdProvider.overrideWithValue(env.salonId)],
///   child: const App(),
/// )
/// ```
final currentSalonIdProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'currentSalonIdProvider mora biti override-ovan u ProviderScope-u aplikacije '
    '— v. dokumentaciju u core_api/src/providers.dart',
  ),
);

final salonRepositoryProvider = Provider<SalonRepository>(
  (ref) => SalonRepository(ref.watch(supabaseClientProvider)),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(ref.watch(supabaseClientProvider)),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(ref.watch(supabaseClientProvider)),
);

final workingHoursRepositoryProvider = Provider<WorkingHoursRepository>(
  (ref) => WorkingHoursRepository(ref.watch(supabaseClientProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(supabaseClientProvider)),
);

final verticalRepositoryProvider = Provider<VerticalRepository>(
  (ref) => VerticalRepository(ref.watch(supabaseClientProvider)),
);

/// Slobodni termini i rezervacija. Jedini repozitorij koji piše u bazu.
///
/// Nema pripadajući `FutureProvider` ovdje: slobodni termini zavise od izbora korisnika
/// (usluga, datum, radnik), pa provider mora biti `family` i živi uz booking flow u
/// aplikaciji. Provider bez argumenata bi morao pogoditi za šta pita.
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(supabaseClientProvider)),
);

// ---------------------------------------------------------------------------
// Prijava. Task 13 — `docs/06 §6.3`.
// ---------------------------------------------------------------------------

/// Implementacija prijave. Test je override-uje lažnom i nikad ne dodirne mrežu.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Sesija kroz vrijeme — `null` znači odjavljen.
///
/// **Stream sa početnom vrijednošću iz `currentSession`**, a ne goli stream: `GoTrueClient`
/// emituje prvo stanje tek kad završi vraćanje sesije sa diska, pa bi ekran do tada vidio
/// `AsyncLoading` i prijavljenom korisniku bi treptao login. Sinhrono čitanje zatvara taj
/// prvi frejm (`docs/06 §6.3`), stream ga nakon toga ispravlja ako se raziđu.
final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.sessionChanges;
});

/// Sesija bez čekanja — ono što ekran i router čitaju.
///
/// Spaja sinhroni `currentSession` i stream: dok stream nema vrijednost, važi sinhrona.
/// Provider, a ne `valueOrNull` po ekranima, da svako mjesto ne bi ponavljalo isti fallback
/// i da se ne bi razišli kad jedno zaboravi.
final currentAuthSessionProvider = Provider<AuthSession?>((ref) {
  final iz = ref.watch(authSessionProvider);
  return iz.valueOrNull ?? ref.watch(authRepositoryProvider).currentSession;
});

/// Da li je iko prijavljen. Gost (`isAnonymous`) se ovdje računa kao prijavljen — on ima
/// sesiju i `customers` red; razlika ga tek tiče kod brisanja naloga (task 17).
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(currentAuthSessionProvider) != null,
);

/// Klijent prijavljenog korisnika u ovom salonu.
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(supabaseClientProvider)),
);

/// `customers.id` prijavljenog korisnika — **pravi red ako ga nema**.
///
/// Ovisi o [currentAuthSessionProvider] namjerno: prijava i odjava moraju ponovo pitati
/// bazu. Bez te veze bi korisnik koji se prijavio nakon prvog pokušaja zadržao `null` do
/// restarta app-e.
///
/// **Zove `ensureCustomer`, ne `currentCustomerId`.** Prvi put kad se neko prijavi u salon
/// reda nema i čitanje bi vratilo `null` — a jedini trenutak kad ga smijemo napraviti je
/// upravo taj. Poziv je idempotentan (`on conflict do nothing` u bazi), pa ga svaka
/// sljedeća prijava ponovi bez posljedice.
///
/// Gost (`isAnonymous`) je namjerno uključen: i on ima `auth_identities` red i rezerviše
/// pod svojim identitetom — tok gosta je task 26, ali ovdje se ne razlikuje.
final currentCustomerIdProvider = FutureProvider<String?>((ref) async {
  if (ref.watch(currentAuthSessionProvider) == null) return null;

  return ref
      .watch(customerRepositoryProvider)
      .ensureCustomer(ref.watch(currentSalonIdProvider));
});

// ---------------------------------------------------------------------------
// Podaci. Keširanje je Riverpodovo — nema ručnog cache sloja.
//
// `FutureProvider` drži rezultat dok ga neko sluša i baca ga kad niko ne sluša;
// osvježavanje je `ref.invalidate(...)`. Vlastiti cache bi značio drugu kopiju istine
// koja zastarijeva po svojim pravilima.
// ---------------------------------------------------------------------------

/// Salon za koji je build napravljen.
final salonProvider = FutureProvider<Salon>(
  (ref) => ref
      .watch(salonRepositoryProvider)
      .byId(ref.watch(currentSalonIdProvider)),
);

/// Katalog usluga aktivnog salona.
final servicesProvider = FutureProvider<List<Service>>(
  (ref) => ref
      .watch(serviceRepositoryProvider)
      .forSalon(ref.watch(currentSalonIdProvider)),
);

/// Radnici aktivnog salona.
final employeesProvider = FutureProvider<List<Employee>>(
  (ref) => ref
      .watch(employeeRepositoryProvider)
      .forSalon(ref.watch(currentSalonIdProvider)),
);

/// Veze radnik–usluga — booking flow iz njih računa presjek.
final employeeServiceLinksProvider = FutureProvider<List<EmployeeService>>(
  (ref) => ref
      .watch(employeeRepositoryProvider)
      .serviceLinksForSalon(ref.watch(currentSalonIdProvider)),
);

/// Radno vrijeme salona — i salonski redovi i oni po radniku.
final workingHoursProvider = FutureProvider<List<WorkingHour>>(
  (ref) => ref
      .watch(workingHoursRepositoryProvider)
      .forSalon(ref.watch(currentSalonIdProvider)),
);

/// Booking postavke salona.
final salonSettingsProvider = FutureProvider<SalonSettings>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .forSalon(ref.watch(currentSalonIdProvider)),
);

/// Termini prijavljenog klijenta i otkazivanje.
final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.watch(supabaseClientProvider)),
);

/// Termini prijavljenog klijenta u aktivnom salonu.
///
/// Ovisi o [currentAuthSessionProvider]: odjava mora isprazniti listu, a prijava je
/// napuniti bez restarta app-e. Osvježavanje nakon otkazivanja je
/// `ref.invalidate(myAppointmentsProvider)` — nema lokalne kopije koja bi se „ažurirala".
final myAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  if (ref.watch(currentAuthSessionProvider) == null) return const [];
  return ref.watch(appointmentRepositoryProvider).forCurrentCustomer();
});

/// Vertikala salona — terminologija, pravila i feature flagovi.
final verticalProvider = FutureProvider<Vertical>(
  (ref) => ref
      .watch(verticalRepositoryProvider)
      .fetchForSalon(ref.watch(currentSalonIdProvider)),
);
