import 'package:admin/main.dart';
import 'package:admin/src/core/env/app_env.dart';
import 'package:admin/src/core/router/admin_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _env = AdminEnv(supabaseUrl: '', supabaseAnonKey: '');

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [adminEnvProvider.overrideWithValue(_env)],
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
    const izSpecifikacije = {
      '/login',
      '/dashboard',
      '/appointments',
      '/appointments/:id',
      '/appointments/new',
      '/calendar',
      '/calendar/block',
      '/services',
      '/employees',
      '/working-hours',
      '/settings',
    };

    expect(AdminRoute.values.map((r) => r.path).toSet(), izSpecifikacije);
  });

  testWidgets('app se podize na /login', (tester) async {
    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/login');
    expect(find.text(AdminRoute.login.title), findsNWidgets(2));
  });

  testWidgets('deep link na /employees prezivljava podizanje app-e', (
    tester,
  ) async {
    // Regresija: sa `initialLocation` bi bookmark na /employees otvorio login, a URL
    // bi i dalje pisao /employees — izgleda ispravno dok neko ne podijeli vezu.
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AdminRoute.employees.path;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(container.read(adminRouterProvider).state.uri.path, '/employees');
  });

  testWidgets('navigacija na /employees mijenja URL i ekran', (tester) async {
    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final router = container.read(adminRouterProvider);
    router.go(AdminRoute.employees.path);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/employees');
    expect(find.text(AdminRoute.employees.title), findsNWidgets(2));
  });
}
