/// Demo ulaz za vizuelni dokaz home ekrana — **nije production entry point.**
///
/// Store build ide kroz `lib/main.dart` i `tool/build_tenant.sh`; ovaj fajl postoji da se
/// ekran može otvoriti i snimiti bez pristupa backendu. Podaci su prepisani iz
/// `supabase/seed.sql` i vrijede tačno onoliko koliko im seed odgovara.
///
/// Ono što se ovim dokazuje je upravo ono što task 10 traži: **isti kod, drugi
/// `SALON_ID`, drugi salon, druge boje, druga terminologija.** Provideri se pune iz
/// registra po `SALON_ID`-u, isto kao što bi ih napunio repozitorij — mijenja se izvor
/// podataka, ne ekran.
///
/// ```sh
/// flutter run -d chrome -t lib/demo_main.dart \
///   --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
/// ```
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/features/booking/booking_flow_provider.dart';
import 'src/features/booking/booking_submit_provider.dart';

Future<void> main() async {
  // Isti bootstrap kao production: `usePathUrlStrategy` i `AppEnv.fromDefines`. Bez
  // `SUPABASE_URL`-a `hasSupabase` je `false`, pa se `Supabase.initialize` preskače i
  // mreža se nikad ne dodirne.
  final env = await bootstrapClient();
  final demo = _demoPodaci[env.salonId];

  if (demo == null) {
    throw StateError(
      'Nema demo podataka za SALON_ID=${env.salonId}. Demo pokriva dva salona iz '
      'supabase/seed.sql — v. _demoPodaci u lib/demo_main.dart.',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appEnvProvider.overrideWithValue(env),
        currentSalonIdProvider.overrideWithValue(env.salonId),
        salonProvider.overrideWith((ref) async => demo.salon),
        servicesProvider.overrideWith((ref) async => demo.services),
        employeesProvider.overrideWith((ref) async => demo.employees),
        workingHoursProvider.overrideWith((ref) async => demo.hours),
        verticalProvider.overrideWith((ref) async => demo.vertical),

        // Booking flow (task 11). Bez ova tri override-a se `/book/slot` u demo buildu
        // sruši na `Supabase.instance` — ekrani zovu providere, a provideri bi ovdje
        // posegnuli za klijentom kojeg `bootstrapClient` namjerno nije digao.
        //
        // Slotovi su izmišljeni, ali oblik je isti kao iz `get_available_slots`:
        // jedan red po slobodnom radniku, pa isto vrijeme dolazi više puta i ekran ga
        // mora svesti (`AvailableSlotList.distinctTimes`).
        availableSlotsProvider.overrideWith(
          (ref, query) async => _demoSlotovi(demo, query),
        ),
        availableDatesProvider.overrideWith(
          (ref, query) async => _demoDatumi(query),
        ),
        // Success ekran čita zadnji termin. Slanje u demou ne postoji — `book(...)`
        // traži prijavljenog korisnika (Sprint 2) — pa se `/book/success` otvara
        // direktno preko URL-a, sa ovim terminom.
        lastBookingProvider.overrideWith(_DemoZadnjiTermin.new),
      ],
      child: const SalonClientApp(),
    ),
  );
}

/// Slobodni termini za demo: 09:00–16:30 na pola sata, po dva radnika.
///
/// **Ovo nije availability logika.** Nema buffera, radnog vremena ni blokada — to je
/// posao `get_available_slots` funkcije (task 05). Ovdje je samo prepisan *oblik*
/// odgovora, da se ekran može pogledati bez backenda.
List<AvailableSlot> _demoSlotovi(_Demo demo, SlotQuery query) {
  final radnici = query.employeeId != null
      ? [query.employeeId!]
      : [for (final e in demo.employees) e.id];

  return [
    for (var sat = 9; sat < 17; sat++)
      for (final minuta in [0, 30])
        for (final radnik in radnici)
          // Popodne petkom namjerno prazno, da se prazno stanje vidi i u demou.
          if (!(query.date.weekday == DateTime.friday && sat >= 13))
            AvailableSlot(
              startTime: LocalTime(sat, minuta),
              employeeId: radnik,
            ),
  ];
}

/// Svi dani u rasponu osim nedjelje — salon nedjeljom ne radi (`seed.sql`).
List<LocalDate> _demoDatumi(DateRangeQuery query) {
  final dani = <LocalDate>[];
  var dan = DateTime(query.from.year, query.from.month, query.from.day);
  final kraj = DateTime(query.to.year, query.to.month, query.to.day);

  while (!dan.isAfter(kraj)) {
    if (dan.weekday != DateTime.sunday) {
      dani.add(LocalDate(dan.year, dan.month, dan.day));
    }
    dan = DateTime(dan.year, dan.month, dan.day + 1);
  }
  return dani;
}

/// Zadnji termin za demo success ekran — `pending`, kako ga baza i pravi.
class _DemoZadnjiTermin extends LastBookingNotifier {
  @override
  Appointment? build() => Appointment(
    id: '40000000-0000-4000-8000-000000000001',
    salonId: ref.watch(currentSalonIdProvider),
    serviceId: '10000000-0000-4000-8000-000000000001',
    customerId: '30000000-0000-4000-8000-000000000001',
    customerName: 'Demo',
    date: _demoDatum(),
    startTime: const LocalTime(10, 0),
    endTime: const LocalTime(10, 30),
    status: AppointmentStatus.pending,
  );
}

LocalDate _demoDatum() {
  final sutra = DateTime.now().add(const Duration(days: 1));
  return LocalDate(sutra.year, sutra.month, sutra.day);
}

class _Demo {
  const _Demo({
    required this.salon,
    required this.services,
    required this.employees,
    required this.hours,
    required this.vertical,
  });

  final Salon salon;
  final List<Service> services;
  final List<Employee> employees;
  final List<WorkingHour> hours;
  final Vertical vertical;
}

const _barberId = '550e8400-e29b-41d4-a716-446655440000';
const _beautyId = '550e8400-e29b-41d4-a716-446655440001';

/// `09:00–17:00` radnim danima, `09:00–14:00` subotom, nedjeljom zatvoreno — tačno kako
/// `seed.sql` puni `working_hours` za oba demo salona.
List<WorkingHour> _radnoVrijeme(String salonId) => [
  for (var dan = 1; dan <= 7; dan++)
    WorkingHour(
      id: 'wh-$salonId-$dan',
      salonId: salonId,
      dayOfWeek: dan,
      startTime: const LocalTime(9, 0),
      endTime: dan == 6 ? const LocalTime(14, 0) : const LocalTime(17, 0),
      isClosed: dan == 7,
    ),
];

final _demoPodaci = <String, _Demo>{
  _barberId: _Demo(
    salon: const Salon(
      id: _barberId,
      name: 'Barber Studio Vitez',
      slug: 'barberstudiovitez',
      description: 'Precizni rezovi, svjež izgled i vrijeme samo za vas.',
      city: 'Vitez',
      address: 'Trg Slobode 15',
      phone: '+387 62 123 456',
      email: 'info@barberstudiovitez.ba',
      primaryColor: '#C6A667',
      secondaryColor: '#171717',
      theme: 'modern_barber',
      verticalPackKey: 'barber',
    ),
    services: const [
      Service(
        id: '10000000-0000-4000-8000-000000000001',
        salonId: _barberId,
        name: 'Muško šišanje',
        category: 'Šišanje',
        price: 15,
        durationMinutes: 30,
      ),
      Service(
        id: '10000000-0000-4000-8000-000000000003',
        salonId: _barberId,
        name: 'Šišanje + brada',
        category: 'Paketi',
        price: 25,
        durationMinutes: 45,
      ),
      Service(
        id: '10000000-0000-4000-8000-000000000004',
        salonId: _barberId,
        name: 'Fade',
        category: 'Šišanje',
        price: 20,
        durationMinutes: 40,
      ),
    ],
    employees: const [
      Employee(
        id: '20000000-0000-4000-8000-000000000001',
        salonId: _barberId,
        name: 'Emir',
        role: 'Barber',
      ),
      Employee(
        id: '20000000-0000-4000-8000-000000000002',
        salonId: _barberId,
        name: 'Amar',
        role: 'Barber',
      ),
    ],
    hours: _radnoVrijeme(_barberId),
    vertical: _barberVertical,
  ),
  _beautyId: _Demo(
    salon: const Salon(
      id: _beautyId,
      name: 'Beauty Studio Travnik',
      slug: 'beautystudiotravnik',
      description: 'Vaš trenutak njege, ljepote i opuštanja.',
      city: 'Travnik',
      address: 'Bosanska 42',
      phone: '+387 62 789 123',
      email: 'kontakt@beautystudiotravnik.ba',
      primaryColor: '#B76E79',
      secondaryColor: '#FFF5F5',
      theme: 'elegant_beauty',
      verticalPackKey: 'beauty',
    ),
    services: const [
      Service(
        id: '10000000-0000-4000-8000-000000000005',
        salonId: _beautyId,
        name: 'Žensko šišanje',
        category: 'Kosa',
        price: 25,
        durationMinutes: 45,
      ),
      Service(
        id: '10000000-0000-4000-8000-000000000007',
        salonId: _beautyId,
        name: 'Farbanje',
        category: 'Boja',
        price: 70,
        durationMinutes: 120,
      ),
      Service(
        id: '10000000-0000-4000-8000-000000000008',
        salonId: _beautyId,
        name: 'Pramenovi',
        category: 'Boja',
        price: 100,
        durationMinutes: 150,
      ),
    ],
    employees: const [
      Employee(
        id: '20000000-0000-4000-8000-000000000003',
        salonId: _beautyId,
        name: 'Amina',
        role: 'Stilistica',
      ),
      Employee(
        id: '20000000-0000-4000-8000-000000000004',
        salonId: _beautyId,
        name: 'Lejla',
        role: 'Stilistica',
      ),
    ],
    hours: _radnoVrijeme(_beautyId),
    vertical: _beautyVertical,
  ),
};

/// Terminologija prepisana iz `vertical_packs` reda u `seed.sql`. Razlika koja se na
/// screenshotu mora vidjeti je `bookCta`: barber "Zakaži termin", beauty "Rezerviši
/// termin".
final _barberVertical = Vertical.fromJson({
  'key': 'barber',
  'display_name': 'Barber',
  'terminology': {
    'businessSingular': 'Barbershop',
    'servicePlural': 'Usluge',
    'staffSingular': 'Barber',
    'staffPlural': 'Naš tim',
    'bookCta': 'Zakaži termin',
  },
  'feature_flags': {'prices': true, 'team': true, 'socialLinks': true},
  'default_theme': 'modern_barber',
});

final _beautyVertical = Vertical.fromJson({
  'key': 'beauty',
  'display_name': 'Beauty',
  'terminology': {
    'businessSingular': 'Salon',
    'serviceSingular': 'Tretman',
    'servicePlural': 'Usluge',
    'staffSingular': 'Stilistica',
    'staffPlural': 'Naš tim',
    'bookCta': 'Rezerviši termin',
  },
  'feature_flags': {'prices': true, 'team': true, 'socialLinks': true},
  'default_theme': 'elegant_beauty',
});
