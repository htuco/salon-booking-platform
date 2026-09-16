import 'package:client/main.dart';
import 'package:client/src/core/auth_config_provider.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/auth/login_screen.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:client/src/features/booking/booking_identity.dart';
import 'package:client/src/features/booking/details_step_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

/// Login na kraju booking flowa. Mock je samo mrežna granica; ekran, kontroler, router
/// i booking state su pravi.
void main() {
  group('email i lozinka', () {
    testWidgets('prijava vraća korisnika u sačuvani booking flow', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(
        tester,
        auth: auth,
        ruta: ClientRoute.bookDetails.path,
        pocetniFlow: (n) => n
          ..chooseService(_usluga.id)
          ..chooseEmployee(_radnik.id)
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      expect(find.text('Čuvamo vam'), findsOneWidget);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(auth.brojPrijava, 1);
      expect(auth.zadnjiEmail, 'gost@primjer.ba');
      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.textContaining('Šišanje'), findsWidgets);
      expect(find.textContaining('Amar'), findsWidgets);
      expect(find.text('Pošalji zahtjev'), findsOneWidget);

      container.dispose();
    });

    testWidgets('registracija traži ponovljenu lozinku i vraća sesiju', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nemate račun? Kreirajte ga'));
      await tester.pumpAndSettle();

      expect(find.text('Kreirajte račun'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('login-password-repeat')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'novi@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password-repeat')),
        'Sigurna123',
      );
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(auth.brojRegistracija, 1);
      expect(auth.zadnjiEmail, 'novi@primjer.ba');
      expect(find.byType(DetailsStepScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('neispravan email i slaba lozinka ne zovu Supabase', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'kratka',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(auth.brojPrijava, 0);
      expect(find.text('Unesite ispravnu email adresu.'), findsOneWidget);
      expect(find.textContaining('najmanje 8 znakova'), findsOneWidget);

      container.dispose();
    });

    testWidgets('registracija odbija različite lozinke prije mreže', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nemate račun? Kreirajte ga'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'novi@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password-repeat')),
        'Druga456',
      );
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(auth.brojRegistracija, 0);
      expect(find.text('Lozinke se ne podudaraju.'), findsOneWidget);
      container.dispose();
    });

    testWidgets('pogrešni podaci daju generičku trajnu poruku', (tester) async {
      final auth = FakeAuthRepository(
        prijavaGreska: const AuthRejectedError('invalid_credentials'),
      );
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Pogresna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(find.text('Pogrešan email ili lozinka.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      container.dispose();
    });

    testWidgets('nema telefona, OTP-a ni lažnog recovery toka', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Telefon'), findsNothing);
      expect(find.textContaining('kod'), findsNothing);
      expect(find.textContaining('Zaboravili'), findsNothing);
      expect(find.textContaining('ne šalje potvrdu emaila'), findsOneWidget);
      container.dispose();
    });
  });

  group('navigacija i provideri', () {
    testWidgets('nazad sa emaila vodi na providere pa u booking', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsStepScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('konfigurirana lista ima Apple, Google i Email', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      expect(find.text('Nastavi sa Apple'), findsOneWidget);
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      expect(find.text('Nastavi sa emailom'), findsOneWidget);
      expect(find.text('Nastavi sa Facebookom'), findsNothing);
      container.dispose();
    });

    testWidgets('strani from se ignoriše i vodi na početnu', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(
        tester,
        auth: auth,
        ruta: '${ClientRoute.login.path}?from=https://tudje.example',
      );

      expect(find.text('Čuvamo vam'), findsNothing);
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      container.dispose();
    });
  });
}

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _danas = LocalDate(2026, 9, 14);

final _loginIzFlowa = Uri(
  path: ClientRoute.login.path,
  queryParameters: {'from': ClientRoute.bookDetails.path},
).toString();

const _env = AppEnv(
  salonId: _salonId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

const _usluga = Service(
  id: '10000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Šišanje',
  price: 15,
  durationMinutes: 30,
);

const _radnik = Employee(
  id: '20000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Amar',
  role: 'Barber',
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required String ruta,
  void Function(BookingFlowNotifier notifier)? pocetniFlow,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  tester.view
    ..physicalSize = const Size(1200, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const [_usluga]),
      employeesProvider.overrideWith((ref) async => const [_radnik]),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      authRepositoryProvider.overrideWithValue(auth),
      visibleAuthProvidersProvider.overrideWithValue(const [
        AuthProvider.apple,
        AuthProvider.google,
        AuthProvider.email,
      ]),
      bookingCustomerIdProvider.overrideWith((ref) async => null),
      bookingTodayProvider.overrideWithValue(_danas),
    ],
  );

  final pretplata = container.listen(bookingFlowProvider, (_, _) {});
  pocetniFlow?.call(container.read(bookingFlowProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  pretplata.close();
  return container;
}
