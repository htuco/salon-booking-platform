import 'package:admin/main.dart';
import 'package:admin/src/core/env/app_env.dart';
import 'package:admin/src/core/router/admin_router.dart';
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
  test('rute prate 01 §12', () {
    // Prepisano iz specifikacije, ne iz enuma — inace test potvrdjuje sam sebe.
    //
    // `/clients` i `/more` su u §12 dopisane u tasku 29, iz admin handoffa: prva nosi
    // prikaze `3e`/`3o`, druga prikaz `3t`. Red ide u tabelu **pa** ovdje — obrnuto bi
    // znacilo da enum vodi specifikaciju.
    const izSpecifikacije = {
      '/login',
      '/dashboard',
      '/appointments',
      '/appointments/:id',
      '/appointments/new',
      '/calendar',
      '/calendar/block',
      '/clients',
      '/services',
      '/employees',
      '/working-hours',
      '/settings',
      '/more',
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

  testWidgets('prijavljen vlasnik ide na /dashboard', (tester) async {
    final container = _container(clan: _vlasnik);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/dashboard');
    expect(find.text(_vlasnik.name), findsOneWidget);
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

    // Ruta jos nema tijelo (Sprint 3), ali ulaz postoji i URL se cuva — inace bi
    // podijeljena veza tiho odvela na dashboard.
    expect(container.read(adminRouterProvider).state.uri.path, '/employees');
    expect(find.text(AdminRoute.employees.title), findsNWidgets(2));
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

    expect(container.read(adminRouterProvider).state.uri.path, '/dashboard');
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
}
