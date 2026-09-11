import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/placeholder/placeholder_screen.dart';

/// Rute klijentske app-e, po `docs/01-mvp-spec.md` §12.
///
/// `go_router`, a ne `Navigator.push`, jer web build mora imati **pravi URL po ekranu**:
/// `/book/slot` se mora moći podijeliti, bookmarkovati i otvoriti nazad. Kad prvi ekran ode
/// kroz imperativni `Navigator`, web verzija ostane bez URL-a i to se otkrije kasno — kad
/// već postoji petnaest ekrana napisanih po tom uzoru.
///
/// Od taska 10 `/` ima pravo tijelo (`HomeScreen`); ostale rute su i dalje placeholderi
/// dok ih task 11 ne napiše. Ruta koja postoji i ima URL je ono što je task 07 dokazao.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // **Bez `initialLocation`.** Na webu `initialLocation` nadjačava URL iz adresne trake,
    // pa `salon.ba/book/slot` otvori početnu — deep link i dijeljena veza tiho ne rade, a
    // URL u traci i dalje piše `/book/slot`, što izgleda kao da sve valja. `GoRouter` bez
    // njega uzme trenutnu platformsku rutu, koja je na mobilnom ionako `/`.
    routes: [
      for (final route in ClientRoute.values)
        GoRoute(
          path: route.path,
          name: route.name,
          builder: (context, state) => switch (route) {
            ClientRoute.home => const HomeScreen(),
            _ => PlaceholderScreen(title: route.title, path: state.uri.path),
          },
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
