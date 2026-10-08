import 'dart:async';

import 'package:admin/main.dart';
import 'package:admin/src/core/env/app_env.dart';
import 'package:admin/src/core/router/admin_router.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/dashboard/dashboard_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _env = AdminEnv(supabaseUrl: '', supabaseAnonKey: '');

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Vlasnik Barber Studio Vitez',
  email: 'admin@barberstudiovitez.test',
  role: 'salon_admin',
  salonId: '550e8400-e29b-41d4-a716-446655440000',
);

/// Kontejner sa zadatim stanjem prijave.
///
/// [clan] `null` znaci neprijavljen; `loading: true` glumi prvo citanje sesije, koje
/// **ne smije** biti protumaceno kao odjava.
ProviderContainer _container({StaffMember? clan, bool loading = false}) {
  final container = ProviderContainer(
    overrides: [
      // Kalendar inače kuca svake minute i ostavi tajmer poslije testa.
      sadaProvider.overrideWith(
        (ref) => Stream.value(DateTime(2026, 9, 14, 10)),
      ),
      adminEnvProvider.overrideWithValue(_env),
      currentStaffProvider.overrideWith(
        (ref) => loading
            ? const Stream<StaffMember?>.empty()
            : Stream<StaffMember?>.value(clan),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const SalonAdminApp(),
);

void main() {
  setUp(() {
    // Routing/form tests must settle independently of the perpetual lava ticker.
    // Animation behavior is exercised in admin_lava_panel_test.dart.
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('Asinhrona prijava cuva isti router i deep link', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/employees';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final signal = StreamController<StaffMember?>();
    final container = ProviderContainer(
      overrides: [
        adminEnvProvider.overrideWithValue(_env),
        currentStaffProvider.overrideWith((ref) => signal.stream),
      ],
    );
    await tester.pumpWidget(_app(container));
    await tester.pump();
    final router = container.read(adminRouterProvider);
    signal.add(_vlasnik);
    await tester.pumpAndSettle();
    expect(identical(container.read(adminRouterProvider), router), isTrue);
    // Stara adresa iz bookmarka preživi prijavu i završi na novoj.
    expect(router.state.uri.path, '/more/staff');
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(signal.close());
    await tester.pump();
  });
  test('rute prate 01 §12', () {
    // Prepisano iz specifikacije, ne iz enuma — inace test potvrdjuje sam sebe.
    //
    // `/clients` i `/more` su u §12 dopisane u tasku 29, iz admin handoffa: prva nosi
    // prikaze `3e`/`3o`, druga prikaz `3t`. Red ide u tabelu **pa** ovdje — obrnuto bi
    // znacilo da enum vodi specifikaciju.
    const izSpecifikacije = {
      '/login',
      '/pozivnica',
      '/today',
      '/today/appointment/:id',
      '/calendar',
      '/calendar/appointment/:id',
      '/calendar/block',
      '/requests',
      '/requests/:id',
      '/more',
      '/more/appointments',
      '/more/appointments/:id',
      '/more/clients',
      '/more/services',
      '/more/staff',
      '/more/hours',
      '/more/settings',
      '/more/profile',
      '/appointments/new',
    };
    expect(AdminRoute.values.map((r) => r.path).toSet(), izSpecifikacije);
  });

  testWidgets('neprijavljen korisnik zavrsi na /login', (tester) async {
    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/login');
    expect(find.text('Prijavi se'), findsOneWidget);
  });

  testWidgets('deep link na /employees trazi prijavu', (tester) async {
    // Bookmark na admin ekran ne smije proci bez prijave — ranije je ovaj test tvrdio
    // suprotno, jer su sve rute bile placeholderi bez ijedne provjere.
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AdminRoute.employees.path;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/login');
  });

  testWidgets('prijavljen vlasnik ide na /today', (tester) async {
    final container = _container(clan: _vlasnik);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/today');
    // Ekran, ne ime prijavljenog: od taska 30 „Danas" crta datum i raspored, a ime stoji
    // u sidebaru (desktop) odnosno iza dugmeta naloga (telefon). Ovaj test pazi na guard i
    // rutu, pa provjerava da je stigao **taj** ekran.
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets('prijavljen deep link na /employees prolazi', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AdminRoute.employees.path;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    final container = _container(clan: _vlasnik);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Task 33 zamjenjuje placeholder pravim ekranom; deep link ostaje sacuvan.
    expect(container.read(adminRouterProvider).state.uri.path, '/more/staff');
    expect(find.text('Osoblje'), findsWidgets);
  });

  testWidgets('dok se sesija cita, korisnik se ne izbacuje na login', (
    tester,
  ) async {
    // Regresija koja se vidi samo na webu: `isLoading` protumacen kao „nije prijavljen"
    // baci admina na login pri svakom osvjezavanju stranice, pa ga vrati — treptaj koji
    // izgleda kao istekla sesija.
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AdminRoute.dashboard.path;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    final container = _container(loading: true);
    await tester.pumpWidget(_app(container));
    await tester.pump();

    expect(container.read(adminRouterProvider).state.uri.path, '/today');
  });

  testWidgets('korisnik koji nije osoblje ostaje na loginu', (tester) async {
    // Token je ispravan, reda u `public.users` nema. Pustanje dalje bi dalo prazne
    // ekrane bez objasnjenja.
    const klijent = StaffMember(
      id: 'bb000000-0000-4000-8000-000000000001',
      name: 'Obican klijent',
      email: 'klijent@primjer.test',
      role: 'employee',
      salonId: null,
    );

    final container = _container(clan: klijent);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/login');
  });

  // Task 47 — guard pušta radnika, ali samo na njegove rute. Sakriven modul koji se
  // otvara kucanjem adrese nije sakriven.
  group('stare adrese', () {
    for (final (stara, nova) in [
      ('/dashboard', '/today'),
      ('/appointments?status=pending', '/requests'),
      ('/appointments', '/more/appointments'),
      ('/appointments?status=confirmed', '/more/appointments?status=confirmed'),
      ('/appointments/abc-123', '/requests/abc-123'),
      ('/clients', '/more/clients'),
      ('/services', '/more/services'),
      ('/employees', '/more/staff'),
      ('/working-hours', '/more/hours'),
      ('/settings', '/more/settings'),
      ('/profile', '/more/profile'),
    ]) {
      test('$stara → $nova', () {
        expect(staraAdresa(Uri.parse(stara)), nova);
      });
    }

    test('nove adrese i forma se ne diraju', () {
      for (final adresa in ['/today', '/requests/1', '/appointments/new']) {
        expect(staraAdresa(Uri.parse(adresa)), isNull, reason: adresa);
      }
    });
  });

  test('detalj termina se otvara u grani iz koje je pozvan', () {
    expect(putanjaTermina('/today', 'x'), '/today/appointment/x');
    expect(putanjaTermina('/calendar', 'x'), '/calendar/appointment/x');
    expect(putanjaTermina('/requests', 'x'), '/requests/x');
    expect(putanjaTermina('/more/appointments', 'x'), '/more/appointments/x');
  });

  group('radnik', () {
    const radnik = StaffMember(
      id: '22222222-0000-4000-8000-000000000002',
      name: 'Radnik Barber Studio Vitez',
      email: 'radnik@barberstudiovitez.test',
      role: 'employee',
      salonId: '550e8400-e29b-41d4-a716-446655440000',
      employeeId: 'e1',
    );

    for (final (adresa, ocekivano) in [
      ('/login', '/today'),
      ('/today', '/today'),
      ('/calendar', '/calendar'),
      ('/requests', '/requests'),
      ('/more', '/more'),
      ('/more/appointments', '/more/appointments'),
      ('/more/profile', '/more/profile'),
      ('/more/staff', '/today'),
      ('/more/clients', '/today'),
      ('/more/settings', '/today'),
      ('/more/hours', '/today'),
      ('/more/services', '/today'),
      ('/appointments/new', '/today'),
      ('/calendar/block', '/today'),
      // Stare adrese prvo postanu nove, pa ih guard tek onda sudi.
      ('/dashboard', '/today'),
      ('/appointments', '/more/appointments'),
      ('/employees', '/today'),
    ]) {
      testWidgets('$adresa → $ocekivano', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.binding.platformDispatcher.defaultRouteNameTestValue = adresa;
        addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
        );

        final container = _container(clan: radnik);
        await tester.pumpWidget(_app(container));
        await tester.pump();
        await tester.pump();

        expect(container.read(adminRouterProvider).state.uri.path, ocekivano);
        // Ekrani čitaju Supabase kojeg u testu nema; stablo se skida prije kraja testa.
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    test('detalj termina je njegov, `new` nije termin', () {
      expect(dozvoljenaRadniku('/requests/abc-123'), isTrue);
      expect(dozvoljenaRadniku('/today/appointment/abc-123'), isTrue);
      expect(dozvoljenaRadniku('/calendar/appointment/abc-123'), isTrue);
      expect(dozvoljenaRadniku('/more/appointments/abc-123'), isTrue);
      expect(dozvoljenaRadniku('/appointments/new'), isFalse);
    });

    test('vlasnik nije radnik — njega guard ne sužava', () {
      expect(_vlasnik.isEmployee, isFalse);
      expect(_vlasnik.imaPristup, isTrue);
    });
  });
}
