/// Moj profil (task 61) — `4b` na 1440, `4d` na 402.
///
/// Repozitorij je lažan: ovdje se dokazuje šta ekran šalje i kad, a ne šta baza prihvata.
/// Granice baze (tuđa slika, tuđi salon, direktan update) drži `025_moj_profil.test.sql`.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/profile/profilna_slika.dart';
import 'package:admin/src/features/profile/profile_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _radnik = StaffMember(
  id: '22222222-0000-4000-8000-000000000002',
  name: 'Emir Bešić',
  email: 'emir@primjer.test',
  role: 'employee',
  salonId: _salonId,
  employeeId: 'e1',
  phone: '061 448 220',
  photoUrl: 'https://primjer.test/profil.jpg',
);

const _vlasnikBezVeze = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Amko',
  email: 'amko@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

final _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir', role: 'Barber'),
  Employee(id: 'e2', salonId: _salonId, name: 'Amar', role: 'Barber'),
];

class _LaziStaff extends StaffRepository {
  _LaziStaff()
    : super(
        SupabaseClient(
          'http://localhost:54321',
          'anon-kljuc-za-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final pozivi = <String>[];

  @override
  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async => pozivi.add('profil:$name|$phone');

  @override
  Future<void> setUseProfilePhoto(bool use) async =>
      pozivi.add('prekidac:$use');

  @override
  Future<void> linkEmployee(String? employeeId) async =>
      pozivi.add('veza:$employeeId');
}

Widget _ekran(
  _LaziStaff repo, {
  StaffMember clan = _radnik,
  Stream<StaffMember?>? tok,
}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith((ref) => tok ?? Stream.value(clan)),
    staffRepositoryProvider.overrideWithValue(repo),
    adminSalonProvider.overrideWith((ref) async => _salon),
    adminEmployeesProvider.overrideWith((ref) async => _radnici),
    pendingCountProvider.overrideWith((ref) async => 0),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminProfileScreen(),
  ),
);

Future<void> _velicina(WidgetTester tester, Size s) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  pristupacnostEkrana('Moj profil', () => _ekran(_LaziStaff()));

  testWidgets('nova slika usred kucanja ne briše ukucano', (tester) async {
    await _velicina(tester, const Size(1440, 900));
    final tok = StreamController<StaffMember?>();
    addTearDown(tok.close);
    await tester.pumpWidget(_ekran(_LaziStaff(), tok: tok.stream));
    tok.add(_radnik);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profil-telefon')), '062 999');
    await tester.pump();
    // Upload slike osvježi člana — isti id, nova slika.
    tok.add(
      const StaffMember(
        id: '22222222-0000-4000-8000-000000000002',
        name: 'Emir Bešić',
        email: 'emir@primjer.test',
        role: 'employee',
        salonId: _salonId,
        employeeId: 'e1',
        phone: '061 448 220',
        photoUrl: 'https://primjer.test/nova.jpg',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('062 999'), findsOneWidget);
    final dugme = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('profil-sacuvaj')),
    );
    expect(dugme.onPressed, isNotNull);
  });

  for (final (ime, velicina, kljucSacuvaj) in [
    ('desktop', const Size(1440, 900), 'profil-sacuvaj'),
    ('telefon', const Size(402, 874), 'profil-sacuvaj-telefon'),
  ]) {
    testWidgets('$ime: Sačuvaj je ugašen dok se ništa ne promijeni', (
      tester,
    ) async {
      await _velicina(tester, velicina);
      final repo = _LaziStaff();
      await tester.pumpWidget(_ekran(repo));
      await tester.pumpAndSettle();

      expect(find.text('emir@primjer.test'), findsWidgets);
      bool ugasen() {
        final dugme = tester.widget<ButtonStyleButton>(
          find.byKey(Key(kljucSacuvaj)),
        );
        return dugme.onPressed == null;
      }

      expect(ugasen(), isTrue, reason: 'bez izmjene nema šta da se snimi');

      await tester.enterText(find.byKey(const Key('profil-telefon')), '062 1');
      await tester.pump();
      expect(ugasen(), isFalse);

      await tester.tap(find.byKey(Key(kljucSacuvaj)));
      await tester.pumpAndSettle();
      expect(repo.pozivi, ['profil:Emir Bešić|062 1']);
    });
  }

  testWidgets('prekidač šalje izbor odmah, bez Sačuvaj', (tester) async {
    await _velicina(tester, const Size(1440, 900));
    final repo = _LaziStaff();
    await tester.pumpWidget(_ekran(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profil-prekidac')));
    await tester.pumpAndSettle();
    expect(repo.pozivi, ['prekidac:true']);
  });

  testWidgets('prekidač je ugašen dok nema profilne slike', (tester) async {
    await _velicina(tester, const Size(1440, 900));
    const bezSlike = StaffMember(
      id: '22222222-0000-4000-8000-000000000002',
      name: 'Emir Bešić',
      email: 'emir@primjer.test',
      role: 'employee',
      salonId: _salonId,
      employeeId: 'e1',
    );
    await tester.pumpWidget(_ekran(_LaziStaff(), clan: bezSlike));
    await tester.pumpAndSettle();

    final prekidac = tester.widget<Switch>(
      find.byKey(const Key('profil-prekidac')),
    );
    expect(prekidac.onChanged, isNull);
    // Bez slike nema ni „Zamijeni mojom" — nema čime.
    expect(find.text('Zamijeni mojom'), findsNothing);
  });

  testWidgets('vlasnik bez veze bira svog radnika', (tester) async {
    await _velicina(tester, const Size(1440, 900));
    final repo = _LaziStaff();
    await tester.pumpWidget(_ekran(repo, clan: _vlasnikBezVeze));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profil-prekidac')), findsNothing);
    await tester.tap(find.text('Ja sam radnik…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amar').last);
    await tester.pumpAndSettle();
    expect(repo.pozivi, ['veza:e2']);
  });

  testWidgets('lozinka: nepoklapanje i kratka lozinka se ne šalju', (
    tester,
  ) async {
    await _velicina(tester, const Size(1440, 900));
    await tester.pumpWidget(_ekran(_LaziStaff()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('profil-lozinka')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profil-lozinka')));
    await tester.pumpAndSettle();
    final polja = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(polja.at(0), 'stara-lozinka');
    await tester.enterText(polja.at(1), 'kratka');
    await tester.enterText(polja.at(2), 'drugacija');
    await tester.tap(find.widgetWithText(FilledButton, 'Promijeni'));
    await tester.pumpAndSettle();

    expect(find.text('Najmanje 8 znakova'), findsOneWidget);
    expect(find.text('Lozinke se ne poklapaju'), findsOneWidget);
  });

  test('inicijali', () {
    expect(inicijaliOd('Emir Bešić'), 'EB');
    expect(inicijaliOd('amko'), 'A');
    expect(inicijaliOd('Ana Marija Kovač'), 'AK');
    expect(inicijaliOd('  '), '');
  });
}
