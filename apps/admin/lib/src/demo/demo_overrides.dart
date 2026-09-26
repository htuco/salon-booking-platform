/// Demo podaci i override-i admina — **nije production kod.**
///
/// Izdvojeno iz `lib/demo_main.dart` (FE-505), da ih i test može podići istom listom.
/// `test/demo_overrides_test.dart` otvara svaku rutu na obje širine i pada kad ekran pokaže
/// grešku učitavanja — demo koji ne pokrije provider inače se otkrije tek u QA prolazu.
///
/// Dokazuje raspored, breakpoint, navigaciju i temu. Ne dokazuje prijavu, RLS ni prave
/// podatke; to traži živi backend i `tool/run_live_demo.sh admin`.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env/app_env.dart';
import '../features/appointments/appointments_providers.dart';
import '../features/calendar/calendar_providers.dart';
import '../features/clients/clients_providers.dart';
import '../features/settings/pristup.dart';
import '../features/settings/settings_providers.dart';
import '../features/working_hours/working_hours_providers.dart';

/// Vitez iz `supabase/seed.sql`.
const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Emir Bešić',
  email: 'emir@barberstudiovitez.test',
  role: 'salon_admin',
  salonId: _salonId,
);

/// Svi override-i demo ulaza.
List<Override> demoOverrides(AdminEnv env) => [
  adminEnvProvider.overrideWithValue(env),
  // Push se u demou ne diže: `pushInitializationProvider` bi posegnuo za Firebase
  // konfiguracijom koje ovdje nema.
  pushStaffProvider.overrideWithValue(false),

  // Bez ovoga router vrti `/login`: guard traži `salon_admin` sa salonom.
  currentStaffProvider.overrideWith(
    (ref) => Stream<StaffMember?>.value(_vlasnik),
  ),
  // Brojač prati demo listu, ne izmišljenu četvorku: snimak na kojem sidebar kaže
  // „4" a lista pokaže jedan zahtjev izgleda kao greška u brojaču.
  pendingCountProvider.overrideWith(
    (ref) async =>
        _termini.where((t) => t.status == AppointmentStatus.pending).length,
  ),
  // Ekran „Danas" od taska 30 piše uslugu, majstora i cijenu uz termin, a ime salona
  // u breadcrumb — sve troje dolazi iz drugih tabela, pa demo mora napuniti i njih.
  // Bez toga bi snimak pokazao raspored bez ijednog opisa, što izgleda kao greška u
  // ekranu, a greška je u demou.
  adminSalonProvider.overrideWith((ref) async => _salon),
  // „Pristup" u Postavkama (task 45): vlasnik i jedan poziv na čekanju. Bez ovoga kartica
  // ide u bazu kojoj demo nema pristup i pokazuje grešku.
  osobljePristupProvider.overrideWith((ref) async => [_vlasnik]),
  poziviProvider.overrideWith(
    (ref) async => [
      StaffInvite(
        id: 'poziv-demo',
        name: 'Amar',
        role: 'employee',
        expiresAt: DateTime.now().add(const Duration(days: 6)),
      ),
    ],
  ),
  adminServicesProvider.overrideWith((ref) async => _usluge),
  adminEmployeesProvider.overrideWith((ref) async => _radnici),
  // Isti razlog, ekran „Osoblje": kartica radnika ispisuje **koje usluge radi**, a
  // to su veze iz `employee_services`. Bez ovog override-a provider ide u bazu,
  // padne, i sve tri kartice pišu „Usluge nisu učitane." — snimak tada pokazuje
  // stanje greške kao da je ekran pokvaren.
  adminEmployeeLinksProvider.overrideWith(
    (ref) async => [
      for (final radnik in _radnici)
        for (final usluga in _usluge)
          EmployeeService(
            id: 'link-${radnik.id}-${usluga.id}',
            salonId: _salonId,
            employeeId: radnik.id,
            serviceId: usluga.id,
          ),
    ],
  ),
  // Detalj se otvara tapom na termin; bez ovoga bi demo pokazao stanje greške, jer
  // `terminProvider` ide u bazu.
  terminProvider.overrideWith(
    (ref, id) async => _termini.where((t) => t.id == id).firstOrNull,
  ),
  zahtjeviProvider.overrideWith(
    (ref) async =>
        _termini.where((t) => t.status == AppointmentStatus.pending).toList(),
  ),
  danasnjiTerminiProvider.overrideWith((ref) async => _termini),
  // **Filter se poštuje, ne zaobilazi.** Ravna lista bi na
  // `/appointments?status=pending` prikazala svih pet termina uz izabran čip „Na
  // čekanju" — snimak koji izgleda kao dokaz, a pokazuje da filter ne radi.
  filtriraniTerminiProvider.overrideWith((ref) async {
    final filter = ref.watch(appointmentsFilterProvider);
    if (filter.status == null) return _termini;
    return _termini.where((t) => t.status == filter.status).toList();
  }),

  // Kalendar (task 31) čita četiri stvari, a ne jednu: termine **izabranog** dana,
  // radno vrijeme, blokade i radnike. Demo mora napuniti sve četiri, inače kalendar
  // nacrta osam praznih kolona i izgleda kao da ekran ne radi.
  //
  // **Termini prate izabrani dan, i nedjeljom ih nema.** Ravna lista bi isti dan
  // vratila i za nedjelju, pa bi snimak pokazao pun raspored u salonu koji tog dana
  // ne radi. Ovako strelica „sljedeći dan" vidljivo mijenja sadržaj, a neradni dan
  // izgleda kao neradni dan.
  kalendarTerminiProvider.overrideWith((ref) async {
    final dan = ref.watch(kalendarDatumProvider);
    if (dan.weekday == DateTime.sunday) return const <Appointment>[];
    return [
      for (final termin in _termini)
        termin.copyWith(date: LocalDate(dan.year, dan.month, dan.day)),
    ];
  }),
  kalendarRadnoVrijemeProvider.overrideWith((ref) async => _radnoVrijeme),
  kalendarBlokadeProvider.overrideWith((ref) async {
    final dan = ref.watch(kalendarDatumProvider);
    if (dan.weekday == DateTime.sunday) return const <BlockedSlot>[];
    return [_blokada(dan)];
  }),
  // FE-505: Klijenti, Radno vrijeme i Postavke su u demou pokazivali grešku učitavanja —
  // njihovi provideri idu u bazu, a demo ih nije punio.
  adminKlijentiProvider.overrideWith((ref) async => _klijenti),
  klijentProvider.overrideWith(
    (ref, id) async => _klijenti.where((k) => k.id == id).firstOrNull,
  ),
  klijentIstorijaProvider.overrideWith(
    (ref, id) async => [
      for (final t in _termini)
        if (t.customerId == id) t,
    ],
  ),
  radnoVrijemeProvider.overrideWith(
    (ref) async => [
      for (final wh in _radnoVrijeme)
        if (wh.employeeId == null) wh,
    ],
  ),
  buduceBlokadeProvider.overrideWith(
    (ref) async => [_blokada(DateTime.now().add(const Duration(days: 1)))],
  ),
  osobljeZaBlokadeProvider.overrideWith((ref) async => _radnici),
  postavkeSalonProvider.overrideWith((ref) async => _salon),
  postavkeBookingProvider.overrideWith(
    (ref) async => const SalonSettings(id: 'demo-settings', salonId: _salonId),
  ),
  postavkeSekcijeProvider.overrideWith((ref) async => const <PolicySection>[]),
  // Demo nema bucket; prazna galerija je i stanje novog salona.
  postavkeGalerijaProvider.overrideWith((ref) async => const <String>[]),
];

/// Klijenti iz demo rasporeda — isti ljudi koji stoje u terminima, da profil otvoren iz
/// liste ima istoriju.
final List<Customer> _klijenti = [
  for (final t in _termini)
    Customer(
      id: t.customerId,
      salonId: _salonId,
      name: t.customerName,
      phone: '061 000 ${t.startTime.hour.toString().padLeft(3, '0')}',
    ),
];

/// Raspored dana iz canvasa `3b`/`3k`, da ljuska ima šta da nosi.
///
/// Brojevi su demo sadržaj, ne podatak iz baze — v. `SPEC.md`, „Funkcionalne granice".
final List<Appointment> _termini = [
  // Jedan završen termin, da „9 završeno · 5 predstoji" i „Promet do sada" imaju šta
  // pokazati — inače je promet uvijek 0 KM i izgleda kao da brojka ne radi.
  _termin('Adnan Kovač', 10, 0, AppointmentStatus.completed),
  _termin('Tarik Selimović', 13, 0, AppointmentStatus.confirmed),
  _termin('Haris Delić', 14, 20, AppointmentStatus.confirmed),
  _termin('Nedim Hodžić', 15, 0, AppointmentStatus.pending),
  _termin('Almir Šahić', 17, 30, AppointmentStatus.pending),
  _termin('Faruk Begić', 16, 10, AppointmentStatus.confirmed),
  _termin('Kenan Zukić', 19, 20, AppointmentStatus.confirmed),
];

final _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barber-studio-vitez',
  city: 'Vitez',
);

/// Cjenovnik i ekipa iz `supabase/seed.sql`, skraćeno.
const _usluge = [
  Service(
    id: 'demo-fade',
    salonId: _salonId,
    name: 'Fade šišanje',
    price: 20,
    durationMinutes: 40,
  ),
  Service(
    id: 'demo-brada',
    salonId: _salonId,
    name: 'Brada + konturisanje',
    price: 15,
    durationMinutes: 30,
  ),
];

const _radnici = [
  Employee(id: 'demo-emir', salonId: _salonId, name: 'Emir'),
  Employee(id: 'demo-vedad', salonId: _salonId, name: 'Vedad'),
  // Treći radnik **nema nijedan termin** i počinje kasnije od ostalih. Oba su namjerna:
  // kalendar tako pokazuje i praznu kolonu i pojas „Ne radi do 12:00", koje demo sa dva
  // puna radnika nikad ne bi nacrtao.
  Employee(id: 'demo-amar', salonId: _salonId, name: 'Amar'),
];

/// Radno vrijeme za svih sedam dana: salon 09–17, Amar 12–20 sa pauzom.
///
/// Nedjelja je zatvorena, kao u `supabase/seed.sql` — strelica „sljedeći dan" tako prije
/// ili kasnije dođe do dana koji se **vidi** kao neradan.
final List<WorkingHour> _radnoVrijeme = [
  for (var dan = 1; dan <= 7; dan++) ...[
    WorkingHour(
      id: 'demo-wh-salon-$dan',
      salonId: _salonId,
      dayOfWeek: dan,
      startTime: const LocalTime(9, 0),
      endTime: LocalTime(dan == 6 ? 14 : 17, 0),
      isClosed: dan == 7,
    ),
    if (dan != 7)
      WorkingHour(
        id: 'demo-wh-amar-$dan',
        salonId: _salonId,
        employeeId: 'demo-amar',
        dayOfWeek: dan,
        startTime: const LocalTime(12, 0),
        endTime: const LocalTime(20, 0),
        breakStartTime: const LocalTime(15, 0),
        breakEndTime: const LocalTime(16, 0),
      ),
  ],
];

/// Jedna salonska blokada, da se vidi razlika između „zauzeto" i „zatvoreno".
BlockedSlot _blokada(DateTime dan) => BlockedSlot(
  id: 'demo-blokada',
  salonId: _salonId,
  date: LocalDate(dan.year, dan.month, dan.day),
  startTime: const LocalTime(11, 0),
  endTime: const LocalTime(12, 0),
  reason: 'Isporuka robe',
);

Appointment _termin(String ime, int sat, int minuta, AppointmentStatus status) {
  final sada = DateTime.now();
  return Appointment(
    id: 'demo-$ime',
    salonId: _salonId,
    serviceId: sat.isEven ? 'demo-fade' : 'demo-brada',
    employeeId: sat.isEven ? 'demo-emir' : 'demo-vedad',
    // Klijent po imenu (FE-505): lista Klijenata se gradi iz ovih termina, a zajednički
    // id bi dao sedam klijenata sa istim ključem i jednu istoriju za sve.
    customerId: 'demo-klijent-$ime',
    customerName: ime,
    customerPhone: '061 552 104',
    customerNote: ime.startsWith('Tarik')
        ? 'Sa strane 1, gore makazama. Ne kratiti brkove.'
        : null,
    date: LocalDate(sada.year, sada.month, sada.day),
    startTime: LocalTime(sat, minuta),
    endTime: LocalTime(minuta >= 20 ? sat + 1 : sat, (minuta + 40) % 60),
    status: status,
  );
}
