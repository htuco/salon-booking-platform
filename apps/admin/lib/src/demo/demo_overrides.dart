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
import '../features/dashboard/danas.dart' show sljedeciRadniDan;
import '../features/dashboard/danas_providers.dart';
import '../features/settings/pristup.dart';
import '../features/settings/settings_providers.dart';
import '../features/working_hours/working_hours_providers.dart';

/// Koji salon demo glumi: `--dart-define=DEMO_SALON=amko` daje Amko Barbershop, bez
/// njega je Vitez iz `supabase/seed.sql`.
///
/// Admin nema flavor (ADR-0003), pa se salon ne bira tenantom nego ovim define-om. Raspored,
/// usluge i brojke su isti u oba; mijenjaju se ime salona, vlasnik i imena radnika — dovoljno
/// da snimak za predstavljanje pokaže pravog klijenta, a ne seed salon.
const _demoSalon = String.fromEnvironment('DEMO_SALON');
const _amko = _demoSalon == 'amko';

const _salonId = _amko
    ? '63679dd5-6ac8-4061-b4d6-d3ef181c9baa'
    : '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: _amko ? 'Amrudin Topčić' : 'Emir Bešić',
  email: _amko ? 'amko@amkobarber.test' : 'emir@barberstudiovitez.test',
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
  // Danas (task 55) čita smjene, blokade, sedmicu i sljedeći radni dan. Bez smjena demo
  // nikad ne bi nacrtao „Najveća rupa", zauzetost u procentima ni „U smjeni 3" — prvi
  // demo dashboarda je tako i izgledao: „— nema smjena za danas" uz pun raspored.
  dashboardRasporedProvider.overrideWith((ref) async => _radnoVrijeme),
  dashboardBlokadeProvider.overrideWith((ref) async => const <BlockedSlot>[]),
  sedmicaProvider.overrideWith((ref) async => 38),
  sljedeciRadniDanProvider.overrideWith((ref) async {
    final sljedeci = sljedeciRadniDan(_radnoVrijeme, DateTime.now());
    if (sljedeci == null) return null;
    return (dan: sljedeci.dan, otvara: sljedeci.otvara, termina: 16);
  }),
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

/// Dan iz handoffa `6a`: tri radnika, 17 termina, tri zahtjeva, jedan otkaz i jedan
/// nedolazak — svako stanje koje raspored crta ima bar jedan red.
///
/// Brojevi su demo sadržaj, ne podatak iz baze — v. `SPEC.md`, „Funkcionalne granice".
/// Vremena su fiksna, a sat je pravi: u 13:12 demo izgleda kao `6a`, u 9:00 svi termini
/// tek dolaze, a uveče su svi prošli.
final List<Appointment> _termini = [
  _termin(
    'Adnan Kovač',
    9,
    30,
    10,
    10,
    _emir,
    _fade,
    AppointmentStatus.completed,
  ),
  _termin(
    'Damir Šarić',
    10,
    0,
    10,
    45,
    _vedad,
    _fadeBrada,
    AppointmentStatus.noShow,
  ),
  _termin(
    'Senad Mujić',
    10,
    30,
    11,
    0,
    _emir,
    _brada,
    AppointmentStatus.cancelled,
  ),
  _termin(
    'Kemal Hadžić',
    11,
    0,
    11,
    40,
    _vedad,
    _fadeBrada,
    AppointmentStatus.completed,
  ),
  _termin(
    'Edin Ramić',
    11,
    20,
    11,
    50,
    _emir,
    _musko,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Tarik Selimović',
    12,
    40,
    13,
    20,
    _vedad,
    _brada,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Jasmin Kurtović',
    13,
    0,
    13,
    30,
    _amar,
    _musko,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Haris Delić',
    13,
    30,
    14,
    0,
    _emir,
    _musko,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Ibro Halilović',
    14,
    10,
    14,
    40,
    _emir,
    _musko,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Faruk Begić',
    14,
    30,
    15,
    10,
    _vedad,
    _fade,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Nedim Hodžić',
    15,
    0,
    15,
    40,
    _amar,
    _fadeBrada,
    AppointmentStatus.pending,
    poslanPrije: 26,
  ),
  _termin(
    'Eldar Hasić',
    15,
    20,
    15,
    50,
    _vedad,
    _musko,
    AppointmentStatus.pending,
    poslanPrije: 7,
  ),
  _termin(
    'Dino Mehmedović',
    15,
    30,
    16,
    10,
    _emir,
    _fade,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Armin Pašić',
    16,
    10,
    16,
    50,
    _vedad,
    _fadeBrada,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Almir Šahić',
    17,
    0,
    17,
    30,
    _amar,
    _musko,
    AppointmentStatus.pending,
    poslanPrije: 12,
  ),
  _termin(
    'Samir Babić',
    17,
    40,
    18,
    10,
    _emir,
    _musko,
    AppointmentStatus.confirmed,
  ),
  _termin(
    'Kenan Zukić',
    19,
    20,
    19,
    50,
    _vedad,
    _musko,
    AppointmentStatus.confirmed,
  ),
];

final _salon = Salon(
  id: _salonId,
  name: _amko ? 'Amko Barbershop' : 'Barber Studio Vitez',
  slug: _amko ? 'amkobarber' : 'barber-studio-vitez',
  city: 'Vitez',
);

/// Cjenovnik i ekipa iz `supabase/seed.sql`, skraćeno.
const _fade = 'demo-fade';
const _brada = 'demo-brada';
const _musko = 'demo-musko';
const _fadeBrada = 'demo-fade-brada';

const _usluge = [
  Service(
    id: _fade,
    salonId: _salonId,
    name: 'Fade šišanje',
    price: 20,
    durationMinutes: 40,
  ),
  Service(
    id: _brada,
    salonId: _salonId,
    name: 'Brada + konturisanje',
    price: 15,
    durationMinutes: 30,
  ),
  Service(
    id: _musko,
    salonId: _salonId,
    name: 'Muško šišanje',
    price: 15,
    durationMinutes: 30,
  ),
  Service(
    id: _fadeBrada,
    salonId: _salonId,
    name: 'Fade + brada',
    price: 30,
    durationMinutes: 40,
  ),
];

const _emir = 'demo-emir';
const _vedad = 'demo-vedad';
const _amar = 'demo-amar';

const _radnici = [
  Employee(id: _emir, salonId: _salonId, name: _amko ? 'Amko' : 'Emir'),
  Employee(id: _vedad, salonId: _salonId, name: _amko ? 'Eniz' : 'Vedad'),
  // Amar počinje kasnije od ostalih, pa kalendar pokazuje i pojas „Ne radi do 12:00".
  Employee(id: _amar, salonId: _salonId, name: 'Amar'),
];

/// Radno vrijeme za svih sedam dana: salon 09–20, svaki radnik svoja smjena sa pauzom.
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
      endTime: const LocalTime(20, 0),
      isClosed: dan == 7,
    ),
    if (dan != 7)
      for (final (id, od, doSata, pauza) in const [
        (_emir, 9, 18, 12),
        (_vedad, 10, 20, 14),
        (_amar, 12, 20, 16),
      ])
        WorkingHour(
          id: 'demo-wh-$id-$dan',
          salonId: _salonId,
          employeeId: id,
          dayOfWeek: dan,
          startTime: LocalTime(od, 0),
          endTime: LocalTime(doSata, 0),
          breakStartTime: LocalTime(pauza, 0),
          breakEndTime: LocalTime(pauza, 30),
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

Appointment _termin(
  String ime,
  int sat,
  int minuta,
  int doSata,
  int doMinute,
  String radnik,
  String usluga,
  AppointmentStatus status, {
  int? poslanPrije,
}) {
  final sada = DateTime.now();
  return Appointment(
    id: 'demo-$ime',
    salonId: _salonId,
    serviceId: usluga,
    employeeId: radnik,
    // Klijent po imenu (FE-505): lista Klijenata se gradi iz ovih termina, a zajednički
    // id bi dao sedamnaest klijenata sa istim ključem i jednu istoriju za sve.
    customerId: 'demo-klijent-$ime',
    customerName: ime,
    customerPhone: '061 552 104',
    customerNote: ime.startsWith('Tarik')
        ? 'Sa strane 1, gore makazama. Ne kratiti brkove.'
        : null,
    date: LocalDate(sada.year, sada.month, sada.day),
    startTime: LocalTime(sat, minuta),
    endTime: LocalTime(doSata, doMinute),
    status: status,
    // „čeka 26 min" se računa iz `created_at`; zahtjev bez njega nema starost.
    createdAt: poslanPrije == null
        ? null
        : sada.subtract(Duration(minutes: poslanPrije)),
  );
}
