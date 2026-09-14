import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/booking/slot_step_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

const _env = AppEnv(
  salonId: '550e8400-e29b-41d4-a716-446655440000',
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      // Od taska 10 `/` je home ekran koji cita podatke. Ovaj fajl testira rute, ne
      // sadrzaj, pa provideri vracaju prazno — ali **moraju** biti override-ovani,
      // inace repozitorij posegne za `Supabase.instance` kojeg u testu nema.
      currentSalonIdProvider.overrideWithValue(_env.salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const <Service>[]),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      // Od taska 18 `/appointments/:id` je podruta grane, pa se uz detalj gradi i
      // korijen taba (`AppointmentsScreen`). On pita da li je korisnik prijavljen, a
      // taj provider bez override-a posegne za `Supabase.instance` kojeg u testu nema.
      isSignedInProvider.overrideWithValue(false),
      // Task 17: `/settings` i `/account` više nisu placeholderi — čitaju sesiju kroz
      // `authRepositoryProvider`, koji bez override-a posegne za `Supabase.instance`
      // kojeg u testu nema. Ista zamka opisana u `support/fake_auth_repository.dart`.
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const _salon = Salon(
  id: '550e8400-e29b-41d4-a716-446655440000',
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const SalonClientApp(),
);

void main() {
  group('rute iz 01 §12', () {
    test('svaka ruta iz specifikacije postoji u routeru', () {
      // Putanje su prepisane iz `docs/01-mvp-spec.md` §12, ne iz `ClientRoute`-a —
      // inace bi test samo potvrdio da je enum jednak sam sebi.
      //
      // `/gallery` je jedini red iz §12 kojeg ovdje nema: oznacen je kao Later i ekran
      // ga dobija u tasku 20. Kad ga dobije, ide i ovdje.
      //
      // `/about-app` i `/terms` su dodani u §12 u tasku 17. Handoff ih crta (5n, 5o) i DoD
      // taska 21 ih imenuje, ali tabela u specifikaciji ih nije imala — ista rupa kao kod
      // 5k. Rute postoje prije ekrana, da redovi Postavki imaju gdje voditi.
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
        '/notifications',
        '/settings',
        '/about-app',
        '/terms',
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
      // `pump` umjesto `pumpAndSettle`: home ekran na `/` ima skeleton puls koji nikad
      // ne stane, pa bi `pumpAndSettle` istekao i kad je router ispravan.
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.bookSlot.path,
        reason: 'deep link mora preziviti podizanje app-e',
      );
      // Od taska 11 `/book/slot` ima pravo tijelo, pa se vise ne trazi naslov
      // placeholdera. Flow je pri deep linku prazan, pa ekran ispravno prikaze
      // prazno stanje umjesto liste termina za uslugu koja nije izabrana.
      expect(find.byType(SlotStepScreen), findsOneWidget);
    });
  });

  group('navigacija daje pravi URL', () {
    // Ovo je razlog zasto je `go_router` obavezan: web build mora imati URL po ekranu.
    // `Navigator.push` bi prosao widget test jednako dobro, a na webu ostavio jedan
    // jedini URL za cijelu app-u — i to bi se otkrilo tek kad ekrana bude petnaest.
    testWidgets('go na /book/slot mijenja i ekran i putanju', (tester) async {
      final container = _container();
      await tester.pumpWidget(_app(container));
      // `pump` umjesto `pumpAndSettle`: home ekran na `/` ima skeleton puls koji nikad
      // ne stane, pa bi `pumpAndSettle` istekao i kad je router ispravan.
      await tester.pump();
      await tester.pump();

      final router = container.read(appRouterProvider);
      router.go(ClientRoute.bookSlot.path);
      await tester.pumpAndSettle();

      expect(
        router.state.uri.path,
        ClientRoute.bookSlot.path,
        reason: 'URL prati ekran, ne samo widget stablo',
      );
      expect(find.byType(SlotStepScreen), findsOneWidget);
    });

    testWidgets('ruta sa parametrom zadrzava konkretan id u URL-u', (
      tester,
    ) async {
      final container = _container();
      await tester.pumpWidget(_app(container));
      // `pump` umjesto `pumpAndSettle`: home ekran na `/` ima skeleton puls koji nikad
      // ne stane, pa bi `pumpAndSettle` istekao i kad je router ispravan.
      await tester.pump();
      await tester.pump();

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
      // `pump` umjesto `pumpAndSettle`: home ekran na `/` ima skeleton puls koji nikad
      // ne stane, pa bi `pumpAndSettle` istekao i kad je router ispravan.
      await tester.pump();
      await tester.pump();

      container.read(appRouterProvider).go('/ne-postoji');
      await tester.pumpAndSettle();

      expect(find.text('Stranica ne postoji'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
