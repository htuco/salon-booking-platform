import 'dart:async';

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/employees/employees_providers.dart';
import 'package:admin/src/features/employees/employees_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _employee = Employee(
  id: 'e1',
  salonId: 'salon',
  name: 'Amar',
  role: 'Barber',
);
const _inactive = Employee(
  id: 'e2',
  salonId: 'salon',
  name: 'Vedad',
  isActive: false,
);
const _service = Service(
  id: 's1',
  salonId: 'salon',
  name: 'Šišanje',
  price: 15,
  durationMinutes: 30,
);
const _hours = [
  WorkingHour(
    id: 'h1',
    salonId: 'salon',
    dayOfWeek: 1,
    startTime: LocalTime(9, 0),
    endTime: LocalTime(17, 0),
  ),
  WorkingHour(
    id: 'h2',
    salonId: 'salon',
    employeeId: 'e1',
    dayOfWeek: 1,
    startTime: LocalTime(10, 0),
    endTime: LocalTime(16, 0),
  ),
];

class _Actions extends EmployeeActions {
  _Actions(super.ref);
  EmployeeInput? saved;
  bool fail = true;
  bool? active;
  @override
  Future<Employee> save(Employee? employee, EmployeeInput input) async {
    saved = input;
    if (fail) throw const ServerError('Probna greška');
    return _employee;
  }

  @override
  Future<void> setActive(Employee employee, bool value) async {
    active = value;
  }
}

Future<_Actions> _pump(
  WidgetTester tester, {
  Size size = const Size(402, 874),
  List<Employee> employees = const [_employee, _inactive],
  bool linkError = false,
  bool listError = false,
  double scale = 1,
  Future<List<EmployeeService>> Function()? loadLinks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late _Actions actions;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentStaffProvider.overrideWith(
          (ref) => Stream.value(
            const StaffMember(
              id: 'u1',
              name: 'Vlasnik',
              email: 'test@invalid',
              role: 'salon_admin',
              salonId: 'salon',
            ),
          ),
        ),
        adminSalonProvider.overrideWith(
          (ref) async => const Salon(
            id: 'salon',
            name: 'Salon',
            slug: 'salon',
            city: 'Vitez',
          ),
        ),
        pendingCountProvider.overrideWith((ref) async => 0),
        adminEmployeesProvider.overrideWith((ref) async {
          if (listError) throw const ServerError('Greška');
          return employees;
        }),
        adminServicesProvider.overrideWith((ref) async => [_service]),
        adminEmployeeLinksProvider.overrideWith((ref) async {
          if (loadLinks != null) return loadLinks();
          if (linkError) throw const ServerError('Greška');
          return [
            const EmployeeService(
              id: 'l',
              salonId: 'salon',
              employeeId: 'e1',
              serviceId: 's1',
            ),
          ];
        }),
        kalendarRadnoVrijemeProvider.overrideWith((ref) async => _hours),
        employeeActionsProvider.overrideWith((ref) => actions = _Actions(ref)),
      ],
      child: MaterialApp(
        theme: buildAdminTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AdminEmployeesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Actions su lazy; editor ili test ih prvi ucita.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AdminEmployeesScreen)),
  );
  actions = container.read(employeeActionsProvider) as _Actions;
  return actions;
}

void main() {
  testWidgets('Otvaranje tokom refresh-a ne vraca stare veze', (tester) async {
    var first = true;
    final pending = Completer<List<EmployeeService>>();
    await _pump(
      tester,
      loadLinks: () async {
        if (first) {
          return [
            const EmployeeService(
              id: 'l',
              salonId: 'salon',
              employeeId: 'e1',
              serviceId: 's1',
            ),
          ];
        }
        return pending.future;
      },
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminEmployeesScreen)),
    );
    first = false;
    container.invalidate(adminEmployeeLinksProvider);
    await tester.pump();
    await tester.tap(find.text('Amar').first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sačuvaj'))
          .onPressed,
      isNull,
    );
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });
  test('Smjena radnika nadjacava salon, odsutan dan je slobodan', () {
    expect(employeeShift(_hours, 'e1', 1), '10:00–16:00');
    expect(employeeShift(_hours, 'e2', 1), '09:00–17:00');
    expect(employeeShift(_hours, 'e1', 2), 'Slobodno');
  });
  for (final size in [
    const Size(840, 900),
    const Size(1024, 900),
    const Size(1440, 900),
    const Size(402, 874),
    const Size(320, 740),
  ]) {
    testWidgets('Osoblje i neaktivni radnik na $size', (tester) async {
      await _pump(tester, size: size);
      expect(find.text('Osoblje i smjene'), findsOneWidget);
      expect(find.text('Neaktivan'), findsOneWidget);
      expect(find.text('Šišanje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Editor cuva nullable staz, izabrane usluge i unos nakon greske',
    (tester) async {
      final actions = await _pump(tester);
      await tester.tap(find.text('Amar').first);
      await tester.pumpAndSettle();
      expect(find.text('Uredi radnika'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ime'),
        'Amar Novi',
      );
      await tester.ensureVisible(find.text('Sačuvaj'));
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();
      expect(find.text('Probna greška'), findsOneWidget);
      expect(actions.saved!.name, 'Amar Novi');
      expect(actions.saved!.experienceYears, isNull);
      expect(actions.saved!.serviceIds, ['s1']);
      actions.fail = false;
      await tester.tap(find.text('Sačuvaj'));
      await tester.pumpAndSettle();
      expect(find.text('Uredi radnika'), findsNothing);
    },
  );
  testWidgets('Greska veza blokira snimanje umjesto brisanja usluga', (
    tester,
  ) async {
    await _pump(tester, linkError: true);
    await tester.tap(find.text('Amar').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sačuvaj'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('Reaktivacija zahtijeva potvrdu i koristi akciju', (
    tester,
  ) async {
    final actions = await _pump(tester);
    await tester.tap(find.text('Vedad').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ponovo aktiviraj radnika'));
    await tester.tap(find.text('Ponovo aktiviraj radnika'));
    await tester.pumpAndSettle();
    expect(actions.active, isNull);
    await tester.tap(find.text('Potvrdi'));
    await tester.pumpAndSettle();
    expect(actions.active, isTrue);
  });
  testWidgets('Prazno stanje i greska imaju akciju', (tester) async {
    await _pump(tester, employees: []);
    expect(find.text('Dodaj prvog radnika'), findsOneWidget);
    await _pump(tester, listError: true);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });
  testWidgets('Dugo ime i povecan font ne prelijevaju karticu', (tester) async {
    await _pump(
      tester,
      scale: 1.8,
      employees: [
        _employee.copyWith(name: 'Radnik sa veoma dugim imenom i prezimenom'),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
