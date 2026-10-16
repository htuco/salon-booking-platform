/// Sedmica kalendara na ekranu (task 69) — `7a` (1440), `7c` (1024) i `7b` (402).
///
/// Model i provideri imaju svoje testove (`calendar_week_test.dart`,
/// `calendar_week_providers_test.dart`); ovdje je ono što se vidi samo na ekranu: prekidač,
/// zaglavlje dana sa odsutnima, čipovi, prelaz na dan, tap na prazno i lista na telefonu —
/// za vlasnika i za radnika.
///
/// Vrijeme je fiksirano kao u `calendar_screen_test.dart`: ponedjeljak 18. maj 2026, 13:00.
library;

import 'package:admin/src/core/router/admin_router.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/calendar/calendar_day.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/calendar/calendar_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const Size _desktop = Size(1440, 900);
const Size _tablet = Size(1024, 768);
const Size _telefon = Size(402, 874);

/// Ponedjeljak, 18. maj 2026 — sedmica iz skice.
final _ponedjeljak = DateTime(2026, 5, 18);
final _sada = DateTime(2026, 5, 18, 13);

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Hamza',
  email: 'hamza@primjer.test',
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
    durationMinutes: 60,
  ),
];

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir Bešić'),
  Employee(id: 'e2', salonId: _salonId, name: 'Vedad'),
  Employee(id: 'e3', salonId: _salonId, name: 'Amar Kurić'),
];

LocalDate _dan(int i) => LocalDate(2026, 5, 18 + i);

Appointment _termin(
  String ime, {
  required int dan,
  required int od,
  required int doMinuta,
  required String radnik,
  AppointmentStatus status = AppointmentStatus.confirmed,
}) => Appointment(
  id: 'a-$ime',
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: ime,
  date: _dan(dan),
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
  status: status,
);

/// Salon radi pon–sub (subotom do 15), nedjeljom ne. Emir četvrtkom ne radi.
final _radnoVrijeme = [
  for (var d = 1; d <= 6; d++)
    WorkingHour(
      id: 'wh-$d',
      salonId: _salonId,
      dayOfWeek: d,
      startTime: const LocalTime(9, 0),
      endTime: d == 6 ? const LocalTime(15, 0) : const LocalTime(20, 0),
    ),
  WorkingHour(
    id: 'wh-emir-cet',
    salonId: _salonId,
    employeeId: 'e1',
    dayOfWeek: 4,
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(17, 0),
    isClosed: true,
  ),
];

final _termini = [
  _termin('Adnan Kovač', dan: 0, od: 9 * 60, doMinuta: 10 * 60, radnik: 'e1'),
  _termin('Kenan Zukić', dan: 1, od: 9 * 60, doMinuta: 10 * 60, radnik: 'e2'),
  _termin(
    'Ajdin Softić',
    dan: 2,
    od: 15 * 60,
    doMinuta: 16 * 60 + 30,
    radnik: 'e1',
    status: AppointmentStatus.pending,
  ),
  _termin(
    'Alen Omerović',
    dan: 4,
    od: 12 * 60,
    doMinuta: 13 * 60,
    radnik: 'e3',
  ),
];

final _blokade = [
  // Radnikova: uz „Svi" ide u red odsutnih, ne u kolonu.
  BlockedSlot(
    id: 'b-vedad',
    salonId: _salonId,
    employeeId: 'e2',
    date: _dan(1),
    startTime: const LocalTime(12, 0),
    endTime: const LocalTime(13, 0),
    reason: 'Doktor',
  ),
  // Salonska: uvijek u koloni.
  BlockedSlot(
    id: 'b-salon',
    salonId: _salonId,
    date: _dan(2),
    startTime: const LocalTime(12, 0),
    endTime: const LocalTime(13, 0),
    reason: 'Salon zatvoren · sastanak',
  ),
];

class _FiksniDatum extends KalendarDatumNotifier {
  _FiksniDatum(this._pocetni);

  final DateTime _pocetni;

  @override
  DateTime build() => _pocetni;
}

class _FiksniPrikaz extends KalendarPrikazNotifier {
  _FiksniPrikaz(this._pocetni);

  final KalendarPrikaz _pocetni;

  @override
  KalendarPrikaz build() => _pocetni;
}

Widget _ekran({
  KalendarPrikaz prikaz = KalendarPrikaz.sedmica,
  String? radnikIzUloge,
  List<Appointment>? termini,
  List<BlockedSlot>? blokade,
}) {
  final router = GoRouter(
    initialLocation: AdminRoute.calendar.path,
    routes: [
      GoRoute(
        path: AdminRoute.calendar.path,
        builder: (_, _) => const AdminCalendarScreen(),
      ),
      GoRoute(
        path: AdminRoute.appointmentNew.path,
        builder: (_, state) => Scaffold(body: Text('forma ${state.uri.query}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentStaffProvider.overrideWith(
        (ref) => Stream<StaffMember?>.value(_vlasnik),
      ),
      adminRadnikIdProvider.overrideWithValue(radnikIzUloge),
      adminSalonProvider.overrideWith((ref) async => _salon),
      adminServicesProvider.overrideWith((ref) async => _usluge),
      adminEmployeesProvider.overrideWith((ref) async => _radnici),
      // Repozitorij za radnika vraća samo njegove termine; lažni ulaz ih vraća sve, pa
      // test dokazuje i da sedmica sama filtrira po ulozi.
      kalendarTerminiSedmiceProvider.overrideWith(
        (ref) async => termini ?? _termini,
      ),
      kalendarBlokadeSedmiceProvider.overrideWith(
        (ref) async => blokade ?? _blokade,
      ),
      kalendarRadnoVrijemeProvider.overrideWith((ref) async => _radnoVrijeme),
      // Dnevni prikaz, kad se na njega pređe iz sedmice.
      kalendarTerminiProvider.overrideWith((ref) async => const []),
      kalendarBlokadeProvider.overrideWith((ref) async => const []),
      sadaProvider.overrideWith((ref) => Stream.value(_sada)),
      kalendarDatumProvider.overrideWith(() => _FiksniDatum(_ponedjeljak)),
      kalendarPrikazProvider.overrideWith(() => _FiksniPrikaz(prikaz)),
    ],
    child: MaterialApp.router(theme: buildAdminTheme(), routerConfig: router),
  );
}

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
  pristupacnostEkrana('Kalendar — sedmica', _ekran);

  test('dodir na osi se zaokružuje dolje na pola sata, unutar ose', () {
    const osa = KalendarOsa(pocetakMinuta: 9 * 60, krajMinuta: 20 * 60);

    // 10:37 → 10:30, 10:29 → 10:00.
    expect(pocetakZaDodir(osa, osa.yZa(10 * 60 + 37)), 10 * 60 + 30);
    expect(pocetakZaDodir(osa, osa.yZa(10 * 60 + 29)), 10 * 60);
    // Dno ose ostavlja pola sata za termin, vrh ne ide prije otvaranja.
    expect(pocetakZaDodir(osa, osa.visina), 19 * 60 + 30);
    expect(pocetakZaDodir(osa, -5), 9 * 60);
  });

  test('vrijeme iz adrese forme: prijedlog, a pokvaren je kao da ga nema', () {
    expect(vrijemeIzAdrese('10:30'), const LocalTime(10, 30));
    expect(vrijemeIzAdrese('25:00'), isNull);
    expect(vrijemeIzAdrese('deset'), isNull);
    expect(vrijemeIzAdrese(null), isNull);
  });

  test('naslov sedmice, i preko granice mjeseca', () {
    expect(naslovSedmice(DateTime(2026, 5, 18)), '18. – 24. maj 2026');
    expect(naslovSedmice(DateTime(2026, 9, 28)), '28. sep – 4. okt 2026');
  });

  group('desktop `7a`', () {
    testWidgets('prekidač „Sedmica" otvara sedmicu, „Dan" je podrazumijevan', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran(prikaz: KalendarPrikaz.dan));
      expect(find.text('Ponedjeljak, 18. maj'), findsOneWidget);
      expect(find.text('18. – 24. maj 2026'), findsNothing);

      await tester.tap(find.text('Sedmica'));
      await tester.pumpAndSettle();

      expect(find.text('18. – 24. maj 2026'), findsOneWidget);
      for (final dan in ['PON', 'UTO', 'SRI', 'ČET', 'PET', 'SUB', 'NED']) {
        expect(find.text(dan), findsOneWidget, reason: dan);
      }
    });

    testWidgets(
      'sedam kolona sa terminima, salonskom blokadom i neradnim danom',
      (tester) async {
        await _naSirini(tester, _desktop, _ekran());

        for (final ime in [
          'Adnan Kovač',
          'Kenan Zukić',
          'Ajdin Softić',
          'Alen Omerović',
        ]) {
          expect(find.text(ime), findsOneWidget, reason: ime);
        }
        expect(find.text('Salon zatvoren · sastanak'), findsOneWidget);
        // Nedjelja: zaglavlje i šrafura kolone.
        expect(find.text('Ne radi'), findsNWidgets(2));
        expect(find.text('Ne radi od 15:00'), findsOneWidget);
        expect(find.text('09:00–20:00 · 1 termin'), findsNWidgets(4));
      },
    );

    testWidgets('uz „Svi" odsutni stoje u zaglavlju, ne u koloni', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Emir Bešić ne radi'), findsOneWidget);
      expect(find.text('Vedad 12:00–13:00 · Doktor'), findsOneWidget);
      // Vedadova blokada nije pojas u koloni — tvrdila bi da je salon zatvoren.
      expect(find.text('Doktor'), findsNothing);
    });

    testWidgets('čipovi nose inicijale, a izbor radnika filtrira sedmicu', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Svi'), findsOneWidget);
      // Avatar bez slike: dva slova na boji radnika (čip, termini, odsutni).
      expect(find.text('EB'), findsWidgets);
      expect(find.text('AK'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Vedad'));
      await tester.pumpAndSettle();

      expect(find.text('Kenan Zukić'), findsOneWidget);
      expect(find.text('Adnan Kovač'), findsNothing);
      // Filtriran radnik: njegova blokada je sada pojas u koloni, a red odsutnih nestaje.
      expect(find.text('Doktor'), findsOneWidget);
      expect(find.text('Vedad 12:00–13:00 · Doktor'), findsNothing);
    });

    testWidgets('tap na zaglavlje dana otvara taj dan', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      await tester.tap(find.text('UTO'));
      await tester.pumpAndSettle();

      expect(find.text('Utorak, 19. maj'), findsOneWidget);
      expect(find.text('18. – 24. maj 2026'), findsNothing);
    });

    testWidgets('strelica ide za sedmicu, „Ova sedmica" vraća na tekuću', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());
      expect(find.text('Ova sedmica'), findsNothing);

      await tester.tap(find.byTooltip('Sljedeća sedmica'));
      await tester.pumpAndSettle();
      expect(find.text('25. – 31. maj 2026'), findsOneWidget);

      // „Ova sedmica" ide na stvarni sat (`KalendarDatumNotifier.danas`), ne na fiksni
      // `sadaProvider` — zato se poredi sa sedmicom od `DateTime.now()`.
      await tester.tap(find.text('Ova sedmica'));
      await tester.pumpAndSettle();
      expect(
        find.text(naslovSedmice(pocetakSedmice(DateTime.now()))),
        findsOneWidget,
      );
    });

    testWidgets('termin otvara detalj', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      final blok = find.ancestor(
        of: find.text('Adnan Kovač'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(blok.first).onTap, isNotNull);
    });

    testWidgets('tap na prazno nudi ručni termin za taj dan i pola sata', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      // Blok 09:00–10:00 u ponedjeljak: sat ispod njegovog vrha je 10:00, pa 50 px niže
      // (37 min) je 10:37 → 10:30.
      final blok = tester.getRect(
        find
            .ancestor(
              of: find.text('Adnan Kovač'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.tapAt(Offset(blok.center.dx, blok.top + kVisinaSata + 50));
      await tester.pumpAndSettle();

      expect(find.text('forma date=2026-05-18&time=10%3A30'), findsOneWidget);
    });
  });

  group('radnik', () {
    testWidgets('vidi samo svoje termine, bez čipova i bez ručnog termina', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran(radnikIzUloge: 'e1'));

      expect(find.text('Adnan Kovač'), findsOneWidget);
      expect(find.text('Ajdin Softić'), findsOneWidget);
      expect(find.text('Kenan Zukić'), findsNothing);
      expect(find.text('Svi'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      // Njegova smjena: četvrtak ne radi, pa nema reda odsutnih.
      expect(find.text('Emir Bešić ne radi'), findsNothing);

      // Prazno mjesto ne vodi nikud — ručno zakazivanje traži `is_admin`.
      final blok = tester.getRect(
        find
            .ancestor(
              of: find.text('Adnan Kovač'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.tapAt(Offset(blok.center.dx, blok.top + kVisinaSata + 50));
      await tester.pumpAndSettle();
      expect(find.textContaining('forma'), findsNothing);
    });

    testWidgets('na telefonu lista bez čipova, samo njegovi termini', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran(radnikIzUloge: 'e2'));

      expect(find.text('Kenan Zukić'), findsOneWidget);
      expect(find.text('Adnan Kovač'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('tablet `7c`', () {
    testWidgets('sedam kolona bez vodoravnog skrola, podnaslov u dva reda', (
      tester,
    ) async {
      await _naSirini(tester, _tablet, _ekran());

      expect(find.text('NED'), findsOneWidget);
      expect(tester.getRect(find.text('NED')).right, lessThan(1024));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal &&
              w.child is! Row,
        ),
        findsNothing,
      );
      expect(find.text('09:00–20:00'), findsNWidgets(5));
      expect(find.text('1 termin'), findsNWidgets(4));
    });
  });

  group('telefon `7b`', () {
    testWidgets('„Dan" je podrazumijevan, „Sedmica" daje listu po danima', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran(prikaz: KalendarPrikaz.dan));
      expect(find.text('PON 18.'), findsNothing);

      await tester.tap(find.text('Sedmica'));
      await tester.pumpAndSettle();

      expect(find.text('PON 18.'), findsOneWidget);
      expect(find.text('UTO 19.'), findsOneWidget);
      expect(find.text('Adnan Kovač'), findsOneWidget);
      expect(find.text('09:00–10:00'), findsWidgets);
    });

    testWidgets('red odsutnih, blokada u jednom redu i neradna nedjelja', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Vedad 12:00–13:00 · Doktor'), findsOneWidget);
      // Čipovi su takođe `Scrollable`; skrola se lista.
      final lista = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('12:00–13:00 · Salon zatvoren · sastanak'),
        200,
        scrollable: lista,
      );
      expect(
        find.text('12:00–13:00 · Salon zatvoren · sastanak'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('NED 24.'),
        200,
        scrollable: lista,
      );
      expect(find.text('Ne radi'), findsOneWidget);
    });

    testWidgets('tap na dan otvara taj dan', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      await tester.tap(find.text('UTO 19.'));
      await tester.pumpAndSettle();

      expect(find.text('UTO 19.'), findsNothing);
      expect(find.text('Kenan Zukić'), findsNothing);
    });

    testWidgets('sedmica bez ičega kaže da nema termina', (tester) async {
      await _naSirini(
        tester,
        _telefon,
        _ekran(termini: const [], blokade: const []),
      );

      expect(find.text('Nema termina ove sedmice.'), findsOneWidget);
    });
  });
}
