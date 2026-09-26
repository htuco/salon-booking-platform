/// Usluge na dvije širine — `3f`, `3p` i editor `3q`.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/services/services_screen.dart';
import 'package:admin/src/features/services/usluge_dijelovi.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _desktop = Size(1440, 900);
const _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: 'u1',
  name: 'Emir Bešić',
  email: 'emir@test.invalid',
  role: 'salon_admin',
  salonId: _salonId,
);

final _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barber-studio-vitez',
  city: 'Vitez',
);

const _services = [
  Service(
    id: 's1',
    salonId: _salonId,
    name: 'Muško šišanje',
    category: 'Šišanje',
    price: 15,
    durationMinutes: 30,
  ),
  Service(
    id: 's2',
    salonId: _salonId,
    name: 'Brada',
    category: 'Brada',
    price: 12.5,
    durationMinutes: 20,
    isActive: false,
  ),
];

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir'),
  Employee(id: 'e2', salonId: _salonId, name: 'Amar'),
];

// Šišanje rade oba radnika („svi"), bradu samo Amar.
const _veze = [
  EmployeeService(
    id: 'l1',
    salonId: _salonId,
    employeeId: 'e1',
    serviceId: 's1',
  ),
  EmployeeService(
    id: 'l2',
    salonId: _salonId,
    employeeId: 'e2',
    serviceId: 's1',
  ),
  EmployeeService(
    id: 'l3',
    salonId: _salonId,
    employeeId: 'e2',
    serviceId: 's2',
  ),
];

Widget _screen({List<Service> services = _services, Object? error}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentStaffProvider.overrideWith(
          (ref) => Stream<StaffMember?>.value(_vlasnik),
        ),
        adminSalonProvider.overrideWith((ref) async => _salon),
        pendingCountProvider.overrideWith((ref) async => 0),
        adminServicesProvider.overrideWith((ref) async {
          if (error != null) throw error;
          return services;
        }),
        adminEmployeesProvider.overrideWith((ref) async => _radnici),
        adminEmployeeLinksProvider.overrideWith((ref) async => _veze),
      ],
      child: MaterialApp(
        theme: buildAdminTheme(),
        home: const AdminServicesScreen(),
      ),
    );

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

/// Prekidač sa datom semantičkom oznakom.
UslugaPrekidac _prekidac(WidgetTester tester, String oznaka) => tester
    .widgetList<UslugaPrekidac>(find.byType(UslugaPrekidac))
    .firstWhere((p) => p.oznaka == oznaka);

void main() {
  pristupacnostEkrana('Usluge', _screen);

  testWidgets('desktop crta tabelu, radnike, panel i top-bar akciju', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());

    expect(find.text('Cjenovnik'), findsOneWidget);
    for (final kolona in ['USLUGA', 'TRAJANJE', 'CIJENA', 'ONLINE']) {
      expect(find.text(kolona), findsOneWidget);
    }
    expect(find.text('Muško šišanje'), findsWidgets);
    expect(find.text('12.50 KM'), findsOneWidget);
    expect(find.text('svi'), findsOneWidget);
    // „Amar" je i u tabeli (red Brade) i u panelu „Ko radi uslugu".
    expect(find.text('Amar'), findsWidgets);
    // Isključena usluga u tabeli piše zašto je blijeda; stara „Neaktivna" pilula je otišla.
    expect(find.text('isključeno iz online zakazivanja'), findsOneWidget);
    expect(_prekidac(tester, 'Online: Brada').vrijednost, isFalse);
    expect(_prekidac(tester, 'Online: Muško šišanje').vrijednost, isTrue);
    // Verzal u tekstu, original u semantici.
    expect(find.text('+ NOVA USLUGA'), findsOneWidget);
    expect(find.bySemanticsLabel('+ Nova usluga'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Switch), findsNothing);
    // Desni panel bez modala: prva usluga je izabrana.
    expect(find.text('Uredi uslugu'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('desktop: tap reda puni panel, bez sheeta', (tester) async {
    await _pumpAt(tester, _desktop, _screen());

    await tester.tap(find.text('Brada').first);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(_prekidac(tester, 'Vidljivo u aplikaciji').vrijednost, isFalse);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .where((field) => field.controller?.text == 'Brada'),
      hasLength(1),
      reason:
          'naziv je u panelu vidljiv, kategorija čeka iza „Kategorija i opis"',
    );

    await tester.tap(find.text('+ NOVA USLUGA'));
    await tester.pumpAndSettle();
    expect(find.text('Nova usluga'), findsOneWidget);
    expect(find.text('Uredi uslugu'), findsNothing);
  });

  testWidgets('telefon crta kartice i donju akciju, ne tabelu ni FAB', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    expect(find.text('USLUGA'), findsNothing);
    expect(find.text('Usluge'), findsOneWidget);
    expect(find.text('30 min · svi'), findsOneWidget);
    expect(find.text('20 min · nije online'), findsOneWidget);
    expect(find.text('15 KM'), findsOneWidget);
    expect(find.text('12.50 KM'), findsOneWidget);
    expect(find.text('+ NOVA USLUGA'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('telefon: tap kartice otvara popunjen editor sa statusom', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    await tester.tap(find.text('Brada'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Vidljivo u aplikaciji'), findsOneWidget);
    expect(_prekidac(tester, 'Vidljivo u aplikaciji').vrijednost, isFalse);
    expect(find.byType(Switch), findsNothing);

    // Naziv i kategorija postojeće usluge stoje iza jednog reda.
    await tester.tap(find.text('Detalji i slika'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .where((field) => field.controller?.text == 'Brada'),
      hasLength(2),
      reason: 'naziv i kategorija su oba Brada u ovom fixtureu',
    );
  });

  testWidgets('nova usluga odbija neispravnu cijenu prije RPC-a', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    await tester.tap(find.text('+ NOVA USLUGA'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final polja = find.descendant(of: sheet, matching: find.byType(TextField));
    // Prvo polje je naziv, drugo cijena u `3q` koracima.
    await tester.enterText(polja.at(0), 'Nova');
    await tester.enterText(polja.at(1), '12.999');
    final sacuvaj = find.descendant(
      of: sheet,
      matching: find.widgetWithText(FilledButton, 'SAČUVAJ'),
    );
    await tester.ensureVisible(sacuvaj);
    await tester.tap(sacuvaj);
    await tester.pump();

    expect(find.text('Npr. 15,00'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('prazan cjenovnik ima radnju, kvar ima retry', (tester) async {
    await _pumpAt(tester, _desktop, _screen(services: const []));
    expect(find.text('Cjenovnik je prazan.'), findsOneWidget);
    expect(find.text('DODAJ PRVU USLUGU'), findsOneWidget);

    await _pumpAt(tester, _desktop, _screen(error: Exception('mreža')));
    expect(find.text('Cjenovnik se ne može učitati.'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });
}
