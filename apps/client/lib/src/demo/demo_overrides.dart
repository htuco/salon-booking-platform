/// Demo podaci i override-i klijenta — **nije production kod.**
///
/// Izdvojeno iz `lib/demo_main.dart` (FE-505) da ih i test može podići: demo koji ne pokrije
/// provider ne pukne u testu nego tek u browseru, i to na ekranu koji QA prolaz ne vidi.
/// `test/demo_overrides_test.dart` podiže svaku rutu sa **ovom** listom na oba tenanta i pada
/// kad ekran pukne ili pokaže grešku učitavanja.
///
/// Podaci su prepisani iz `supabase/seed.sql` i vrijede tačno onoliko koliko im seed odgovara.
/// Provideri se pune iz registra po `SALON_ID`-u, isto kao što bi ih napunio repozitorij —
/// mijenja se izvor podataka, ne ekran.
library;

import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env/app_env.dart';
import '../features/booking/booking_flow_provider.dart';
import '../features/booking/booking_submit_provider.dart';

/// Da li demo pokriva salon [salonId].
bool imaDemoPodataka(String salonId) => _demoPodaci.containsKey(salonId);

/// Svi override-i demo ulaza za [env]. Baca ako za salon nema demo podataka.
///
/// [prijavljen] bira početno stanje demo klijenta; `false` pokazuje neprijavljene Termine
/// i Postavke.
List<Override> demoOverrides(AppEnv env, {bool prijavljen = true}) {
  final demo = _demoPodaci[env.salonId];
  if (demo == null) {
    throw StateError(
      'Nema demo podataka za SALON_ID=${env.salonId}. Demo pokriva dva salona iz '
      'supabase/seed.sql — v. _demoPodaci u lib/src/demo/demo_overrides.dart.',
    );
  }
  final salonId = env.salonId;

  return [
    appEnvProvider.overrideWithValue(env),
    currentSalonIdProvider.overrideWithValue(salonId),
    salonProvider.overrideWith((ref) async => demo.salon),
    servicesProvider.overrideWith((ref) async => demo.services),
    employeesProvider.overrideWith((ref) async => demo.employees),
    // Bez ovoga drugi korak flowa prikaze gresku umjesto radnika: provider bi
    // posegnuo za `Supabase.instance`, a demo build ga nema. Prazna lista veza
    // znaci "svi radnici rade svaku uslugu", sto je za demo tacno.
    employeeServiceLinksProvider.overrideWith(
      (ref) async => const <EmployeeService>[],
    ),
    workingHoursProvider.overrideWith((ref) async => demo.hours),
    verticalProvider.overrideWith((ref) async => demo.vertical),
    salonSettingsProvider.overrideWith(
      (ref) async => SalonSettings(id: 'demo-settings', salonId: salonId),
    ),

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
    // Success ekran čita zadnji termin. Slanje u demou ne postoji, pa se
    // `/book/success` otvara direktno preko URL-a, sa ovim terminom.
    lastBookingProvider.overrideWith(
      () => _DemoZadnjiTermin(demo.services.first.id),
    ),

    // FE-505: izvori bez kojih su Galerija, Recenzije i pravni ekrani u demou
    // pokazivali grešku učitavanja umjesto sadržaja.
    salonGalleryProvider.overrideWith((ref) async => _galerija),
    salonRatingProvider.overrideWith((ref) async => _ocjena(salonId)),
    salonReviewsProvider.overrideWith((ref) async => _recenzije(salonId)),
    termsProvider.overrideWith((ref) async => _pravila),
    privacyPolicyProvider.overrideWith((ref) async => _privatnost),

    // FE-505: Termini i Postavke su bez ovoga u demou pucali u sivu površinu —
    // `authRepositoryProvider` posegne za `Supabase.instance`. Demo je prijavljen
    // demo klijent sa jednim narednim i dva prošla termina.
    authRepositoryProvider.overrideWithValue(_DemoAuth(prijavljen: prijavljen)),
    currentCustomerIdProvider.overrideWith((ref) async => _demoKlijentId),
    myAppointmentsProvider.overrideWith(
      (ref) async => _mojiTermini(salonId, demo),
    ),
  ];
}

const _demoKlijentId = '30000000-0000-4000-8000-000000000001';

/// Placeholder ploče spakovane uz app (`assets/demo/`), do šest — koliko Početna crta.
const _galerija = [
  'assets/demo/ph1.png',
  'assets/demo/ph2.png',
  'assets/demo/ph3.png',
  'assets/demo/ph4.png',
  'assets/demo/ph1.png',
  'assets/demo/ph2.png',
];

SalonRatingSummary _ocjena(String salonId) => SalonRatingSummary(
  salonId: salonId,
  average: 4.8,
  total: 25,
  count5: 21,
  count4: 3,
  count3: 1,
);

List<Review> _recenzije(String salonId) {
  final sada = DateTime.now();
  return [
    Review(
      id: 'demo-r1',
      salonId: salonId,
      authorName: 'Nedim H.',
      rating: 5,
      comment:
          'Uvijek isto, tačno kako tražim. Nema čekanja kad se zakaže preko '
          'aplikacije.',
      createdAt: sada.subtract(const Duration(days: 3)),
    ),
    Review(
      id: 'demo-r2',
      salonId: salonId,
      authorName: 'Amar S.',
      rating: 5,
      comment: 'Brzo, uredno, cijena poštena.',
      createdAt: sada.subtract(const Duration(days: 14)),
    ),
    Review(
      id: 'demo-r3',
      salonId: salonId,
      authorName: 'Haris M.',
      rating: 4,
      comment:
          'Sve super, jedino subotom zna biti gužva — termin uzmite ranije.',
      createdAt: sada.subtract(const Duration(days: 32)),
    ),
  ];
}

final _izmjena = DateTime(2026, 5, 1);

final _pravila = [
  PolicySection(
    id: 'demo-t1',
    sortOrder: 1,
    title: 'Zakazivanje',
    body:
        'Zahtjev za termin nije potvrda. Termin je potvrđen tek kad salon prihvati '
        'zahtjev i kad dobijete obavještenje u aplikaciji.',
    updatedAt: _izmjena,
  ),
  PolicySection(
    id: 'demo-t2',
    sortOrder: 2,
    title: 'Otkazivanje',
    body:
        'Termin možete otkazati najkasnije 3 sata prije početka. Kasnije '
        'otkazivanje ili nedolazak salon može evidentirati.',
    updatedAt: _izmjena,
  ),
];

final _privatnost = [
  PolicySection(
    id: 'demo-p1',
    sortOrder: 1,
    title: 'Koje podatke čuvamo',
    body:
        'Ime, email i termine koje zakažete. Podaci služe samo za zakazivanje u '
        'ovom salonu i ne dijele se sa drugim salonima.',
    updatedAt: _izmjena,
  ),
];

/// Jedan naredni termin (sutra, potvrđen) i dva prošla — dovoljno da se vide oba taba
/// „Mojih termina" i dugme za otkazivanje.
List<Appointment> _mojiTermini(String salonId, _Demo demo) {
  final danas = DateTime.now();
  LocalDate prije(int dana) {
    final d = danas.subtract(Duration(days: dana));
    return LocalDate(d.year, d.month, d.day);
  }

  Appointment termin(
    String id,
    LocalDate datum,
    int sat,
    AppointmentStatus status,
    int usluga,
  ) {
    final s = demo.services[usluga % demo.services.length];
    final kraj = sat * 60 + s.durationMinutes;
    return Appointment(
      id: id,
      salonId: salonId,
      serviceId: s.id,
      employeeId: demo.employees.first.id,
      customerId: _demoKlijentId,
      customerName: 'Demo klijent',
      date: datum,
      startTime: LocalTime(sat, 0),
      endTime: LocalTime(kraj ~/ 60, kraj % 60),
      status: status,
    );
  }

  return [
    termin('demo-a1', _demoDatum(), 14, AppointmentStatus.confirmed, 0),
    termin('demo-a2', prije(9), 10, AppointmentStatus.completed, 1),
    termin('demo-a3', prije(30), 11, AppointmentStatus.completed, 2),
  ];
}

/// Prijava u demou — sesija u memoriji, mreža se ne dodiruje.
///
/// Odjava i brisanje računa rade (sesija postane `null`), pa se u demou vidi i
/// neprijavljeno stanje Termina i Postavki. Svaka prijava vraća istu demo sesiju.
class _DemoAuth implements AuthRepository {
  _DemoAuth({required bool prijavljen})
    : _sesija = prijavljen ? _sesijaDemo : null;

  static const _sesijaDemo = AuthSession(
    userId: 'demo-user',
    providers: {'email'},
    email: 'demo@primjer.ba',
  );

  final _kontroler = StreamController<AuthSession?>.broadcast();
  AuthSession? _sesija;

  void _postavi(AuthSession? s) {
    _sesija = s;
    _kontroler.add(s);
  }

  Future<AuthSession> _prijavi() async {
    _postavi(_sesijaDemo);
    return _sesijaDemo;
  }

  @override
  Stream<AuthSession?> get sessionChanges => _kontroler.stream;

  @override
  AuthSession? get currentSession => _sesija;

  @override
  Future<AuthSession> signInWithApple() => _prijavi();

  @override
  Future<AuthSession> signInWithGoogle() => _prijavi();

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) => _prijavi();

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) => _prijavi();

  @override
  Future<AuthSession> continueAsGuest({required String name}) => _prijavi();

  @override
  Future<void> signOut() async => _postavi(null);

  @override
  Future<void> deleteAccount() async => _postavi(null);
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
  _DemoZadnjiTermin(this.serviceId);

  /// Usluga **ovog** tenanta. Fiksni id je ranije znacio da beauty success ekran
  /// prikaze prazan red: termin je nosio barberovu uslugu, koje u beauty katalogu nema.
  final String serviceId;

  @override
  Appointment? build() => Appointment(
    id: '40000000-0000-4000-8000-000000000001',
    salonId: ref.watch(currentSalonIdProvider),
    serviceId: serviceId,
    customerId: '30000000-0000-4000-8000-000000000001',
    customerName: 'Demo',
    date: _demoDatum(),
    startTime: const LocalTime(10, 0),
    endTime: const LocalTime(10, 30),
    status: AppointmentStatus.pending,
  );
}

/// Prvi sljedeci dan u kojem demo salon radi — nedjelja se preskace.
///
/// Bez preskakanja success ekran zna pokazati termin u nedjelju, kad je salon po
/// `seed.sql` zatvoren. Nije bug u ekranu, ali je pogresan podatak na slici koja sluzi
/// kao dokaz.
LocalDate _demoDatum() {
  var dan = DateTime.now().add(const Duration(days: 1));
  if (dan.weekday == DateTime.sunday) {
    dan = DateTime(dan.year, dan.month, dan.day + 1);
  }
  return LocalDate(dan.year, dan.month, dan.day);
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
        imageUrl: 'assets/demo/ph1.png',
      ),
      Employee(
        id: '20000000-0000-4000-8000-000000000002',
        salonId: _barberId,
        name: 'Amar',
        role: 'Barber',
        imageUrl: 'assets/demo/ph2.png',
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
        imageUrl: 'assets/demo/ph3.png',
      ),
      Employee(
        id: '20000000-0000-4000-8000-000000000004',
        salonId: _beautyId,
        name: 'Lejla',
        role: 'Stilistica',
        imageUrl: 'assets/demo/ph4.png',
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
