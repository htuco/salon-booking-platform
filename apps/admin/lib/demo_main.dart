/// Demo ulaz za vizuelni dokaz admin ljuske — **nije production entry point.**
///
/// Production build ide kroz `lib/main.dart`. Ovaj fajl postoji jer se admin ekran
/// **ne može vidjeti bez prijave**, a prijava traži backend: router pušta dalje tek kad
/// `currentStaffProvider` vrati `salon_admin`. Bez lokalnog stacka (Docker, `supabase`
/// CLI) to znači da se ljuska ne bi vidjela nijednom — task 28 je iz tog razloga ostavio
/// „dashboard nije viđen na ekranu" kao dug.
///
/// Isti obrazac kao `apps/client/lib/demo_main.dart` iz taska 11: provideri se pune
/// ručno, mreža se ne dodiruje.
///
/// **Šta ovo dokazuje, a šta ne.** Dokazuje raspored, breakpoint, navigaciju i temu —
/// ono što task 29 tvrdi. Ne dokazuje prijavu, RLS ni prave podatke; to traži živi
/// backend i `tool/run_live_demo.sh admin`.
///
/// ```sh
/// # desktop ljuska
/// flutter run -d chrome -t lib/demo_main.dart
/// # telefonska ljuska — suzi prozor ispod 840 px, ili
/// flutter build web -t lib/demo_main.dart
/// ```
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';
import 'src/core/env/app_env.dart';
import 'src/core/env/bootstrap.dart';
import 'src/features/appointments/appointments_providers.dart';
import 'src/features/calendar/calendar_providers.dart';

/// Vitez iz `supabase/seed.sql`.
const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Emir Bešić',
  email: 'emir@barberstudiovitez.test',
  role: 'salon_admin',
  salonId: _salonId,
);

Future<void> main() async {
  // Isti bootstrap kao production. Bez `SUPABASE_URL`-a `hasSupabase` je `false`, pa se
  // `Supabase.initialize` preskače i mreža se nikad ne dodirne.
  final env = await bootstrapAdmin();

  runApp(
    ProviderScope(
      overrides: [
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
          (ref) async => _termini
              .where((t) => t.status == AppointmentStatus.pending)
              .length,
        ),
        // Ekran „Danas" od taska 30 piše uslugu, majstora i cijenu uz termin, a ime salona
        // u breadcrumb — sve troje dolazi iz drugih tabela, pa demo mora napuniti i njih.
        // Bez toga bi snimak pokazao raspored bez ijednog opisa, što izgleda kao greška u
        // ekranu, a greška je u demou.
        adminSalonProvider.overrideWith((ref) async => _salon),
        adminServicesProvider.overrideWith((ref) async => _usluge),
        adminEmployeesProvider.overrideWith((ref) async => _radnici),
        // Detalj se otvara tapom na termin; bez ovoga bi demo pokazao stanje greške, jer
        // `terminProvider` ide u bazu.
        terminProvider.overrideWith(
          (ref, id) async => _termini.where((t) => t.id == id).firstOrNull,
        ),
        zahtjeviProvider.overrideWith(
          (ref) async => _termini
              .where((t) => t.status == AppointmentStatus.pending)
              .toList(),
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
      ],
      child: const SalonAdminApp(),
    ),
  );
}

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
    customerId: 'demo-klijent',
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
