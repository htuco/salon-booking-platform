import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _env = AppEnv(
  salonId: '550e8400-e29b-41d4-a716-446655440000',
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [appEnvProvider.overrideWithValue(_env)],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const SalonClientApp(),
);

void main() {
  group('rute iz 01 §12', () {
    test('svaka ruta iz specifikacije postoji u routeru', () {
      // Putanje su prepisane iz `docs/01-mvp-spec.md` §12, ne iz `ClientRoute`-a —
      // inace bi test samo potvrdio da je enum jednak sam sebi.
      const izSpecifikacije = {
        '/',
        '/services',
        '/book/service',
        '/book/employee',
        '/book/slot',
        '/book/details',
        '/book/success',
        '/auth/login',
        '/account',
        '/appointments',
        '/appointments/:id',
        '/team',
        '/about',
      };

      expect(
        ClientRoute.values.map((r) => r.path).toSet(),
        izSpecifikacije,
        reason: 'router i 01 §12 moraju opisivati isti skup ekrana',
      );
    });

    test('nijedna ruta se ne ponavlja', () {
      final paths = ClientRoute.values.map((r) => r.path).toList();
      expect(paths.toSet().length, paths.length);
    });
  });

  group('deep link', () {
    // Regresija: sa `initialLocation` router na webu otvori pocetnu bez obzira na URL iz
    // adresne trake, pa dijeljena veza na /book/slot vodi na /. U browseru to izgleda
    // ispravno (URL ostaje /book/slot), pa se otkrije tek kad neko posalje link.
    testWidgets('router prati platformsku rutu, ne nametnutu lokaciju', (
      tester,
    ) async {
      // `/book/slot` je ono sto bi na webu doslo iz adresne trake.
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          ClientRoute.bookSlot.path;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );

      final container = _container();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookSlot.path,
        reason: 'deep link mora preziviti podizanje app-e',
      );
      expect(find.text(ClientRoute.bookSlot.title), findsNWidgets(2));
    });
  });

  group('navigacija daje pravi URL', () {
    // Ovo je razlog zasto je `go_router` obavezan: web build mora imati URL po ekranu.
    // `Navigator.push` bi prosao widget test jednako dobro, a na webu ostavio jedan
    // jedini URL za cijelu app-u — i to bi se otkrilo tek kad ekrana bude petnaest.
    testWidgets('go na /book/slot mijenja i ekran i putanju', (tester) async {
      final container = _container();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      router.go(ClientRoute.bookSlot.path);
      await tester.pumpAndSettle();

      expect(
        router.state.uri.path,
        ClientRoute.bookSlot.path,
        reason: 'URL prati ekran, ne samo widget stablo',
      );
      expect(find.text(ClientRoute.bookSlot.title), findsNWidgets(2));
    });

    testWidgets('ruta sa parametrom zadrzava konkretan id u URL-u', (
      tester,
    ) async {
      final container = _container();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      router.go('/appointments/abc-123');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/appointments/abc-123');
      expect(find.text('/appointments/abc-123'), findsOneWidget);
    });

    testWidgets('nepoznat URL ide na errorBuilder, ne u sivi ekran', (
      tester,
    ) async {
      final container = _container();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go('/ne-postoji');
      await tester.pumpAndSettle();

      expect(find.text('Stranica ne postoji'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
