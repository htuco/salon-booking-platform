import 'package:core_api/core_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointments_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/placeholder/admin_placeholder_screen.dart';

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
      final stanje = ref.watch(currentStaffProvider);
      if (stanje.isLoading) return null;

      final clan = stanje.valueOrNull;
      final naLoginu = putanja == AdminRoute.login.path;

      // Prijavljen, ali nije osoblje nijednog salona: ostaje na loginu, koji mu objasni
      // zasto. Puštanje dalje bi dalo prazne ekrane bez ijednog objasnjenja.
      if (clan == null || !clan.isSalonAdmin) {
        return naLoginu ? null : AdminRoute.login.path;
      }

      return naLoginu ? AdminRoute.dashboard.path : null;
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
        path: AdminRoute.dashboard.path,
        name: AdminRoute.dashboard.name,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AdminRoute.appointments.path,
        name: AdminRoute.appointments.name,
        builder: (context, state) => const AdminAppointmentsScreen(),
      ),
      // Rute koje jos nemaju tijelo. Ostaju kao placeholderi da ulaz postoji kad task 24 i
      // Sprint 3 dodju do njih; donja navigacija ih namjerno **ne** nudi.
      for (final route in AdminRoute.values)
        if (!_napisane.contains(route))
          GoRoute(
            path: route.path,
            name: route.name,
            builder: (context, state) => AdminPlaceholderScreen(
              title: route.title,
              path: state.uri.path,
            ),
          ),
    ],
    errorBuilder: (context, state) => AdminPlaceholderScreen(
      title: 'Stranica ne postoji',
      path: state.uri.path,
    ),
  );
});

/// Rute koje su dobile pravo tijelo u tasku 23.
const _napisane = {
  AdminRoute.login,
  AdminRoute.dashboard,
  AdminRoute.appointments,
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
  dashboard('/dashboard', 'Dashboard'),
  appointments('/appointments', 'Termini'),
  appointmentDetails('/appointments/:id', 'Detalji termina'),
  appointmentNew('/appointments/new', 'Dodaj termin'),
  calendar('/calendar', 'Kalendar'),
  calendarBlock('/calendar/block', 'Blokiraj vrijeme'),
  services('/services', 'Usluge'),
  employees('/employees', 'Radnici'),
  workingHours('/working-hours', 'Radno vrijeme'),
  settings('/settings', 'Postavke');

  const AdminRoute(this.path, this.title);

  final String path;
  final String title;
}
