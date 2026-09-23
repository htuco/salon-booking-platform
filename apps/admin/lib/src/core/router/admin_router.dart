import 'package:core_api/core_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointments_providers.dart';
import '../../features/appointments/appointment_detail_screen.dart';
import '../../features/appointments/appointments_screen.dart';
import '../../features/appointments/new_appointment_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/pozivnica_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/placeholder/admin_placeholder_screen.dart';
import '../../features/working_hours/working_hours_screen.dart';

/// Rute admin aplikacije, po `docs/01-mvp-spec.md` §12.
///
/// Admin ima **svoj** router, ne dijeli ga sa klijentom: rute se ne poklapaju (`/dashboard`,
/// `/employees`), a dijeljen router bi znacio da klijentski build nosi admin ekrane.
final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // `/` nije ekran u adminu (01 §12) — vodi na `/login`. Ovo je **redirect**, ne
    // `initialLocation`: `initialLocation` na webu nadjačava URL iz adresne trake, pa bi
    // `/employees` iz bookmarka otvorio login, a URL bi i dalje pisao `/employees`.
    redirect: (context, state) {
      final putanja = state.uri.path;
      if (putanja == '/') return AdminRoute.login.path;

      // `currentStaffProvider` je stream: dok prvo citanje traje, `isLoading` je `true` i
      // **ne smije** se tumaciti kao „nije prijavljen". Bez ovoga bi svako osvjezavanje
      // stranice na webu bacilo prijavljenog admina na login, pa ga vratilo — treptaj koji
      // izgleda kao da je sesija istekla.
      // refreshListenable ponovo evaluira guard; watch bi rekonstruisao router i
      // izgubio deep link kada asinhrono ucitavanje clanstva zavrsi.
      final stanje = ref.read(currentStaffProvider);
      if (stanje.isLoading) return null;

      final clan = stanje.valueOrNull;
      final naLoginu = putanja == AdminRoute.login.path;
      // Poziv je, kao i prijava, ekran za nekoga ko još nema pristup.
      final javna = naLoginu || putanja == AdminRoute.pozivnica.path;

      // Prijavljen, ali nije osoblje nijednog salona: ostaje na loginu, koji mu objasni
      // zasto. Puštanje dalje bi dalo prazne ekrane bez ijednog objasnjenja.
      if (clan == null || !clan.isSalonAdmin) {
        return javna ? null : AdminRoute.login.path;
      }

      return javna ? AdminRoute.dashboard.path : null;
    },
    // Router se mora osvjezavati kad se sesija promijeni, inace `redirect` nikad ne
    // odradi odjavu — `go_router` ga zove samo pri navigaciji.
    refreshListenable: _ProviderSlusac(ref, currentStaffProvider),
    routes: [
      GoRoute(
        path: AdminRoute.login.path,
        name: AdminRoute.login.name,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: AdminRoute.pozivnica.path,
        name: AdminRoute.pozivnica.name,
        builder: (context, state) =>
            AdminPozivnicaScreen(kod: state.uri.queryParameters['kod']),
      ),
      GoRoute(
        path: AdminRoute.dashboard.path,
        name: AdminRoute.dashboard.name,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      // `?status=pending` je adresa „Zahtjeva" iz navigacije. Filter se čita **ovdje** i
      // prosljeđuje ekranu kao argument, a ne u ekranu iz `GoRouterState`: ekran koji čita
      // router se ne može podići u widget testu bez pravog `GoRouter`-a (v. `aktivna` u
      // `admin_scaffold.dart`).
      GoRoute(
        path: AdminRoute.appointments.path,
        name: AdminRoute.appointments.name,
        builder: (context, state) => AdminAppointmentsScreen(
          trazeniStatus: statusIzUpita(state.uri.queryParameters[kStatusUpit]),
        ),
      ),
      // **Mora stajati prije `/appointments/:id`**, inače `go_router` pročita „new" kao
      // vrijednost parametra `id` i otvori detalje termina kojeg nema. Statički segment
      // uvijek ide ispred parametra — ovdje to drži i petlja ispod, koja placeholdere
      // dodaje tek na kraju, ali oslanjati se na to znači da promjena redoslijeda u toj
      // petlji tiho obori ovu rutu.
      GoRoute(
        path: AdminRoute.appointmentNew.path,
        name: AdminRoute.appointmentNew.name,
        builder: (context, state) => const NewAppointmentScreen(),
      ),
      // Detalj termina stoji **poslije** `/appointments/new`, v. komentar iznad.
      GoRoute(
        path: AdminRoute.appointmentDetails.path,
        name: AdminRoute.appointmentDetails.name,
        builder: (context, state) => AppointmentDetailScreen(
          appointmentId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AdminRoute.calendar.path,
        name: AdminRoute.calendar.name,
        builder: (context, state) => const AdminCalendarScreen(),
      ),
      GoRoute(
        path: AdminRoute.more.path,
        name: AdminRoute.more.name,
        builder: (context, state) => const AdminMoreScreen(),
      ),
      GoRoute(
        path: AdminRoute.services.path,
        name: AdminRoute.services.name,
        builder: (context, state) => const AdminServicesScreen(),
      ),
      GoRoute(
        path: AdminRoute.clients.path,
        name: AdminRoute.clients.name,
        builder: (context, state) => const AdminClientsScreen(),
      ),
      GoRoute(
        path: AdminRoute.employees.path,
        name: AdminRoute.employees.name,
        builder: (context, state) => const AdminEmployeesScreen(),
      ),
      GoRoute(
        path: AdminRoute.workingHours.path,
        name: AdminRoute.workingHours.name,
        builder: (context, state) => const AdminWorkingHoursScreen(),
      ),
      GoRoute(
        path: AdminRoute.settings.path,
        name: AdminRoute.settings.name,
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      // Rute koje jos nemaju tijelo. Ostaju kao placeholderi do implementacije.
      //
      // **Task 29 je ovdje obrnuo raniju odluku.** Do njega je vrijedilo „celija koja vodi
      // na placeholder je gora od celije koje nema", pa navigacija nije nudila nijednu
      // nenapisanu rutu. Handoff trazi suprotno: sidebar `3b` crta svih osam modula, a
      // `3t` ih na telefonu nabraja iza „Jos". Ljuska se zato pise nad punom listom, i
      // placeholder je ono sto vlasnik vidi dok modul ne dobije ekran — vidljivo prazno
      // mjesto umjesto nevidljivog.
      for (final route in AdminRoute.values)
        if (!_napisane.contains(route))
          GoRoute(
            path: route.path,
            name: route.name,
            builder: (context, state) => AdminPlaceholderScreen(
              title: route.title,
              path: state.uri.path,
              route: route,
            ),
          ),
    ],
    errorBuilder: (context, state) => AdminPlaceholderScreen(
      title: 'Stranica ne postoji',
      path: state.uri.path,
    ),
  );
});

/// Rute koje imaju pravo tijelo — ostale dobiju placeholder iz petlje iznad.
const _napisane = {
  AdminRoute.employees,
  AdminRoute.login,
  // Task 45.
  AdminRoute.pozivnica,
  AdminRoute.dashboard,
  AdminRoute.appointments,
  // Task 24.
  AdminRoute.appointmentNew,
  // Task 30.
  AdminRoute.appointmentDetails,
  // Task 29.
  AdminRoute.more,
  // Task 31.
  AdminRoute.calendar,
  // Task 32.
  AdminRoute.services,
  // Task 35.
  AdminRoute.clients,
  // Task 34. `/calendar/block` i dalje nema svoj ekran, ali vise ne ceka `rpc`: blokada se
  // dodaje sa `/working-hours`, a `prikaziUredjivacBlokade` je spreman i za ulaz iz `3c`.
  AdminRoute.workingHours,
  // Task 36 — `/settings` je bila zadnja ruta koja je padala u placeholder petlju.
  AdminRoute.settings,
};

/// Premoscuje Riverpod provider i `Listenable` koji `go_router` ocekuje.
class _ProviderSlusac<T> extends ChangeNotifier {
  _ProviderSlusac(Ref ref, ProviderListenable<T> provider) {
    ref.listen<T>(provider, (_, _) => notifyListeners());
  }
}

/// Sve rute admin app-e. Tijela pisu taskovi iz Sprinta 2.
enum AdminRoute {
  login('/login', 'Prijava'),

  /// „Imam poziv" (task 45) — javna kao i prijava: radnik još nema nalog.
  pozivnica('/pozivnica', 'Poziv'),
  dashboard('/dashboard', 'Dashboard'),
  appointments('/appointments', 'Termini'),
  appointmentDetails('/appointments/:id', 'Detalji termina'),
  appointmentNew('/appointments/new', 'Dodaj termin'),
  calendar('/calendar', 'Kalendar'),
  calendarBlock('/calendar/block', 'Blokiraj vrijeme'),
  clients('/clients', 'Klijenti'),
  services('/services', 'Usluge'),
  employees('/employees', 'Radnici'),
  workingHours('/working-hours', 'Radno vrijeme'),
  settings('/settings', 'Postavke'),

  /// `3t` — ulaz u module koje donja navigacija ne nosi kao ćeliju.
  ///
  /// **Postoji samo zato što telefon ima četiri ćelije, a navigacija osam stavki.** Na
  /// desktopu tih pet modula stoji u sidebaru, pa se do ovog ekrana ne dolazi iz
  /// navigacije — ruta ostaje ispravna ako je neko otvori direktno.
  more('/more', 'Još');

  const AdminRoute(this.path, this.title);

  final String path;
  final String title;
}
