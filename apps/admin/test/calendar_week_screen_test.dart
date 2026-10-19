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
import 'package:admin/src/core/widgets/admin_scaffold.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/calendar/calendar_day.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/calendar/calendar_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  List<WorkingHour>? radnoVrijeme,
  DateTime? sada,
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
      kalendarRadnoVrijemeProvider.overrideWith(
        (ref) async => radnoVrijeme ?? _radnoVrijeme,
      ),
      // Dnevni prikaz, kad se na njega pređe iz sedmice.
      kalendarTerminiProvider.overrideWith((ref) async => const []),
      kalendarBlokadeProvider.overrideWith((ref) async => const []),
      sadaProvider.overrideWith((ref) => Stream.value(sada ?? _sada)),
      kalendarDatumProvider.overrideWith(() => _FiksniDatum(_ponedjeljak)),
      kalendarPrikazProvider.overrideWith(() => _FiksniPrikaz(prikaz)),
    ],
    child: MaterialApp.router(
      theme: buildAdminTheme(),
      routerConfig: router,
      // Sidebar crta `AppShell`, kojeg ovdje nema. Bez ovog mjesta ekran bi na 1024 imao
      // kolone od ~135 px umjesto ~102 i mjerio raspored koji korisnik nikad ne vidi —
      // tablet je u prvoj verziji testa zato prolazio sa odsječenim natpisima.
      builder: (context, child) => AdminShell.jeDesktop(context)
          ? Row(
              children: [
                const SizedBox(width: AdminSize.sidebarWidth),
                Expanded(child: child!),
              ],
            )
          : child!,
    ),
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

/// Gusta sedmica: kratki termini u dvije i tri trake — ono zbog čega blok bira sadržaj.
final _gusto = [
  for (final (i, r) in ['e1', 'e2', 'e3'].indexed)
    _termin('Gust $i', dan: 0, od: 10 * 60, doMinuta: 10 * 60 + 30, radnik: r),
  for (final (i, r) in ['e1', 'e2'].indexed)
    _termin('Par $i', dan: 1, od: 10 * 60 + 30, doMinuta: 11 * 60, radnik: r),
  _termin('Sam', dan: 3, od: 14 * 60, doMinuta: 15 * 60, radnik: 'e3'),
  for (final (i, r) in ['e1', 'e2'].indexed)
    _termin(
      'Dug par $i',
      dan: 2,
      od: 10 * 60,
      doMinuta: 11 * 60 + 30,
      radnik: r,
    ),
];

/// Nijedno vrijeme (`10:30`) u bloku nije odsječeno: ili stane cijelo, ili ga nema.
///
/// Odsječeno vrijeme je pogrešno vrijeme — „10" umjesto „10:30" (pregled #137). Radi i sa
/// test fontom, jer blok mjeri vrijeme istim stilom kojim ga crta. Oznake sati na osi se
/// preskaču: osa ima svoju širinu, a test font je širi od Barlowa.
void _vremenaCijela(WidgetTester tester) {
  final oblik = RegExp(r'^\d\d:\d\d$');
  final pocetakKolona = tester.getRect(find.text('PON')).left - 20;
  var provjereno = 0;
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final tekst = p.text.toPlainText();
    if (!oblik.hasMatch(tekst)) continue;
    if (p.localToGlobal(Offset.zero).dx < pocetakKolona) continue;
    provjereno++;
    expect(
      p.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(p.size.width + 0.5),
      reason: '„$tekst" je odsječen na ${p.size.width.toStringAsFixed(1)} px',
    );
  }
  expect(
    provjereno,
    greaterThan(0),
    reason: 'nijedno vrijeme nije ni nacrtano',
  );
}

/// Tačka u praznom dijelu kolone dana [indeks] (0 = ponedjeljak), u [minuta] sata.
Offset _uKoloni(WidgetTester tester, int indeks, int minuta) {
  final zaglavlje = tester.getRect(
    find.text(['PON', 'UTO', 'SRI', 'ČET', 'PET', 'SUB', 'NED'][indeks]),
  );
  // Blok „Adnan Kovač" počinje u 09:00 — njegov vrh je linija tog sata.
  final devet = tester
      .getRect(
        find
            .ancestor(
              of: find.text('Adnan Kovač'),
              matching: find.byType(InkWell),
            )
            .first,
      )
      .top;
  return Offset(
    zaglavlje.left + 20,
    devet + (minuta - 9 * 60) / 60 * kVisinaSata,
  );
}

void main() {
  pristupacnostEkrana('Kalendar — sedmica', _ekran, tablet: true);

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
        // Jedan red ili dva zavisi od fonta (v. grupu „mjere u Barlowu").
        expect(find.textContaining('1 termin'), findsNWidgets(4));
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

      // Čipovi su red koji skrola kad ne stanu; test font je širi od Barlowa.
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Vedad'));
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
      expect(find.textContaining('09:00–20:00'), findsNWidgets(5));
      expect(find.textContaining('1 termin'), findsNWidgets(4));
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

  group('pregled #137', () {
    testWidgets('dugmad sedmice čitač ekrana može pritisnuti', (tester) async {
      final semantika = tester.ensureSemantics();
      await _naSirini(tester, _desktop, _ekran());

      final ocekivano = isSemantics(
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Adnan Kovač'))),
        ocekivano,
        reason: 'blok termina',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('19.*otvori dan'))),
        ocekivano,
        reason: 'zaglavlje dana',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Dan')),
        ocekivano,
        reason: 'segment prekidača',
      );
      // Danas se kaže riječima, ne samo bojom.
      expect(
        find.bySemanticsLabel(RegExp('danas.*otvori dan')),
        findsOneWidget,
      );
      semantika.dispose();
    });

    testWidgets('prekidač: meta 44 px, „Uskoro" se vidi bez hovera', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      final segment = find.ancestor(
        of: find.text('Sedmica'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(segment.first).height, greaterThanOrEqualTo(44));
      expect(find.text('Uskoro'), findsOneWidget);

      // Tablet: onemogućen „Mjesec" se sklanja, da top bar ne prelije.
      await _naSirini(tester, _tablet, _ekran());
      expect(find.text('Mjesec'), findsNothing);
      expect(find.text('Sedmica'), findsOneWidget);
    });

    testWidgets('prošli dan ne nudi termin, današnji i budući nude', (
      tester,
    ) async {
      // Srijeda 20. maj u 13:00.
      await _naSirini(
        tester,
        _desktop,
        _ekran(sada: DateTime(2026, 5, 20, 13)),
      );

      // 11:00 je u vidljivom dijelu mreže na 900 px; 17:00 bi bio ispod i tap ne bi
      // pogodio ništa — pa bi i „ne nudi" prošao bez ikakve provjere.
      await tester.tapAt(_uKoloni(tester, 0, 11 * 60));
      await tester.pumpAndSettle();
      expect(find.textContaining('forma'), findsNothing, reason: 'ponedjeljak');

      await tester.tapAt(_uKoloni(tester, 3, 11 * 60));
      await tester.pumpAndSettle();
      expect(
        find.text('forma date=2026-05-21&time=11%3A00'),
        findsOneWidget,
        reason: 'četvrtak',
      );
    });

    testWidgets('šrafura „Ne radi" ne nudi termin', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // Nedjelja je cijela neradna, subota od 15:00. Kontrola: isti tap u subotu prije
      // zatvaranja otvara formu — inače bi „ne nudi" prolazio i za tap pored mreže.
      await tester.tapAt(_uKoloni(tester, 6, 11 * 60));
      await tester.tapAt(_uKoloni(tester, 5, 15 * 60 + 30));
      await tester.pumpAndSettle();
      expect(find.textContaining('forma'), findsNothing);

      await tester.tapAt(_uKoloni(tester, 5, 11 * 60));
      await tester.pumpAndSettle();
      expect(find.text('forma date=2026-05-23&time=11%3A00'), findsOneWidget);
    });

    testWidgets('linija „sada" stoji samo u današnjoj koloni', (tester) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(sada: DateTime(2026, 5, 21, 11)),
      );

      final linija = tester.getRect(find.byKey(kLinijaSadaSedmice));
      final cetvrtak = tester.getRect(find.text('ČET'));
      final petak = tester.getRect(find.text('PET'));
      expect(linija.left, lessThanOrEqualTo(cetvrtak.left));
      expect(linija.right, lessThanOrEqualTo(petak.left));
      expect(linija.width, greaterThan(50));
    });

    testWidgets('druga sedmica nema liniju „sada"', (tester) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(sada: DateTime(2026, 5, 27, 11)),
      );
      expect(find.byKey(kLinijaSadaSedmice), findsNothing);
    });

    testWidgets('telefon: salon sa pauzom i bez termina kaže da nema termina', (
      tester,
    ) async {
      await _naSirini(
        tester,
        _telefon,
        _ekran(
          termini: const [],
          blokade: const [],
          radnoVrijeme: [
            for (var d = 1; d <= 6; d++)
              WorkingHour(
                id: 'wh-$d',
                salonId: _salonId,
                dayOfWeek: d,
                startTime: const LocalTime(9, 0),
                endTime: const LocalTime(17, 0),
                breakStartTime: const LocalTime(12, 0),
                breakEndTime: const LocalTime(12, 30),
              ),
          ],
        ),
      );

      expect(find.text('Nema termina ove sedmice.'), findsOneWidget);
    });
  });

  // **Zadnja grupa u fajlu, i to je namjerno.** Mjeri tekst u pravom Barlowu: test font
  // crta svaki znak kao kvadrat, pa „10:30" ne stane ni u jedan blok, a „Ne radi od 15:00"
  // traži 244 px umjesto ~100 — mjerilo bi se nešto što korisnik nikad ne vidi. Font
  // ostaje učitan do kraja izolata, pa grupe poslije ove ne bi mjerile istim fontom kao
  // one prije.
  group('mjere u Barlowu (pregled #137)', () {
    setUpAll(() async {
      final barlow = FontLoader('Barlow');
      for (final tezina in ['Regular', 'Medium', 'SemiBold']) {
        barlow.addFont(rootBundle.load('assets/fonts/Barlow-$tezina.ttf'));
      }
      await barlow.load();
    });

    for (final (ime, velicina) in [
      ('desktop', _desktop),
      ('tablet', _tablet),
    ]) {
      testWidgets('$ime: vrijeme u bloku je cijelo ili ga nema', (
        tester,
      ) async {
        await _naSirini(tester, velicina, _ekran(termini: _gusto));
        _vremenaCijela(tester);
      });

      testWidgets('$ime: i na fontu 130 %', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _naSirini(tester, velicina, _ekran(termini: _gusto));
        _vremenaCijela(tester);
      });
    }

    // Na 1440 je kolona ~161 px, a `09:00–20:00 · 0 termina` traži ~150 uz 12 px
    // paddinga — dva reda su tačna; jedan red dobija tek širi ekran. Pravilo nije broj
    // redova nego da se podnaslov nigdje ne reže.
    for (final (ime, velicina) in [
      ('desktop', _desktop),
      ('tablet', _tablet),
    ]) {
      testWidgets('$ime: podnaslov zaglavlja se ne reže', (tester) async {
        await _naSirini(tester, velicina, _ekran());
        final podnaslovi = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              RegExp(r'^(09:00–\d\d:00|\d+ termin|Ne radi)')
                  .hasMatch(w.data ?? ''),
        );
        expect(podnaslovi, findsWidgets);
        for (final e in podnaslovi.evaluate()) {
          final p = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(RichText),
            ),
          );
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
        }
      });
    }

    testWidgets('tablet: neradni natpis i blokada se lome, ne režu', (
      tester,
    ) async {
      await _naSirini(tester, _tablet, _ekran());

      for (final tekst in ['Ne radi od 15:00', 'Salon zatvoren · sastanak']) {
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(tekst),
            matching: find.byType(RichText),
          ),
        );
        expect(p.didExceedMaxLines, isFalse, reason: tekst);
      }
    });
  });
}
