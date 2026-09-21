/// Usluge na dvije širine — `3f`, `3p` i editor `3q`.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/services/services_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('desktop crta tabelu, cijene i top-bar akciju', (tester) async {
    await _pumpAt(tester, _desktop, _screen());

    expect(find.text('Cjenovnik'), findsOneWidget);
    expect(find.text('USLUGA'), findsOneWidget);
    expect(find.text('TRAJANJE'), findsOneWidget);
    expect(find.text('CIJENA'), findsOneWidget);
    expect(find.text('Muško šišanje'), findsOneWidget);
    expect(find.text('12.50 KM'), findsOneWidget);
    expect(find.text('Neaktivna'), findsOneWidget);
    expect(find.text('+ Nova usluga'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('telefon crta kartice i floating akciju, ne desktop zaglavlje', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    expect(find.text('USLUGA'), findsNothing);
    expect(find.text('30 min · 15 KM'), findsOneWidget);
    expect(find.text('20 min · 12.50 KM'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('tap reda otvara popunjen editor sa statusom', (tester) async {
    await _pumpAt(tester, _telefon, _screen());

    await tester.tap(find.text('Brada'));
    await tester.pumpAndSettle();

    expect(find.text('Uredi uslugu'), findsOneWidget);
    expect(
      tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .where((field) => field.controller?.text == 'Brada'),
      hasLength(2),
      reason: 'naziv i kategorija su oba Brada u ovom fixtureu',
    );
    expect(find.text('Vidljivo u aplikaciji'), findsOneWidget);
    expect(find.text('Ponovo aktiviraj uslugu'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('nova usluga odbija neispravnu cijenu prije RPC-a', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Naziv'), 'Nova');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Trajanje (min)'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cijena (KM)'),
      '12.999',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sačuvaj'));
    await tester.pump();

    expect(find.text('Npr. 15,00'), findsOneWidget);
  });

  testWidgets('prazan cjenovnik ima radnju, kvar ima retry', (tester) async {
    await _pumpAt(tester, _desktop, _screen(services: const []));
    expect(find.text('Cjenovnik je prazan.'), findsOneWidget);
    expect(find.text('Dodaj prvu uslugu'), findsOneWidget);

    await _pumpAt(tester, _desktop, _screen(error: Exception('mreža')));
    expect(find.text('Cjenovnik se ne može učitati.'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });
}
