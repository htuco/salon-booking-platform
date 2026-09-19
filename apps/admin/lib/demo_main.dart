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
        pendingCountProvider.overrideWith((ref) async => 4),
        danasnjiTerminiProvider.overrideWith((ref) async => _termini),
        // **Filter se poštuje, ne zaobilazi.** Ravna lista bi na
        // `/appointments?status=pending` prikazala svih pet termina uz izabran čip „Na
        // čekanju" — snimak koji izgleda kao dokaz, a pokazuje da filter ne radi.
        filtriraniTerminiProvider.overrideWith((ref) async {
          final filter = ref.watch(appointmentsFilterProvider);
          if (filter.status == null) return _termini;
          return _termini.where((t) => t.status == filter.status).toList();
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
  _termin('Tarik Selimović', 13, 0, AppointmentStatus.confirmed),
  _termin('Haris Delić', 14, 20, AppointmentStatus.confirmed),
  _termin('Nedim Hodžić', 15, 0, AppointmentStatus.pending),
  _termin('Faruk Begić', 16, 10, AppointmentStatus.confirmed),
  _termin('Kenan Zukić', 19, 20, AppointmentStatus.confirmed),
];

Appointment _termin(String ime, int sat, int minuta, AppointmentStatus status) {
  final sada = DateTime.now();
  return Appointment(
    id: 'demo-$ime',
    salonId: _salonId,
    serviceId: 'demo-usluga',
    customerId: 'demo-klijent',
    customerName: ime,
    date: LocalDate(sada.year, sada.month, sada.day),
    startTime: LocalTime(sat, minuta),
    endTime: LocalTime(minuta >= 20 ? sat + 1 : sat, (minuta + 40) % 60),
    status: status,
  );
}
