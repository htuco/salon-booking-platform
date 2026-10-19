/// Ručni termin otvoren iz sedmice (task 69) — prijedlog vremena iz `?time=`.
///
/// Pravilo koje se ovdje čuva: **prazno mjesto u kalendaru nije slobodan termin.** Vrijeme
/// koje je vlasnik dodirnuo se izabere samo ako ga `get_available_slots` vrati; inače forma
/// ostaje bez vremena. Bez ovog testa bi se provjera `distinctTimes.contains` mogla obrisati
/// i suita bi ostala zelena (pregled #137).
///
/// Datumi su relativni na danas, jer forma ne ide u prošlost — to je jedino mjesto gdje
/// test čita stvarni sat, i čita ga samo za „koji je dan".
library;

import 'dart:async';

import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/appointments/new_appointment_screen.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Hamza',
  email: 'hamza@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

const _usluga = Service(
  id: 's1',
  salonId: _salonId,
  name: 'Fade',
  price: 20,
  durationMinutes: 30,
);

const _radnici = [Employee(id: 'e1', salonId: _salonId, name: 'Emir')];

const _veze = [
  EmployeeService(
    id: 'v1',
    salonId: _salonId,
    employeeId: 'e1',
    serviceId: 's1',
  ),
];

AvailableSlot _slot(int sat, int minuta) =>
    AvailableSlot(startTime: LocalTime(sat, minuta), employeeId: 'e1');

/// Vraća slotove po radniku; upit za „bilo koji" se može zadržati da stigne zadnji.
class _LazniSlotovi implements StaffAppointmentRepository {
  _LazniSlotovi({required this.zaSve, this.zaRadnika = const []});

  final List<AvailableSlot> zaSve;
  final List<AvailableSlot> zaRadnika;
  final upiti = <({LocalDate date, String? employeeId})>[];

  /// Kad nije `null`, odgovor za „bilo koji" čeka na ovaj completer.
  Completer<void>? zadrziSve;

  @override
  Future<List<AvailableSlot>> slotsForManualBooking({
    required String salonId,
    required String serviceId,
    required LocalDate date,
    String? employeeId,
  }) async {
    upiti.add((date: date, employeeId: employeeId));
    if (employeeId != null) return zaRadnika;
    if (zadrziSve case final c?) await c.future;
    return zaSve;
  }

  @override
  Future<List<Customer>> searchCustomers({
    required String salonId,
    required String upit,
    int limit = 20,
  }) async => const [
    Customer(id: 'c1', salonId: _salonId, name: 'Mirza Aliagić'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DateTime _danas() {
  final sada = DateTime.now();
  return DateTime(sada.year, sada.month, sada.day);
}

Widget _forma(
  _LazniSlotovi slotovi, {
  required DateTime datum,
  LocalTime? vrijeme,
}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminServicesProvider.overrideWith((ref) async => const [_usluga]),
    adminEmployeesProvider.overrideWith((ref) async => _radnici),
    adminEmployeeLinksProvider.overrideWith((ref) async => _veze),
    // Forma ga čita jednom (`ref.read`), pa ne smije čekati stream člana.
    adminSalonIdProvider.overrideWithValue(_salonId),
    staffAppointmentRepositoryProvider.overrideWithValue(slotovi),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: NewAppointmentScreen(initialDate: datum, initialTime: vrijeme),
  ),
);

Future<void> _izaberiKlijentaIUslugu(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Mir');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mirza Aliagić'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fade · 30 min'));
  await tester.pumpAndSettle();
}

/// „Sačuvaj" je omogućen tek kad su klijent, usluga **i vrijeme** izabrani. Jedino mjesto
/// gdje se vidi da je forma sama izabrala vrijeme kojeg nema među čipovima — a upravo to
/// bi uradio prijedlog bez provjere slobodnih.
bool _sacuvajOmoguceno(WidgetTester tester) =>
    tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.text('Sačuvaj'),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity ==
    1;

bool _izabrano(WidgetTester tester, String vrijeme) => tester
    .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, vrijeme))
    .selected;

void main() {
  setUp(() {
    // Forma je duga lista; visok prozor drži korak 4 vidljivim bez skrolanja.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio(),
  );

  final sutra = DateTime(_danas().year, _danas().month, _danas().day + 1);

  testWidgets('dodirnuto vrijeme se izabere kad ga baza vrati kao slobodno', (
    tester,
  ) async {
    final slotovi = _LazniSlotovi(zaSve: [_slot(10, 0), _slot(10, 30)]);
    await tester.pumpWidget(
      _forma(slotovi, datum: sutra, vrijeme: const LocalTime(10, 30)),
    );
    await _izaberiKlijentaIUslugu(tester);

    expect(_izabrano(tester, '10:30'), isTrue);
    expect(_izabrano(tester, '10:00'), isFalse);
    expect(_sacuvajOmoguceno(tester), isTrue);
  });

  testWidgets('dodirnuto vrijeme koje nije slobodno se ne izabere', (
    tester,
  ) async {
    // 10:30 je u kalendaru prazno, ali ga buffer ili korak slota zatvaraju.
    final slotovi = _LazniSlotovi(zaSve: [_slot(10, 0), _slot(11, 0)]);
    await tester.pumpWidget(
      _forma(slotovi, datum: sutra, vrijeme: const LocalTime(10, 30)),
    );
    await _izaberiKlijentaIUslugu(tester);

    expect(find.widgetWithText(ChoiceChip, '10:30'), findsNothing);
    expect(_izabrano(tester, '10:00'), isFalse);
    expect(_izabrano(tester, '11:00'), isFalse);
    expect(_sacuvajOmoguceno(tester), isFalse);
  });

  testWidgets('prošli datum iz adrese otvara formu na danas, bez prijedloga', (
    tester,
  ) async {
    final jucer = DateTime(_danas().year, _danas().month, _danas().day - 1);
    final slotovi = _LazniSlotovi(zaSve: [_slot(10, 30)]);
    await tester.pumpWidget(
      _forma(slotovi, datum: jucer, vrijeme: const LocalTime(10, 30)),
    );
    await _izaberiKlijentaIUslugu(tester);

    final danas = _danas();
    expect(
      slotovi.upiti.single.date,
      LocalDate(danas.year, danas.month, danas.day),
    );
    // Prijedlog je bio za jučer; danas u 10:30 nije ono što je vlasnik dodirnuo.
    expect(_izabrano(tester, '10:30'), isFalse);
    expect(_sacuvajOmoguceno(tester), isFalse);
  });

  testWidgets('zastarjeli odgovor ne bira prijedlog iz tuđe liste', (
    tester,
  ) async {
    // „Bilo koji" ima 10:30, Emir nema. Upit za „bilo koji" stigne zadnji.
    final slotovi = _LazniSlotovi(
      zaSve: [_slot(10, 30)],
      zaRadnika: [_slot(11, 0)],
    )..zadrziSve = Completer<void>();
    await tester.pumpWidget(
      _forma(slotovi, datum: sutra, vrijeme: const LocalTime(10, 30)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mir');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mirza Aliagić'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fade · 30 min'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Emir'));
    await tester.pumpAndSettle();
    slotovi.zadrziSve!.complete();
    await tester.pumpAndSettle();

    expect(slotovi.upiti.map((u) => u.employeeId), [null, 'e1']);
    expect(find.widgetWithText(ChoiceChip, '10:30'), findsNothing);
    expect(_izabrano(tester, '11:00'), isFalse);
    expect(_sacuvajOmoguceno(tester), isFalse);
  });
}
