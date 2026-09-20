/// „Danas" na dvije širine — prikazi `3b` (desktop) i `3k` (telefon).
///
/// Isti ekran i isti podaci; mijenja se samo širina prozora. Dva odvojena testa nad dva
/// widgeta bi prolazila i kad bi dashboard imao dva stabla, a upravo to sprint zabranjuje.
library;

import 'package:admin/src/core/format/datum.dart';
import 'package:admin/src/features/appointments/appointment_card.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/dashboard/dashboard_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const Size _desktop = Size(1440, 900);
const Size _siroki = Size(1920, 1080);
const Size _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Emir Besic',
  email: 'emir@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

final _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barber-studio-vitez',
  city: 'Vitez',
);

const _usluge = [
  Service(
    id: 's1',
    salonId: _salonId,
    name: 'Fade šišanje',
    price: 20,
    durationMinutes: 40,
  ),
  Service(
    id: 's2',
    salonId: _salonId,
    name: 'Brada',
    price: 15,
    durationMinutes: 20,
  ),
];

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir'),
  Employee(id: 'e2', salonId: _salonId, name: 'Vedad'),
];

Appointment _termin({
  required String ime,
  required int sat,
  AppointmentStatus status = AppointmentStatus.confirmed,
  String usluga = 's1',
  String? radnik = 'e1',
  LocalDate? datum,
}) => Appointment(
  id: 'a-$ime-$sat',
  salonId: _salonId,
  serviceId: usluga,
  employeeId: radnik,
  customerId: 'c1',
  customerName: ime,
  date: datum ?? LocalDate(2026, 9, 14),
  startTime: LocalTime(sat, 0),
  endTime: LocalTime(sat, 40),
  status: status,
);

final _danasnji = [
  _termin(ime: 'Adnan Kovač', sat: 12, status: AppointmentStatus.completed),
  _termin(ime: 'Haris Delić', sat: 14, radnik: 'e2'),
  _termin(
    ime: 'Nedim Hodžić',
    sat: 15,
    status: AppointmentStatus.pending,
    usluga: 's2',
    radnik: null,
  ),
];

Widget _ekran({
  List<Appointment>? termini,
  List<Appointment>? zahtjevi,
  int naCekanju = 2,
}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminSalonProvider.overrideWith((ref) async => _salon),
    danasnjiTerminiProvider.overrideWith((ref) async => termini ?? _danasnji),
    zahtjeviProvider.overrideWith(
      (ref) async =>
          zahtjevi ??
          [
            _termin(
              ime: 'Nedim Hodžić',
              sat: 15,
              status: AppointmentStatus.pending,
              radnik: null,
            ),
          ],
    ),
    pendingCountProvider.overrideWith((ref) async => naCekanju),
    adminServicesProvider.overrideWith((ref) async => _usluge),
    adminEmployeesProvider.overrideWith((ref) async => _radnici),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminDashboardScreen(),
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
  group('desktop `3b`', () {
    testWidgets('naslov je datum, a ne ime prijavljenog', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text(datumDugo(DateTime.now())), findsOneWidget);
      // Ime člana osoblja stoji u sidebaru; ekran je o danu, ne o korisniku.
      expect(find.textContaining('prvi 12:00'), findsOneWidget);
    });

    testWidgets('breadcrumb nosi ime salona pa naslov ekrana', (tester) async {
      // `Vitez / Danas` iz canvasa. Ime dolazi iz `salons`, jer ga `StaffMember` ne nosi —
      // do taska 30 je top bar imao samo naslov.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Barber Studio Vitez'), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('Danas'), findsWidgets);
    });

    testWidgets('tri kartice metrika, sa tačnim brojkama', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Termina danas'), findsOneWidget);
      expect(find.text('Čeka potvrdu'), findsOneWidget);
      expect(find.text('Promet danas'), findsOneWidget);
      // Četvrta kartica iz canvasa traži smjene radnika (task 33) i namjerno je nema.
      expect(find.text('Slobodno vrijeme'), findsNothing);

      expect(find.text('1 završeno · 2 predstoji'), findsOneWidget);
      // Promet: završeni `s1` je 20 KM; prognoza dodaje `s1` i `s2` koji predstoje.
      expect(find.text('20 KM'), findsOneWidget);
      expect(find.text('prognoza 55 KM'), findsOneWidget);
    });

    testWidgets('tabela nosi pet kolona i sve termine dana', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      for (final kolona in [
        'VRIJEME',
        'KLIJENT',
        'USLUGA',
        'MAJSTOR',
        'STATUS',
      ]) {
        expect(find.text(kolona), findsOneWidget, reason: 'kolona $kolona');
      }

      expect(find.text('Adnan Kovač'), findsOneWidget);
      expect(find.text('Fade šišanje'), findsWidgets);
      // Termin bez radnika piše „bilo ko", ne crticu: crtica se čita kao podatak koji
      // nedostaje, a ovo je izbor klijenta.
      expect(find.text('bilo ko'), findsOneWidget);
    });

    testWidgets('kartica zahtjeva vodi na punu listu', (tester) async {
      await _naSirini(tester, _desktop, _ekran(naCekanju: 5));

      expect(find.text('Zahtjevi'), findsWidgets);
      expect(find.text('5 novih'), findsOneWidget);
      expect(find.text('Potvrdi'), findsOneWidget);
      expect(find.text('Odbij'), findsOneWidget);
      expect(find.text('Vidi svih 5 zahtjeva →'), findsOneWidget);
    });

    testWidgets('zauzetost mjeri minute, ne procenat kapaciteta', (
      tester,
    ) async {
      // Canvas piše „82%", što traži smjenu radnika; dok smjena nema, procenat bi bio
      // izmišljen. Traka je relativna, a broj uz nju je ono što se stvarno zna.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Zauzetost majstora'), findsOneWidget);
      // Cijeli red, ne podniz: prva verzija je pisala „1 1 termin", jer `_terminaTekst`
      // već nosi broj. `findsWidgets` nad `40m` je to propustio.
      expect(find.text('1 termin · 40m'), findsNWidgets(2));
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('radna površina se širi sa prozorom', (tester) async {
      // 1440 je mjesto gdje je canvas crtan, ne najveći monitor: tabela na 1920 mora
      // dobiti tih 480 px, a ne ostaviti prazan pojas desno.
      // Mjeri se prva kartica metrike: tri su u redu preko cijele radne površine, pa joj
      // pripada tačno trećina dobijenih 480 px.
      await _naSirini(tester, _desktop, _ekran());
      final naUskom = tester.getSize(find.byType(Card).first).width;

      await _naSirini(tester, _siroki, _ekran());
      final naSirokom = tester.getSize(find.byType(Card).first).width;

      expect(naSirokom, greaterThan(naUskom));
      expect(
        naSirokom - naUskom,
        closeTo((_siroki.width - _desktop.width) / 3, 1),
      );
    });

    testWidgets('top bar nosi akcije iz `3b`', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('+ Novi termin'), findsOneWidget);
      expect(find.text('Blokiraj termin'), findsOneWidget);
      // Pretraga klijenta traži modul klijenata (task 35); polje koje ne traži ništa je
      // gore od polja kojeg nema.
      expect(find.text('Pretraži klijenta'), findsNothing);
    });
  });

  group('telefon `3k`', () {
    testWidgets('ekran nosi svoje zaglavlje, bez AppBar-a', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      // `AppBar` sa sitnim „Danas" iznad velikog „Danas" bi istu riječ napisao dvaput.
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Danas'), findsWidgets);
      expect(find.textContaining('3 termina'), findsOneWidget);
    });

    testWidgets('traka zahtjeva vodi u punu listu', (tester) async {
      await _naSirini(tester, _telefon, _ekran(naCekanju: 4));

      expect(find.text('4 zahtjeva čekaju'), findsOneWidget);
      expect(find.text('Pregledaj zahtjeve'), findsOneWidget);
    });

    testWidgets('bez zahtjeva nema ni trake', (tester) async {
      await _naSirini(tester, _telefon, _ekran(naCekanju: 0, zahtjevi: []));

      expect(find.text('Pregledaj zahtjeve'), findsNothing);
    });

    testWidgets('raspored su kartice, ne tabela', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      // `SPEC.md`: „Tabele na uskim širinama prelaze u kartice/liste."
      expect(find.text('VRIJEME'), findsNothing);
      expect(find.byType(AppointmentCard), findsNWidgets(3));
      // Kartica nosi uslugu, majstora i cijenu u jednom redu.
      expect(find.text('Fade šišanje · Emir · 20 KM'), findsOneWidget);
    });

    testWidgets('dvije male metrike iz `3k`', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Predstoji danas'), findsOneWidget);
      expect(find.text('Promet do sada'), findsOneWidget);
    });

    testWidgets('ime salona stoji na ekranu, bez birača lokacije', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Barber Studio Vitez'), findsOneWidget);
      // `▾` iz canvasa je `3a` (više lokacija) i izvan je sprinta.
      expect(find.text('promijeni lokaciju'), findsNothing);
    });
  });

  group('termin koji traje', () {
    test('samo potvrđen termin može biti „u toku"', () {
      final sada = DateTime(2026, 9, 14, 14, 20);
      final potvrdjen = _termin(ime: 'Haris', sat: 14);

      expect(terminUToku(potvrdjen, sada), isTrue);
      // Zahtjev koji čeka nije počeo: salon još nije rekao da hoće.
      expect(
        terminUToku(
          _termin(ime: 'Haris', sat: 14, status: AppointmentStatus.pending),
          sada,
        ),
        isFalse,
      );
      // Isti sat, drugi dan.
      expect(
        terminUToku(
          _termin(ime: 'Haris', sat: 14, datum: LocalDate(2026, 9, 15)),
          sada,
        ),
        isFalse,
      );
      // Termin koji je istekao u 14:40.
      expect(terminUToku(potvrdjen, DateTime(2026, 9, 14, 14, 45)), isFalse);
    });
  });
}
