import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Vertikala salona — terminologija, pravila i feature flagovi.
final verticalProvider = FutureProvider<Vertical>(
  (ref) => ref
      .watch(verticalRepositoryProvider)
      .fetchForSalon(ref.watch(currentSalonIdProvider)),
);
