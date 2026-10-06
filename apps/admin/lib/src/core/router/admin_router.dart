import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../../features/profile/profile_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/placeholder/admin_placeholder_screen.dart';
import '../../features/working_hours/working_hours_screen.dart';
import '../../shell/app_shell.dart';

/// Rute admin aplikacije, po `docs/01-mvp-spec.md` §12.
///
/// Admin ima **svoj** router, ne dijeli ga sa klijentom: rute se ne poklapaju (`/today`,
/// `/more/staff`), a dijeljen router bi znacio da klijentski build nosi admin ekrane.
///
/// **Četiri grane, jedan [AppShell].** `StatefulShellRoute.indexedStack` drži Danas,
/// Kalendar, Zahtjeve i Još žive istovremeno, svaku sa svojim navigatorom: promjena taba
/// čuva scroll, otvoren detalj i filter, i ne učitava podatke ponovo. Detalj termina se
/// otvara **unutar** grane iz koje je pozvan (traka ostaje), a forma preko cijelog ekrana
/// na root navigatoru (traka se skrije). Sheetovi i dijalozi takođe idu na root, da
/// prekriju traku i da ih Android „nazad" zatvori prije ekrana ispod.
final adminRouterProvider = Provider<GoRouter>((ref) {
  // Ključevi žive koliko i router: novi router (npr. u testu) dobija nove, pa se dva
  // `Navigator`-a nikad ne bore za isti `GlobalKey`.
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');
  final danas = GlobalKey<NavigatorState>(debugLabel: 'danas');
  final kalendar = GlobalKey<NavigatorState>(debugLabel: 'kalendar');
  final zahtjevi = GlobalKey<NavigatorState>(debugLabel: 'zahtjevi');
  final jos = GlobalKey<NavigatorState>(debugLabel: 'jos');

  GoRoute ruta(
    AdminRoute route,
    Widget Function(GoRouterState state) ekran, {
    AdminRoute? roditelj,
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: roditelj == null
        ? route.path
        : route.path.substring(roditelj.path.length + 1),
    name: route.name,
    pageBuilder: (context, state) => stranicaGrane(state, ekran(state)),
    routes: routes,
  );

  GoRoute detaljTermina(AdminRoute route, AdminRoute roditelj) => ruta(
    route,
    roditelj: roditelj,
    (state) => AppointmentDetailScreen(
      appointmentId: state.pathParameters['id'] ?? '',
    ),
  );

  return GoRouter(
    navigatorKey: root,
    // `/` nije ekran u adminu (01 §12) — vodi na `/login`. Ovo je **redirect**, ne
    // `initialLocation`: `initialLocation` na webu nadjačava URL iz adresne trake, pa bi
    // `/more/staff` iz bookmarka otvorio login, a URL bi i dalje pisao `/more/staff`.
    redirect: (context, state) {
      final putanja = state.uri.path;
      if (putanja == '/') return AdminRoute.login.path;
      // Stare adrese (bookmark, link iz maila, starija notifikacija) vode na nove.
      if (staraAdresa(state.uri) case final nova?) return nova;

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
      if (clan == null || !clan.imaPristup) {
        return javna ? null : AdminRoute.login.path;
      }
      if (javna) return AdminRoute.dashboard.path;

      // Radnik ne dobija modul koji navigacija ne nudi ni kad ga otkuca u adresu (task 47).
      // Ovo je urednost, ne izolacija: podatke tih modula ionako drže admin-only politike,
      // pa bi radnik na `/more/clients` vidio prazan adresar — koji izgleda kao greška.
      if (clan.isEmployee && !dozvoljenaRadniku(putanja)) {
        return AdminRoute.dashboard.path;
      }
      return null;
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
      // Forma preko cijelog ekrana, na root navigatoru: traka se skrije, ulazi odozdo, a
      // `pop` poslije upisa vraća tačno na granu i scroll odakle je otvorena.
      GoRoute(
        path: AdminRoute.appointmentNew.path,
        name: AdminRoute.appointmentNew.name,
        parentNavigatorKey: root,
        pageBuilder: (context, state) => stranicaForme(
          state,
          NewAppointmentScreen(
            initialDate: DateTime.tryParse(
              state.uri.queryParameters['date'] ?? '',
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          lokacija: state.uri.path,
        ),
        branches: [
          // Danas se učita i kad aplikacija krene iz notifikacije u drugu granu, pa je
          // spreman čim korisnik dodirne prvi tab.
          StatefulShellBranch(
            navigatorKey: danas,
            preload: true,
            routes: [
              ruta(
                AdminRoute.dashboard,
                (_) => const AdminDashboardScreen(),
                routes: [
                  detaljTermina(
                    AdminRoute.dashboardAppointment,
                    AdminRoute.dashboard,
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: kalendar,
            routes: [
              ruta(
                AdminRoute.calendar,
                (_) => const AdminCalendarScreen(),
                routes: [
                  detaljTermina(
                    AdminRoute.calendarAppointment,
                    AdminRoute.calendar,
                  ),
                  // `/calendar/block` još nema svoj ekran: blokada se dodaje iz brzih
                  // akcija i sa radnog vremena (task 34).
                  ruta(
                    AdminRoute.calendarBlock,
                    roditelj: AdminRoute.calendar,
                    (state) => AdminPlaceholderScreen(
                      title: AdminRoute.calendarBlock.title,
                      path: state.uri.path,
                      route: AdminRoute.calendarBlock,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: zahtjevi,
            routes: [
              ruta(
                AdminRoute.requests,
                (_) => const AdminAppointmentsScreen(samoZahtjevi: true),
                routes: [
                  detaljTermina(AdminRoute.requestDetails, AdminRoute.requests),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: jos,
            routes: [
              ruta(
                AdminRoute.more,
                (_) => const AdminMoreScreen(),
                routes: [
                  // Filter se čita **ovdje** i prosljeđuje ekranu kao argument, a ne u
                  // ekranu iz `GoRouterState`: ekran koji čita router se ne može podići u
                  // widget testu bez pravog `GoRouter`-a.
                  ruta(
                    AdminRoute.appointments,
                    roditelj: AdminRoute.more,
                    (state) => AdminAppointmentsScreen(
                      trazeniStatus: statusIzUpita(
                        state.uri.queryParameters[kStatusUpit],
                      ),
                    ),
                    routes: [
                      detaljTermina(
                        AdminRoute.appointmentDetails,
                        AdminRoute.appointments,
                      ),
                    ],
                  ),
                  ruta(
                    AdminRoute.clients,
                    roditelj: AdminRoute.more,
                    (_) => const AdminClientsScreen(),
                  ),
                  ruta(
                    AdminRoute.services,
                    roditelj: AdminRoute.more,
                    (_) => const AdminServicesScreen(),
                  ),
                  ruta(
                    AdminRoute.employees,
                    roditelj: AdminRoute.more,
                    (_) => const AdminEmployeesScreen(),
                  ),
                  ruta(
                    AdminRoute.workingHours,
                    roditelj: AdminRoute.more,
                    (_) => const AdminWorkingHoursScreen(),
                  ),
                  ruta(
                    AdminRoute.settings,
                    roditelj: AdminRoute.more,
                    (_) => const AdminSettingsScreen(),
                  ),
                  ruta(
                    AdminRoute.profile,
                    roditelj: AdminRoute.more,
                    (_) => const AdminProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AdminPlaceholderScreen(
      title: 'Stranica ne postoji',
      path: state.uri.path,
    ),
  );
});

/// Stranica unutar grane: slide s desna i swipe-back sa lijeve ivice na iOS-u.
///
/// Na ostalim platformama `MaterialPage`, a prelaz bira tema (`admin_theme.dart`).
Page<void> stranicaGrane(GoRouterState state, Widget child) =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? CupertinoPage<void>(key: state.pageKey, child: child)
    : MaterialPage<void>(key: state.pageKey, child: child);

/// Forma preko cijelog ekrana na root navigatoru: ulazi odozdo, na svakoj platformi.
Page<void> stranicaForme(GoRouterState state, Widget child) =>
    CupertinoPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: child,
    );

/// Nova adresa za staru, ili `null` kad adresa nije stara.
///
/// Stare adrese su iz vremena prije grana (`/dashboard`, `/appointments?status=pending`,
/// `/employees`). Ostaju živi linkovi u bookmarkima, mailovima i notifikacijama, pa se
/// prepisuju, a ne puštaju u „Stranica ne postoji".
String? staraAdresa(Uri uri) {
  const proste = {
    '/dashboard': '/today',
    '/clients': '/more/clients',
    '/services': '/more/services',
    '/employees': '/more/staff',
    '/working-hours': '/more/hours',
    '/settings': '/more/settings',
    '/profile': '/more/profile',
  };
  if (proste[uri.path] case final nova?) return nova;

  final segmenti = uri.pathSegments;
  if (segmenti.isEmpty || segmenti.first != 'appointments') return null;
  if (segmenti.length == 1) {
    // Lista na čekanju je sada tab Zahtjevi; svaka druga lista je „Svi termini" u Još.
    final status = uri.queryParameters[kStatusUpit];
    if (status == AppointmentStatus.pending.wireName) {
      return AdminRoute.requests.path;
    }
    return Uri(
      path: AdminRoute.appointments.path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    ).toString();
  }
  // `/appointments/new` je i dalje forma; `/appointments/:id` je detalj, a stari linkovi
  // na detalj dolaze iz notifikacija o zahtjevima.
  if (segmenti.length == 2 && segmenti[1] != 'new') {
    return '${AdminRoute.requests.path}/${segmenti[1]}';
  }
  return null;
}

/// Putanja detalja termina **u grani u kojoj je korisnik** — [trenutna] je njegova adresa.
///
/// Detalj otvoren iz Kalendara ostaje u Kalendaru, pa „nazad" i promjena taba vraćaju
/// tačno tamo. Van poznate grane ide u Zahtjeve.
String putanjaTermina(String trenutna, String id) {
  final segmenti = Uri.parse(trenutna).pathSegments;
  final grana = segmenti.isEmpty ? '' : segmenti.first;
  return switch (grana) {
    'today' => '${AdminRoute.dashboard.path}/appointment/$id',
    'calendar' => '${AdminRoute.calendar.path}/appointment/$id',
    'more' => '${AdminRoute.appointments.path}/$id',
    _ => '${AdminRoute.requests.path}/$id',
  };
}

/// Otvara detalj termina u trenutnoj grani, sa „nazad" na ekran odakle je otvoren.
void otvoriDetaljTermina(BuildContext context, String id) =>
    context.push(putanjaTermina(GoRouterState.of(context).uri.path, id));

/// Rute koje radnik smije otvoriti — njegov dan, kalendar i termini (task 47).
///
/// **Lista dozvoljenih, ne zabranjenih:** modul koji se tek doda ostaje radniku zatvoren
/// dok ga neko svjesno ne upiše ovdje. `/appointments/new` i `/calendar/block` nisu tu jer
/// ručno zakazivanje i blokade traže `is_admin` u bazi.
const kRuteRadnika = {
  AdminRoute.dashboard,
  AdminRoute.dashboardAppointment,
  AdminRoute.calendar,
  AdminRoute.calendarAppointment,
  AdminRoute.requests,
  AdminRoute.requestDetails,
  AdminRoute.appointments,
  AdminRoute.appointmentDetails,
  // „Još" je radniku na telefonu jedini ulaz u odjavu i profil.
  AdminRoute.more,
  // Profil je nalog osobe, ne salona — radnik mijenja svoju sliku i lozinku (task 61).
  AdminRoute.profile,
};

/// Da li [putanja] vodi na neku od [kRuteRadnika].
///
/// `/appointments/new` se provjerava izričito jer ga `/appointments/:id` inače uhvati kao
/// termin sa `id`-em „new".
bool dozvoljenaRadniku(String putanja) {
  if (putanja == AdminRoute.appointmentNew.path) return false;
  final segmenti = Uri.parse(putanja).pathSegments;
  for (final ruta in kRuteRadnika) {
    final uzorak = Uri.parse(ruta.path).pathSegments;
    if (uzorak.length != segmenti.length) continue;
    var poklapa = true;
    for (var i = 0; i < uzorak.length; i++) {
      if (!uzorak[i].startsWith(':') && uzorak[i] != segmenti[i]) {
        poklapa = false;
        break;
      }
    }
    if (poklapa) return true;
  }
  return false;
}

/// Premoscuje Riverpod provider i `Listenable` koji `go_router` ocekuje.
class _ProviderSlusac<T> extends ChangeNotifier {
  _ProviderSlusac(Ref ref, ProviderListenable<T> provider) {
    ref.listen<T>(provider, (_, _) => notifyListeners());
  }
}

/// Sve rute admin app-e.
///
/// Putanja nosi granu: `/today`, `/calendar`, `/requests` i `/more` su korijeni četiri
/// taba, a sve ispod njih se otvara u toj grani. Jedini izuzetak je forma
/// `/appointments/new`, koja ide preko cijelog ekrana na root navigatoru.
enum AdminRoute {
  login('/login', 'Prijava'),

  /// „Imam poziv" (task 45) — javna kao i prijava: radnik još nema nalog.
  pozivnica('/pozivnica', 'Poziv'),
  dashboard('/today', 'Danas'),
  dashboardAppointment('/today/appointment/:id', 'Detalji termina'),
  calendar('/calendar', 'Kalendar'),
  calendarAppointment('/calendar/appointment/:id', 'Detalji termina'),
  calendarBlock('/calendar/block', 'Blokiraj vrijeme'),
  requests('/requests', 'Zahtjevi'),
  requestDetails('/requests/:id', 'Detalji termina'),

  /// `3t` — ulaz u module koje donja navigacija ne nosi kao ćeliju.
  ///
  /// Na desktopu ti moduli stoje u sidebaru, pa se do ovog ekrana ne dolazi iz
  /// navigacije — ruta ostaje ispravna ako je neko otvori direktno.
  more('/more', 'Još'),

  /// „Svi termini" — puna lista sa filterom; Zahtjevi su zaseban tab.
  appointments('/more/appointments', 'Termini'),
  appointmentDetails('/more/appointments/:id', 'Detalji termina'),
  clients('/more/clients', 'Klijenti'),
  services('/more/services', 'Usluge'),
  employees('/more/staff', 'Radnici'),
  workingHours('/more/hours', 'Radno vrijeme'),
  settings('/more/settings', 'Postavke'),

  /// Moj profil (task 61) — nalog osobe; ulaz iz menija u sidebaru i iz „Još".
  profile('/more/profile', 'Moj profil'),

  /// Forma preko cijelog ekrana, van grana.
  appointmentNew('/appointments/new', 'Dodaj termin');

  const AdminRoute(this.path, this.title);

  final String path;
  final String title;
}
