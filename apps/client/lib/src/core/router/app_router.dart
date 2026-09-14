import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointments_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/booking/booking_success_screen.dart';
import '../../features/booking/details_step_screen.dart';
import '../../features/booking/employee_step_screen.dart';
import '../../features/booking/service_step_screen.dart';
import '../../features/booking/slot_step_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/account/settings_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/placeholder/placeholder_screen.dart';
import '../../features/services/services_screen.dart';
import 'client_shell.dart';

/// Rute klijentske app-e, po `docs/01-mvp-spec.md` §12.
///
/// `go_router`, a ne `Navigator.push`, jer web build mora imati **pravi URL po ekranu**:
/// `/book/slot` se mora moći podijeliti, bookmarkovati i otvoriti nazad. Kad prvi ekran ode
/// kroz imperativni `Navigator`, web verzija ostane bez URL-a i to se otkrije kasno — kad
/// već postoji petnaest ekrana napisanih po tom uzoru.
///
/// ## Dva sprata, i to je cijela struktura
///
/// Od taska 18 stablo se dijeli na **tab-level ekrane i sve ostalo**:
///
/// - `StatefulShellRoute` nosi pet grana iz `prototype/ui/SPEC.md` §Bottom tab bar —
///   Usluge, Termini, Početna, Obavijesti, Postavke. Svaka grana ima svoj `Navigator`,
///   pa tab pamti gdje je korisnik stao.
/// - Sve izvan njega (booking flow, prijava, moj račun) je **pushed ekran bez tab bara**,
///   sa back headerom. Tako traži handoff: iz rezervacije se ne odlazi u drugi tab.
///
/// Podjela je namjerno u putanjama, ne u `if`-u unutar ekrana: ekran koji sam odlučuje
/// hoće li nacrtati tab bar je ekran koji će jednom odlučiti pogrešno.
///
/// **Nema `redirect` guarda ni na jednoj ruti.** `docs/06 §1.1`: cijeli katalog i izbor
/// termina su javni, a prijava se traži tek na kraju flowa — odluka koja se ne otvara.
/// Povratak nakon prijave zato ne ide kroz `redirect` nego kroz `?from=`, koji login ekran
/// čita i na koji vraća korisnika.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // **Bez `initialLocation`.** Na webu `initialLocation` nadjačava URL iz adresne trake,
    // pa `salon.ba/book/slot` otvori početnu — deep link i dijeljena veza tiho ne rade, a
    // URL u traci i dalje piše `/book/slot`, što izgleda kao da sve valja. `GoRouter` bez
    // njega uzme trenutnu platformsku rutu, koja je na mobilnom ionako `/`.
    routes: [
      StatefulShellRoute.indexedStack(
        // `indexedStack`, ne `Navigator` po grani sa rušenjem stanja: pet tabova ostaju
        // živi, pa skrol pozicija Početne preživi odlazak na Termine i nazad.
        builder: (context, state, shell) => ClientShell(shell: shell),
        branches: [
          // Redoslijed grana **je** redoslijed ćelija u traci: Početna je treća, tj. u
          // sredini, kako `SPEC.md` izričito traži.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientRoute.services.path,
                name: ClientRoute.services.name,
                builder: (context, state) => const ServicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientRoute.appointments.path,
                name: ClientRoute.appointments.name,
                builder: (context, state) => const AppointmentsScreen(),
                routes: [
                  // Podruta grane, ne zasebna ruta: detalj termina pripada tabu
                  // Termini i mora zadržati traku (`SPEC.md` 5h).
                  GoRoute(
                    path: _relative(
                      ClientRoute.appointmentDetails,
                      ClientRoute.appointments,
                    ),
                    name: ClientRoute.appointmentDetails.name,
                    builder: (context, state) =>
                        _placeholder(ClientRoute.appointmentDetails, state),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientRoute.home.path,
                name: ClientRoute.home.name,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  // `SPEC.md` 5b: "O nama" ima traku sa **Početna aktivna** — to je
                  // pod-ekran Početne, ne šesti tab.
                  GoRoute(
                    path: _relative(ClientRoute.about, ClientRoute.home),
                    name: ClientRoute.about.name,
                    builder: (context, state) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: _relative(ClientRoute.team, ClientRoute.home),
                    name: ClientRoute.team.name,
                    builder: (context, state) =>
                        _placeholder(ClientRoute.team, state),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientRoute.notifications.path,
                name: ClientRoute.notifications.name,
                builder: (context, state) =>
                    _placeholder(ClientRoute.notifications, state),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientRoute.settings.path,
                name: ClientRoute.settings.name,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- Izvan shella: ekrani bez tab bara ---

      // `?serviceId=` dolazi sa home ekrana (task 10). Bez čitanja ovdje preselekcija
      // usluge tiho ne radi — korisnik bira istu uslugu dvaput, a ekran pri tome
      // izgleda ispravno.
      GoRoute(
        path: ClientRoute.bookService.path,
        name: ClientRoute.bookService.name,
        builder: (context, state) => ServiceStepScreen(
          preselectedServiceId: state.uri.queryParameters['serviceId'],
        ),
      ),
      GoRoute(
        path: ClientRoute.bookEmployee.path,
        name: ClientRoute.bookEmployee.name,
        builder: (context, state) => const EmployeeStepScreen(),
      ),
      GoRoute(
        path: ClientRoute.bookSlot.path,
        name: ClientRoute.bookSlot.name,
        builder: (context, state) => const SlotStepScreen(),
      ),
      GoRoute(
        path: ClientRoute.bookDetails.path,
        name: ClientRoute.bookDetails.name,
        builder: (context, state) => const DetailsStepScreen(),
      ),
      GoRoute(
        path: ClientRoute.bookSuccess.path,
        name: ClientRoute.bookSuccess.name,
        builder: (context, state) => const BookingSuccessScreen(),
      ),
      // `?from=` nosi rutu povratka nakon prijave. Ekran je provjerava naspram
      // `ClientRoute` liste — na webu je to vrijednost iz adresne trake, pa
      // neprovjerena bi pretvorila prijavu u preusmjerenje na tuđi sajt.
      GoRoute(
        path: ClientRoute.login.path,
        name: ClientRoute.login.name,
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: ClientRoute.account.path,
        name: ClientRoute.account.name,
        builder: (context, state) => const AccountScreen(),
      ),
      // Ekrane pravi task 21; rute su ovdje da redovi Postavki imaju gdje voditi.
      GoRoute(
        path: ClientRoute.aboutApp.path,
        name: ClientRoute.aboutApp.name,
        builder: (context, state) => _placeholder(ClientRoute.aboutApp, state),
      ),
      GoRoute(
        path: ClientRoute.terms.path,
        name: ClientRoute.terms.name,
        builder: (context, state) => _placeholder(ClientRoute.terms, state),
      ),
    ],
    // Bez ovoga nepoznat URL na webu daje sivi ekran sa stack traceom.
    errorBuilder: (context, state) =>
        PlaceholderScreen(title: 'Stranica ne postoji', path: state.uri.path),
  );
});

PlaceholderScreen _placeholder(ClientRoute route, GoRouterState state) =>
    PlaceholderScreen(title: route.title, path: state.uri.path);

/// Putanja podrute relativno na roditelja — `go_router` traži da dijete nema vodeću `/`.
///
/// Računa se, a ne piše drugi put: `'/appointments/:id'` prepisan kao `':id'` je isti
/// podatak na dva mjesta, i prvi put kad se roditelj preimenuje ostane samo jedan tačan.
String _relative(ClientRoute child, ClientRoute parent) {
  final prefiks = parent.path.endsWith('/') ? parent.path : '${parent.path}/';
  assert(
    child.path.startsWith(prefiks),
    '${child.path} nije podruta od ${parent.path}',
  );
  return child.path.substring(prefiks.length);
}

/// Sve rute klijentske app-e na jednom mjestu.
///
/// Enum, a ne slobodni stringovi: `context.go('/book/slots')` sa greškom u kucanju je
/// runtime greška koju kompajler ne vidi, a `ClientRoute.bookSlot.path` je ne dopušta.
enum ClientRoute {
  home('/', 'Početna'),
  services('/services', 'Usluge'),
  bookService('/book/service', 'Odabir usluge'),
  bookEmployee('/book/employee', 'Odabir radnika'),
  bookSlot('/book/slot', 'Odabir termina'),
  bookDetails('/book/details', 'Podaci'),
  bookSuccess('/book/success', 'Potvrda'),
  login('/auth/login', 'Prijava'),
  account('/account', 'Moj račun'),
  appointments('/appointments', 'Moji termini'),
  appointmentDetails('/appointments/:id', 'Detalji termina'),
  team('/team', 'Naš tim'),
  about('/about', 'O nama'),

  /// Ćelija trake koja nema ekran do taska 21. Ruta postoji prije ekrana namjerno —
  /// traka sa pet ćelija od kojih dvije nemaju gdje voditi je traka koja pada.
  notifications('/notifications', 'Obavijesti'),

  /// Širi ekran od [account]: profil, notifikacije, jezik, odjava (`SPEC.md` 5k).
  /// **Ekran pravi task 17, ne 21** — raniji komentar je tvrdio suprotno, a DoD taska 21
  /// nabraja samo [notifications], [aboutApp] i [terms]. Dok 5k nije postojao, [account]
  /// nije imao ulaz iz aplikacije, pa ni brisanje naloga nije bilo dostupno.
  settings('/settings', 'Postavke'),

  /// Redovi Postavki koje ekranom pokriva task 21. Rute postoje prije ekrana namjerno,
  /// isto kao [notifications]: chevron koji ne vodi nigdje je gori od placeholdera.
  aboutApp('/about-app', 'O aplikaciji'),
  terms('/terms', 'Pravila korištenja');

  const ClientRoute(this.path, this.title);

  final String path;

  /// Naslov placeholdera. Pravi ekrani uzimaju tekst iz `vertical.terms` ili `.arb`-a —
  /// ovo su imena ruta za razvoj, ne UI copy.
  final String title;
}
