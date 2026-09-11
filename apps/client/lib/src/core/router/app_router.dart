import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/placeholder/placeholder_screen.dart';

/// Rute klijentske app-e, po `docs/01-mvp-spec.md` §12.
///
/// `go_router`, a ne `Navigator.push`, jer web build mora imati **pravi URL po ekranu**:
/// `/book/slot` se mora moći podijeliti, bookmarkovati i otvoriti nazad. Kad prvi ekran ode
/// kroz imperativni `Navigator`, web verzija ostane bez URL-a i to se otkrije kasno — kad
/// već postoji petnaest ekrana napisanih po tom uzoru.
///
/// Tijela su namjerno placeholderi: ovaj task postavlja kičmu, a sadržaj pišu taskovi 10 i 11.
/// Ruta koja postoji i ima URL je ono što se ovdje dokazuje.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ClientRoute.home.path,
    routes: [
      for (final route in ClientRoute.values)
        GoRoute(
          path: route.path,
          name: route.name,
          builder: (context, state) =>
              PlaceholderScreen(title: route.title, path: state.uri.path),
        ),
    ],
    // Bez ovoga nepoznat URL na webu daje sivi ekran sa stack traceom.
    errorBuilder: (context, state) =>
        PlaceholderScreen(title: 'Stranica ne postoji', path: state.uri.path),
  );
});

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
  about('/about', 'O nama');

  const ClientRoute(this.path, this.title);

  final String path;

  /// Naslov placeholdera. Pravi ekrani uzimaju tekst iz `vertical.terms` ili `.arb`-a —
  /// ovo su imena ruta za razvoj, ne UI copy.
  final String title;
}
