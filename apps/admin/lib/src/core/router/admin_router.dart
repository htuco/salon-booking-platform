import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    redirect: (context, state) =>
        state.uri.path == '/' ? AdminRoute.login.path : null,
    routes: [
      for (final route in AdminRoute.values)
        GoRoute(
          path: route.path,
          name: route.name,
          builder: (context, state) =>
              AdminPlaceholderScreen(title: route.title, path: state.uri.path),
        ),
    ],
    errorBuilder: (context, state) => AdminPlaceholderScreen(
      title: 'Stranica ne postoji',
      path: state.uri.path,
    ),
  );
});

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
