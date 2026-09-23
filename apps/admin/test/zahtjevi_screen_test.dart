/// Zahtjevi za potvrdu — prikazi `3d` (desktop) i `3m` (telefon).
///
/// Isti ekran kao puna lista termina, otvoren sa `?status=pending`. Testira se ono po čemu
/// se ta dva lica razlikuju: šta je naslov, gleda li se jedan dan ili više njih, i koje
/// radnje stoje uz zahtjev.
library;

import 'package:admin/src/core/format/datum.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/appointments/appointments_screen.dart';
import 'package:admin/src/features/appointments/zahtjev_kartica.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const Size _desktop = Size(1440, 900);
const Size _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Vlasnik',
  email: 'admin@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

const _usluge = [
  Service(
    id: 's1',
    salonId: _salonId,
    name: 'Fade + brada',
    price: 30,
    durationMinutes: 80,
  ),
];

const _radnici = [Employee(id: 'e1', salonId: _salonId, name: 'Amar')];

Appointment _zahtjev({
  required String ime,
  required LocalDate datum,
  int sat = 15,
  String? radnik = 'e1',
  String? napomena,
}) => Appointment(
  id: 'a-$ime',
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: ime,
  customerNote: napomena,
  date: datum,
  startTime: LocalTime(sat, 0),
  endTime: LocalTime(sat + 1, 20),
  status: AppointmentStatus.pending,
);

final _danas = DateTime.now();
final _danasLocal = LocalDate(_danas.year, _danas.month, _danas.day);
final _sutra = _danas.add(const Duration(days: 1));
final _sutraLocal = LocalDate(_sutra.year, _sutra.month, _sutra.day);

/// `18.05.` — kako kartica piše datum uz ime dana.
String _ddMm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

Widget _ekran({List<Appointment>? zahtjevi}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    zahtjeviProvider.overrideWith(
      (ref) async =>
          zahtjevi ??
          [
            _zahtjev(ime: 'Nedim Hodžić', datum: _danasLocal),
            _zahtjev(
              ime: 'Almir Šahić',
              datum: _sutraLocal,
              sat: 10,
              radnik: null,
            ),
          ],
    ),
    // Dnevna lista je namjerno **prazna**: ekran zahtjeva ne smije čitati nju.
    filtriraniTerminiProvider.overrideWith((ref) async => const []),
    pendingCountProvider.overrideWith((ref) async => zahtjevi?.length ?? 2),
    adminServicesProvider.overrideWith((ref) async => _usluge),
    adminEmployeesProvider.overrideWith((ref) async => _radnici),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminAppointmentsScreen(
      trazeniStatus: AppointmentStatus.pending,
    ),
  ),
);

Future<void> _naSirini(
  WidgetTester tester,
  Size velicina,
  Widget widget,
) async {
  tester.view.physicalSize = velicina;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  pristupacnostEkrana('Zahtjevi', _ekran);

  group('oba rasporeda', () {
    testWidgets('naslov broji zahtjeve, a ne termine dana', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('2 zahtjeva čekaju'), findsOneWidget);
      expect(
        find.text('Klijent vidi „na čekanju" dok ne odgovorite.'),
        findsOneWidget,
      );
    });

    testWidgets('zahtjevi nisu vezani za jedan dan', (tester) async {
      // Dnevna lista je u testu prazna; oba zahtjeva se ipak vide, i onaj za sutra.
      // Da ekran čita `filtriraniTerminiProvider`, ovo bi bilo prazno stanje.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Nedim Hodžić'), findsOneWidget);
      expect(find.text('Almir Šahić'), findsOneWidget);
      // Zato uz vrijeme stoji i dan — „15:00" bez datuma ne kaže za kada je. Za sutra
      // handoff piše ime dana, ne „sutra" (`3d`).
      final sutra = kDaniSedmice[_sutra.weekday - 1].toLowerCase();
      expect(find.text('danas, ${_ddMm(_danas)}'), findsOneWidget);
      expect(find.text('$sutra, ${_ddMm(_sutra)}'), findsOneWidget);
    });

    testWidgets('izbor dana se ne nudi u zahtjevima', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.byTooltip('Prethodni dan'), findsNothing);
      expect(find.byTooltip('Sljedeći dan'), findsNothing);
    });

    testWidgets('prazno stanje govori o zahtjevima, ne o danu', (tester) async {
      await _naSirini(tester, _desktop, _ekran(zahtjevi: []));

      expect(find.text('Nijedan zahtjev ne čeka odgovor.'), findsOneWidget);
      expect(find.text('Nema zahtjeva'), findsOneWidget);
    });
  });

  group('desktop `3d`', () {
    testWidgets('kartica nosi vrijeme, trajanje, uslugu i majstora', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('80 minuta'), findsNWidgets(2));
      // Usluga i cijena stoje u jednom podatku: „Fade + brada · 30 KM".
      expect(find.text('Fade + brada · 30 KM'), findsNWidgets(2));
      expect(find.text('Amar'), findsOneWidget);
      // Termin bez radnika: klijent je izabrao „bilo ko".
      expect(find.text('bilo ko'), findsOneWidget);
    });

    testWidgets('uz svaki zahtjev stoje potvrda i odbijanje', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // Primarna radnja u verzalu (ADR-0020).
      expect(find.text('POTVRDI'), findsNWidgets(2));
      expect(find.text('Odbij zahtjev'), findsNWidgets(2));
      // Srednja radnja iz `3d`: zahtjev sa majstorom nudi drugo vrijeme, „bilo ko"
      // promjenu majstora.
      expect(find.text('Ponudi drugo vrijeme'), findsOneWidget);
      expect(find.text('Promijeni majstora'), findsOneWidget);
    });

    testWidgets('srednja radnja nema RPC, pa kaže „uskoro"', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      await tester.tap(find.text('Ponudi drugo vrijeme'));
      await tester.pump();

      expect(find.text('Ponuda drugog vremena — uskoro.'), findsOneWidget);
    });

    testWidgets('top bar nudi grupnu potvrdu', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Potvrdi sve bez preklapanja'), findsOneWidget);
      // U zahtjevima se ne nudi ručni unos: to je radnja pune liste.
      expect(find.text('+ NOVI TERMIN'), findsNothing);
    });

    testWidgets('grupna potvrda je onemogućena kad nema zahtjeva', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran(zahtjevi: []));

      final dugme = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Potvrdi sve bez preklapanja'),
      );
      expect(dugme.onPressed, isNull);
    });
  });

  group('telefon `3m`', () {
    testWidgets('zahtjevi su kartice sa istim radnjama', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      // `3m`: zahtjev ima svoju karticu, ne opštu `AppointmentCard`.
      expect(tester.takeException(), isNull);
      expect(find.byType(ZahtjevKarticaTelefon), findsNWidgets(2));
      expect(find.text('POTVRDI'), findsNWidgets(2));
      expect(find.text('Odbij'), findsNWidgets(2));
    });

    testWidgets('bez FAB-a za ručni unos', (tester) async {
      // FAB stoji uz punu listu; u zahtjevima bi vodio na drugi tok usred odlučivanja.
      await _naSirini(tester, _telefon, _ekran());

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('široki ekrani (FE-406)', () {
    testWidgets('na 2560 px zahtjevi ostaju jedna kolona, bez prelijevanja', (
      tester,
    ) async {
      // **Ovu je našla suita, ne pregled koda.** Prva verzija fluidne mreže je i zahtjeve
      // slagala u četiri kolone, a `_ZahtjevKartica` je raspored iz `3d`
      // (vrijeme | podaci | radnje) računat za punu radnu površinu — u koloni od ~560 px
      // `Row` je prelio za 303 px i oborio šest testova u ovom fajlu.
      //
      // Test stoji ovdje, a ne uz ostale FE-406 provjere u `appointments_screen_test.dart`:
      // zahtjevi se čitaju iz `zahtjeviProvider`, pa tamošnji `_ekran` (koji override-uje
      // `filtriraniTerminiProvider`) ne nacrta nijednu karticu i provjera bi bila prazna.
      await _naSirini(tester, const Size(2560, 1200), _ekran());

      expect(tester.takeException(), isNull);

      // Jedna kolona: sve kartice dijele lijevu ivicu.
      final kartice = find.byType(Card);
      expect(kartice, findsWidgets);
      final prva = tester.getRect(kartice.first).left;
      for (var i = 1; i < kartice.evaluate().length; i++) {
        expect(tester.getRect(kartice.at(i)).left, prva);
      }
    });
  });
}
