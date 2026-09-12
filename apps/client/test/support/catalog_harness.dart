import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Podizanje koraka 1 i 2 sa zadanim katalogom.
///
/// Izdvojeno iz `booking_flow_screens_test.dart` jer ga trebaju dva fajla: tamo se mjeri
/// **tok**, ovdje **šta katalog nosi na ekran** (task 22). Kopija harnessa u drugom fajlu
/// bi se razišla pri prvoj izmjeni providera, i to tiho.
const salonId = '550e8400-e29b-41d4-a716-446655440000';

const _env = AppEnv(
  salonId: salonId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

const _salon = Salon(
  id: salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

const _danas = LocalDate(2026, 9, 14);

class _MockBooking extends Mock implements BookingRepository {}

Future<ProviderContainer> pumpKorak1(
  WidgetTester tester, {
  required List<Service> usluge,
}) => _pump(tester, ruta: ClientRoute.bookService.path, usluge: usluge);

Future<ProviderContainer> pumpKorak2(
  WidgetTester tester, {
  required List<Employee> radnici,
}) => _pump(
  tester,
  ruta: ClientRoute.bookEmployee.path,
  radnici: radnici,
  // Korak 2 ima guard na prethodni korak: bez izabrane usluge prikaže prazno stanje
  // umjesto liste radnika, i test bi mjerio guard umjesto onoga što tvrdi.
  pocetniFlow: (n) => n.chooseService('s1'),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required String ruta,
  List<Service> usluge = const [
    Service(
      id: 's1',
      salonId: salonId,
      name: 'Šišanje',
      price: 15,
      durationMinutes: 30,
    ),
  ],
  List<Employee> radnici = const [],
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
      currentSalonIdProvider.overrideWithValue(salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => usluge),
      employeesProvider.overrideWith((ref) async => radnici),
      // Prazna lista veza znači "svaki radnik radi svaku uslugu" — presjek se tada ne
      // sužava i korak 2 prikaže sve koje mu je test dao.
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      bookingRepositoryProvider.overrideWithValue(_MockBooking()),
      bookingTodayProvider.overrideWithValue(_danas),
    ],
  );

  final pretplata = container.listen(bookingFlowProvider, (_, _) {});
  addTearDown(pretplata.close);

  if (pocetniFlow != null) {
    pocetniFlow(container.read(bookingFlowProvider.notifier));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  return container;
}
