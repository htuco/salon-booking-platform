/// „Pristup" u Postavkama — osoblje, pozivi i novi poziv (task 45).
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/settings/pristup.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: 'u1',
  name: 'Emir Bešić',
  email: 'emir@test.invalid',
  role: 'salon_admin',
  salonId: _salonId,
);

const _radnik = StaffMember(
  id: 'u2',
  name: 'Amar',
  email: 'amar@test.invalid',
  role: 'employee',
  salonId: _salonId,
);

/// Lažni repozitorij: pamti pozive, bez mreže.
class _Lazni implements StaffAccessRepository {
  final napravljeni = <(String, String, String?)>[];
  final povuceni = <String>[];

  @override
  Future<List<StaffMember>> members(String salonId) async => [
    _vlasnik,
    _radnik,
  ];

  @override
  Future<List<StaffInvite>> pendingInvites(String salonId) async => [
    StaffInvite(
      id: 'p1',
      name: 'Lejla',
      role: 'employee',
      expiresAt: DateTime(2026, 10, 1),
    ),
  ];

  @override
  Future<StaffInviteCode> createInvite({
    required String salonId,
    required String role,
    required String name,
    String? employeeId,
  }) async {
    napravljeni.add((role, name, employeeId));
    return StaffInviteCode(
      inviteId: 'p2',
      code: 'ABCDEFGH23',
      expiresAt: DateTime(2026, 10, 1),
    );
  }

  @override
  Future<void> revokeInvite({
    required String salonId,
    required String inviteId,
  }) async => povuceni.add(inviteId);

  @override
  Future<void> removeMember({
    required String salonId,
    required String userId,
  }) async {}

  @override
  Future<void> acceptInvite({
    required String code,
    required String email,
    required String password,
  }) async {}
}

Widget _ekran(_Lazni repo) => ProviderScope(
  overrides: [
    staffAccessRepositoryProvider.overrideWithValue(repo),
    adminEmployeesProvider.overrideWith(
      (ref) async => const [
        Employee(id: 'e1', salonId: _salonId, name: 'Amar'),
        Employee(id: 'e2', salonId: _salonId, name: 'Emir'),
      ],
    ),
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const Scaffold(body: SingleChildScrollView(child: PristupSadrzaj())),
  ),
);

void main() {
  test('poruka nosi kod i, na webu, link koji ga prenosi', () {
    final poruka = porukaPoziva(
      ime: 'Amar',
      kod: 'ABCDEFGH23',
      salon: 'Barber Studio Vitez',
      adresa: Uri.parse('https://admin.test'),
    );
    expect(poruka, contains('Kod: ABCDEFGH23'));
    expect(poruka, contains('https://admin.test/pozivnica?kod=ABCDEFGH23'));
    expect(poruka, contains('7 dana'));

    final bezLinka = porukaPoziva(ime: 'A', kod: 'K', salon: 'S');
    expect(bezLinka, contains('Imam poziv'));
  });

  testWidgets('lista osoblja i poziva; sebe vlasnik ne može ukloniti', (
    tester,
  ) async {
    await tester.pumpWidget(_ekran(_Lazni()));
    await tester.pumpAndSettle();

    expect(find.text('Emir Bešić'), findsOneWidget);
    expect(find.text('vlasnik lokacije · vi'), findsOneWidget);
    expect(find.text('Amar'), findsOneWidget);
    expect(find.text('Lejla'), findsOneWidget);
    // Jedno „Ukloni" (radnik), nijedno uz vlasnika koji gleda ekran.
    expect(find.text('Ukloni'), findsOneWidget);
    expect(find.text('Povuci'), findsOneWidget);
  });

  testWidgets('poziv: radnik se bira iz Osoblja, ime dolazi od njega', (
    tester,
  ) async {
    final repo = _Lazni();
    await tester.pumpWidget(_ekran(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Pozovi člana osoblja'));
    await tester.pumpAndSettle();
    // Podrazumijevana uloga je radnik — češći slučaj, i manje prava ako vlasnik ne pogleda.
    expect(find.text('Radnik vidi i vodi samo svoje termine.'), findsOneWidget);

    // Bez izabranog radnika poziv se ne pravi (baza bi ga ionako odbila, task 46).
    await tester.tap(find.text('Napravi poziv'));
    await tester.pumpAndSettle();
    expect(find.text('Izaberite radnika.'), findsOneWidget);
    expect(repo.napravljeni, isEmpty);

    await tester.tap(find.text('Koji radnik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Napravi poziv'));
    await tester.pumpAndSettle();

    expect(repo.napravljeni, [('employee', 'Emir', 'e2')]);
    expect(find.text('Poziv je spreman'), findsOneWidget);
    expect(find.text('ABCDEFGH23'), findsOneWidget);
    expect(find.text('Kopiraj poruku'), findsOneWidget);
  });

  testWidgets('poziv za vlasnika traži ime, bez radnika', (tester) async {
    final repo = _Lazni();
    await tester.pumpWidget(_ekran(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Pozovi člana osoblja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vlasnik'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Selma');
    await tester.tap(find.text('Napravi poziv'));
    await tester.pumpAndSettle();

    expect(repo.napravljeni, [('salon_admin', 'Selma', null)]);
  });

  testWidgets('povlačenje poziva', (tester) async {
    final repo = _Lazni();
    await tester.pumpWidget(_ekran(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Povuci'));
    await tester.pumpAndSettle();
    expect(repo.povuceni, ['p1']);
  });
}
