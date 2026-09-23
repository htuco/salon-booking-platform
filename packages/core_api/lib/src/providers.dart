import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_repository.dart';
import 'auth/customer_repository.dart';
import 'auth/staff_repository.dart';
import 'auth/supabase_auth_repository.dart';
import 'booking/appointment_repository.dart';
import 'booking/booking_repository.dart';
import 'booking/staff_appointment_repository.dart';
import 'catalog/blocked_slot_repository.dart';
import 'catalog/employee_repository.dart';
import 'catalog/policy_repository.dart';
import 'catalog/review_repository.dart';
import 'catalog/salon_repository.dart';
import 'catalog/service_repository.dart';
import 'catalog/settings_repository.dart';
import 'catalog/staff_customer_repository.dart';
import 'catalog/working_hours_repository.dart';
import 'vertical/vertical_repository.dart';
import 'push/push_providers.dart';

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

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(supabaseClientProvider)),
);

final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => PolicyRepository(ref.watch(supabaseClientProvider)),
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

/// Blokirano vrijeme salona. Čita ga admin kalendar; klijentskoj app-i ne treba, jer je
/// za nju blokada odsustvo slota, a ne podatak.
final blockedSlotRepositoryProvider = Provider<BlockedSlotRepository>(
  (ref) => BlockedSlotRepository(ref.watch(supabaseClientProvider)),
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

/// Google OAuth client ID-evi, iz `--dart-define`-ova kroz `build_tenant.sh`.
///
/// **Aplikacija ih mora override-ovati**, isto kao [currentSalonIdProvider] i iz istog
/// razloga: `core_api` ne zna za `--dart-define`. Prazne vrijednosti su ispravno stanje —
/// znače „Google nije konfigurisan za ovaj build", i tada [AuthRepository.signInWithGoogle]
/// baca grešku koja to i kaže, umjesto da otvori dijalog koji će pasti.
///
/// Dva su, ne jedan (`docs/06 §7.1`):
/// - `web` je `serverClientId` — ono što Supabase provjerava kao `aud` u ID tokenu, i
///   **isto je za sve flavore**, jer ga korisnik nikad ne vidi;
/// - `ios` je client ID te konkretne iOS app-e, **po flavoru**, jer ga Google veže za
///   bundle ID. Android ga ne traži: tamo ga plugin izvodi iz potpisa APK-a.
final googleClientIdsProvider = Provider<GoogleClientIds>(
  (ref) => bezGoogleKlijenata,
);

/// Implementacija prijave. Test je override-uje lažnom i nikad ne dodirne mrežu.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final google = ref.watch(googleClientIdsProvider);
  return SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    google: google,
    beforeSignOut: () async => ref.read(pushServiceProvider)?.beforeSignOut(),
  );
});

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

/// Da li je korisnik prijavljen podržanim providerom. Supabase anonimnu sesiju auth
/// repozitorij mapira na `null`, pa ona ne otvara zaštićene rute.
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

/// Fotografije salona — `salons.gallery_urls`.
///
/// Zaseban provider, a ne polje na [salonProvider]: v. `SalonRepository.galleryUrls`.
/// Prazna lista je uredno stanje i znači "sakrij sekciju", ne "greška".
final salonGalleryProvider = FutureProvider<List<String>>(
  (ref) => ref
      .watch(salonRepositoryProvider)
      .galleryUrls(ref.watch(currentSalonIdProvider)),
);

/// Recenzije sa tekstom, najnovije prvo (`SPEC.md` 5m).
///
/// Prazna lista je uredno stanje: salon može imati ocjene bez ijedne napisane recenzije.
/// Tada `/reviews` crta samo prosjek i histogram, a lista ispod izostane.
final salonReviewsProvider = FutureProvider<List<Review>>(
  (ref) => ref
      .watch(reviewRepositoryProvider)
      .forSalon(ref.watch(currentSalonIdProvider)),
);

/// Prosjek, ukupan broj i histogram ocjena — jedan red iz `salon_rating_summary`.
///
/// **`null` znači „salon nema nijednu ocjenu", ne greška.** Ekran tada sakrije sekciju
/// umjesto da nacrta „0,0 od 5". Ovaj provider je zamijenio privremeni `salonRatingProvider`
/// iz `apps/client/features/home/`, koji je do taska 20 uvijek vraćao `null` jer šema nije
/// imala tabelu.
final salonRatingProvider = FutureProvider<SalonRatingSummary?>(
  (ref) => ref
      .watch(reviewRepositoryProvider)
      .summaryForSalon(ref.watch(currentSalonIdProvider)),
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

/// Sekcije „Pravila korištenja" — platformske i salonske, spojene i sortirane
/// (`SPEC.md` 5o).
///
/// Radi bez prijave: store review otvara ovaj ekran na svježoj instalaciji.
final termsProvider = FutureProvider<List<PolicySection>>(
  (ref) => ref
      .watch(policyRepositoryProvider)
      .terms(ref.watch(currentSalonIdProvider)),
);

/// Sekcije politike privatnosti. Bez `salonId` — dokument je u cijelosti platformski
/// (ADR-0009).
final privacyPolicyProvider = FutureProvider<List<PolicySection>>(
  (ref) => ref.watch(policyRepositoryProvider).privacy(),
);

/// Vrijednosti kojima se popunjavaju placeholderi u tijelu sekcije.
///
/// **Sinhron `Provider` nad `valueOrNull` triju asinhronih izvora, namjerno.** Da čeka
/// `Future.wait`, pad jednog upita (postavke, vertikala) srušio bi cijeli pravni ekran.
/// Ovako neriješen izvor znači samo da placeholder ostaje vidljiv kao `{minCancelHours}` —
/// vidljiv kvar koji neko prijavi, umjesto rečenice bez roka koja izgleda ispravno.
/// Kad izvor stigne, provider se preračuna i tekst se dopuni.
final policyPlaceholdersProvider = Provider<PolicyPlaceholders>((ref) {
  final salon = ref.watch(salonProvider).valueOrNull;
  final postavke = ref.watch(salonSettingsProvider).valueOrNull;
  final vertikala = ref.watch(verticalProvider).valueOrNull;

  return PolicyPlaceholders(
    minCancelHours: postavke?.minCancelHours,
    phone: salon?.phone,
    email: salon?.email,
    appointmentSingular: vertikala?.terms.appointmentSingular,
  );
});

// ---------------------------------------------------------------------------
// Admin aplikacija (task 23).
//
// Odvojeni od klijentskih providera jer opisuju **drugog korisnika**: osoblje koje se
// prijavljuje lozinkom i čiji salon dolazi iz članstva, ne iz `SALON_ID` flavora. Klijentska
// app ove providere nikad ne čita, i obrnuto.

/// Prijava osoblja i njegovo članstvo u salonu.
final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(
    ref.watch(supabaseClientProvider),
    beforeSignOut: () async => ref.read(pushServiceProvider)?.beforeSignOut(),
  ),
);

/// Termini salona, čitani iz admina.
final staffAppointmentRepositoryProvider = Provider<StaffAppointmentRepository>(
  (ref) => StaffAppointmentRepository(ref.watch(supabaseClientProvider)),
);

/// Adresar salona, čitan iz admina.
final staffCustomerRepositoryProvider = Provider<StaffCustomerRepository>(
  (ref) => StaffCustomerRepository(ref.watch(supabaseClientProvider)),
);

/// Trenutno prijavljen član osoblja, ili `null`.
///
/// Prati [StaffRepository.authStateChanges], pa odjava i istek tokena sami prazne ekran —
/// jednokratno čitanje bi ostavilo admin listu na ekranu nakon što sesija prestane vrijediti.
///
/// **`null` ima dva značenja i ekran ih mora razlikovati:** niko nije prijavljen, ili je
/// prijavljen neko ko nije osoblje (token ispravan, reda u `public.users` nema). Drugo je
/// pogrešno postavljen nalog, ne pogrešna lozinka.
final currentStaffProvider = StreamProvider<StaffMember?>((ref) async* {
  final repozitorij = ref.watch(staffRepositoryProvider);

  // Prvi frejm ne smije čekati na stream: router mora odmah znati smije li pustiti
  // `/dashboard`, a `onAuthStateChange` se oglasi tek na promjenu.
  yield repozitorij.currentSession == null
      ? null
      : await repozitorij.membership();

  await for (final _ in repozitorij.authStateChanges) {
    yield repozitorij.currentSession == null
        ? null
        : await repozitorij.membership();
  }
});

/// `salon_id` salona kojim prijavljeni admin upravlja; `null` dok nije prijavljen.
///
/// **Jedini izvor salona u admin app-i.** Ne postoji ekran koji ga bira niti header koji ga
/// nosi — v. `StaffMember` i ADR-0003.
final adminSalonIdProvider = Provider<String?>(
  (ref) => ref.watch(currentStaffProvider).valueOrNull?.salonId,
);

/// Vertikala salona kojim admin upravlja — terminologija za admin ekrane.
///
/// **Postoji odvojeno od [verticalProvider] iz istog razloga kao `adminServicesProvider`:**
/// onaj čita [currentSalonIdProvider], koji klijentska app override-uje iz `SALON_ID`
/// flavora, a admin app ga nema i ne smije ga imati — jedna je za sve salone (ADR-0003).
/// Neoverride-ovan provider tamo baca `UnimplementedError`.
///
/// Vraća `null` dok admin nije prijavljen ili dok salon nije poznat; ekran tada koristi
/// [Vertical.fallback], jer je generički tekst bolji od spinnera preko naslova kolone.
final adminVerticalProvider = FutureProvider<Vertical?>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref.watch(verticalRepositoryProvider).fetchForSalon(salonId);
});
