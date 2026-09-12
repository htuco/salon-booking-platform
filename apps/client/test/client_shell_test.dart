import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Donja navigacija u stvarnom stablu aplikacije — `prototype/ui/SPEC.md` §Bottom tab bar.
///
/// `core_ui/test/bottom_nav_bar_test.dart` dokazuje kako traka **izgleda**; ovdje se
/// dokazuje šta ona **radi**: koji ekrani je imaju, koji je nemaju, i da tab pamti gdje je
/// korisnik stao.
void main() {
  group('gdje traka postoji, a gdje ne', () {
    for (final ruta in [
      ClientRoute.home,
      ClientRoute.services,
      ClientRoute.appointments,
      ClientRoute.notifications,
      ClientRoute.settings,
    ]) {
      testWidgets('${ruta.path} je tab-level ekran i ima traku', (
        tester,
      ) async {
        final container = _container();
        await _podigni(tester, container, na: ruta.path);

        expect(find.byType(AppBottomNav), findsOneWidget);
      });
    }

    for (final ruta in [
      ClientRoute.bookService,
      ClientRoute.bookSlot,
      ClientRoute.login,
      ClientRoute.account,
    ]) {
      testWidgets('${ruta.path} je pushed ekran i nema traku', (tester) async {
        // Handoff: pod-ekrani i cijeli booking flow nemaju traku. Da je ima, korisnik
        // bi usred rezervacije mogao odlutati u drugi tab i izgubiti izbor.
        final container = _container();
        await _podigni(tester, container, na: ruta.path);

        expect(find.byType(AppBottomNav), findsNothing);
      });
    }

    testWidgets('pod-ekran Početne ("O nama") zadržava traku', (tester) async {
      // `SPEC.md` 5b: "tab bar, Početna active". Zato je `/about` podruta grane, a ne
      // zasebna ruta van shella.
      final container = _container();
      await _podigni(tester, container, na: ClientRoute.about.path);

      expect(find.byType(AppBottomNav), findsOneWidget);
    });
  });

  group('redoslijed i aktivna ćelija', () {
    testWidgets('Početna je treća od pet, i aktivna na "/"', (tester) async {
      final container = _container();
      await _podigni(tester, container, na: ClientRoute.home.path);

      final traka = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(traka.items.length, 5);
      expect(traka.items[2].label, 'Početna');
      expect(
        traka.currentIndex,
        2,
        reason: 'Pocetna je namjerno u sredini (`SPEC.md`)',
      );
    });

    testWidgets('deep link u granu odmah označi tu ćeliju', (tester) async {
      // Regresija: traka koja racuna aktivnu celiju iz vlastitog stanja, a ne iz
      // rutiranja, na deep linku pokaze Pocetnu dok je ekran Termini.
      final container = _container();
      await _podigni(tester, container, na: ClientRoute.appointments.path);

      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        1,
      );
    });
  });

  group('ponašanje tabova', () {
    testWidgets('tap na ćeliju mijenja i ekran i URL', (tester) async {
      final container = _container();
      await _podigni(tester, container, na: ClientRoute.home.path);

      await tester.tap(find.text('Termini'));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.appointments.path,
      );
    });

    testWidgets('ponovni tap na aktivnu ćeliju vraća tab na korijen', (
      tester,
    ) async {
      // `SPEC.md` to trazi izricito. Bez toga korisnik koji je zalutao u pod-ekran nema
      // nacina da se vrati osim back dugmetom, a na Pocetnoj to znaci izlazak iz app-e.
      final container = _container();
      await _podigni(tester, container, na: '/appointments/abc-123');

      expect(
        container.read(appRouterProvider).state.uri.path,
        '/appointments/abc-123',
      );

      await tester.tap(find.text('Termini'));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.appointments.path,
      );
    });

    testWidgets('tab pamti gdje je korisnik stao', (tester) async {
      // Ovo je cijeli razlog za `StatefulShellRoute` umjesto obicnog `ShellRoute`-a:
      // svaka grana ima svoj `Navigator`, pa odlazak na Pocetnu ne brise istoriju
      // taba Termini.
      final container = _container();
      await _podigni(tester, container, na: '/appointments/abc-123');

      await tester.tap(find.text('Početna'));
      await tester.pump();
      await tester.pump();
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.home.path,
      );

      await tester.tap(find.text('Termini'));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        '/appointments/abc-123',
        reason: 'grana mora zadrzati svoj stack preko prelaska na drugi tab',
      );
    });
  });
}

Future<void> _podigni(
  WidgetTester tester,
  ProviderContainer container, {
  required String na,
}) async {
  // Ruta se postavlja kao **platformska**, ne kroz `initialLocation`: tako se podize i
  // pravi deep link, i tako je jedino vidljivo da shell bira granu iz URL-a.
  tester.binding.platformDispatcher.defaultRouteNameTestValue = na;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  // `pump`, ne `pumpAndSettle`: Pocetna ima skeleton koji pulsira u nedogled.
  await tester.pump();
  await tester.pump();
}

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(
        const AppEnv(
          salonId: _salonId,
          supabaseUrl: '',
          supabaseAnonKey: '',
          apiUrl: '',
        ),
      ),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const <Service>[]),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      salonGalleryProvider.overrideWith((ref) async => const <String>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      isSignedInProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
