/// Kalendar dana na dvije širine — prikazi `3c` (desktop) i `3l` (telefon).
///
/// Isti ekran, isti podaci, ista `AdminCalendarScreen`; mijenja se samo širina prozora.
/// Dva odvojena widgeta za dva rasporeda bi prolazila i kad bi kalendar imao dva stabla, a
/// upravo to sprint zabranjuje.
///
/// **Vrijeme je fiksirano na svim mjestima.** Dan je ponedjeljak 18. maj 2026, a `sada`
/// dolazi kroz `sadaProvider`, koji je zato i stream — bez toga bi ovaj fajl bio zelen
/// samo u dijelu dana, što je greška koju je task 17 već našao tri puta.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/calendar/calendar_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const Size _desktop = Size(1440, 900);
const Size _telefon = Size(402, 874);

/// Ponedjeljak, 18. maj 2026 — dan koji crta canvas.
final _dan = DateTime(2026, 5, 18);

/// 13:00 istog dana, tačno kao linija „sada" u canvasu.
final _sada = DateTime(2026, 5, 18, 13);

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
    durationMinutes: 60,
  ),
];

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir'),
  Employee(id: 'e2', salonId: _salonId, name: 'Amar'),
];

Appointment _termin({
  required String ime,
  required int od,
  required int doMinuta,
  String? radnik = 'e1',
  AppointmentStatus status = AppointmentStatus.confirmed,
}) => Appointment(
  id: 'a-$ime',
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: ime,
  date: LocalDate(_dan.year, _dan.month, _dan.day),
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
  status: status,
);

/// Ponedjeljak: salon 09–17, Amar 12–20 sa pauzom.
final _radnoVrijeme = [
  WorkingHour(
    id: 'wh-salon',
    salonId: _salonId,
    dayOfWeek: 1,
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(17, 0),
  ),
  WorkingHour(
    id: 'wh-amar',
    salonId: _salonId,
    employeeId: 'e2',
    dayOfWeek: 1,
    startTime: const LocalTime(12, 0),
    endTime: const LocalTime(20, 0),
    breakStartTime: const LocalTime(15, 0),
    breakEndTime: const LocalTime(15, 40),
  ),
];

final _termini = [
  _termin(ime: 'Mirza Aliagić', od: 11 * 60, doMinuta: 12 * 60 + 20),
  _termin(ime: 'Tarik Selimović', od: 13 * 60, doMinuta: 14 * 60 + 20),
  _termin(
    ime: 'Nedim Hodžić',
    od: 15 * 60,
    doMinuta: 16 * 60 + 20,
    radnik: 'e2',
    status: AppointmentStatus.pending,
  ),
];

final _blokade = [
  BlockedSlot(
    id: 'b1',
    salonId: _salonId,
    date: LocalDate(_dan.year, _dan.month, _dan.day),
    startTime: const LocalTime(10, 0),
    endTime: const LocalTime(11, 0),
    reason: 'Inventura',
  ),
];

Widget _ekran({
  List<Appointment>? termini,
  List<WorkingHour>? radnoVrijeme,
  List<BlockedSlot>? blokade,
  List<Employee>? radnici,
  DateTime? sada,
  DateTime? dan,
}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminSalonProvider.overrideWith((ref) async => _salon),
    adminServicesProvider.overrideWith((ref) async => _usluge),
    adminEmployeesProvider.overrideWith((ref) async => radnici ?? _radnici),
    kalendarTerminiProvider.overrideWith((ref) async => termini ?? _termini),
    kalendarRadnoVrijemeProvider.overrideWith(
      (ref) async => radnoVrijeme ?? _radnoVrijeme,
    ),
    kalendarBlokadeProvider.overrideWith((ref) async => blokade ?? _blokade),
    // Bez ovoga bi `sadaProvider` vrtio `Stream.periodic` i test bi zavisio od sata.
    sadaProvider.overrideWith((ref) => Stream.value(sada ?? _sada)),
    kalendarDatumProvider.overrideWith(() => _FiksniDatum(dan ?? _dan)),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminCalendarScreen(),
  ),
);

class _FiksniDatum extends KalendarDatumNotifier {
  _FiksniDatum(this._pocetni);

  final DateTime _pocetni;

  @override
  DateTime build() => _pocetni;
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
  group('desktop `3c`', () {
    testWidgets('kolona po radniku, sa smjenom i brojem termina', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Emir'), findsOneWidget);
      expect(find.text('Amar'), findsOneWidget);
      // Emir: salonski raspored i dva termina. Amar: svoj raspored i jedan.
      expect(find.text('09:00–17:00 · 2 termina'), findsOneWidget);
      expect(find.text('12:00–20:00 · 1 termin'), findsOneWidget);
    });

    testWidgets('vremenska osa pokriva i smjenu koja traje duže', (
      tester,
    ) async {
      // Amar radi do 20:00, pa osa mora ići dotle iako salon zatvara u 17:00.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('09:00'), findsWidgets);
      expect(find.text('19:00'), findsOneWidget);
    });

    testWidgets('termin je blok sa imenom i rasponom vremena', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Mirza Aliagić'), findsOneWidget);
      expect(find.text('11:00–12:20 · Fade šišanje'), findsOneWidget);
    });

    testWidgets('pauza, blokada i neradno vrijeme se vide kao pojasevi', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      // Pauza je Amarova, blokada salonska pa stoji u obje kolone, a Amar do 12:00 ne radi.
      expect(find.text('Pauza'), findsOneWidget);
      expect(find.text('Inventura'), findsNWidgets(2));
      expect(find.text('Ne radi do 12:00'), findsOneWidget);
      expect(find.text('Ne radi od 17:00'), findsOneWidget);
    });

    testWidgets('linija „sada" nosi vrijeme i stoji samo za današnji dan', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());
      expect(find.text('13:00'), findsWidgets);

      // Isti ekran za sutra: linije nema, jer bi tvrdila da je sutra sad.
      await _naSirini(
        tester,
        _desktop,
        _ekran(dan: DateTime(2026, 5, 19), termini: const []),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('zaglavlje dana ima strelice i datum', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Ponedjeljak, 18. maj'), findsOneWidget);
      expect(find.byTooltip('Prethodni dan'), findsOneWidget);
      expect(find.byTooltip('Sljedeći dan'), findsOneWidget);
    });

    testWidgets('strelica pomjera dan i mijenja naslov', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      await tester.tap(find.byTooltip('Sljedeći dan'));
      await tester.pumpAndSettle();

      expect(find.text('Utorak, 19. maj'), findsOneWidget);
      // Dan koji nije današnji nudi povratak — na današnjem bi dugme bilo bez učinka.
      // `widgetWithText`, ne `find.text`: sidebar nosi ćeliju „Danas" sa istim tekstom.
      expect(find.widgetWithText(TextButton, 'Danas'), findsOneWidget);
    });

    testWidgets('legenda objašnjava i otkazan termin, koji canvas ne crta', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Potvrđeno'), findsOneWidget);
      expect(find.text('Čeka potvrdu'), findsOneWidget);
      expect(find.text('Završeno'), findsOneWidget);
      expect(find.text('Otkazano'), findsOneWidget);
      expect(find.text('U toku'), findsOneWidget);
    });

    testWidgets('akcije koje nemaju RPC putanju nisu nacrtane', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // Prekidač prikaza i dvije radnje nad radnim vremenom traže task 34, odnosno
      // sedmični i mjesečni prikaz kojih ovaj task nema.
      expect(find.text('Sedmica'), findsNothing);
      expect(find.text('Mjesec'), findsNothing);
      expect(find.text('Dodaj pauzu'), findsNothing);
      expect(find.text('Zatvori dan'), findsNothing);
      // „Blokiraj vrijeme" ostaje: ruta postoji i vodi u ljusku.
      expect(find.text('Blokiraj vrijeme'), findsWidgets);
    });

    testWidgets('salon bez radnika kaže zašto nema kolona', (tester) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(radnici: const [], termini: const [], blokade: const []),
      );

      expect(
        find.textContaining('nema nijednog radnika'),
        findsOneWidget,
      );
    });
  });

  group('telefon `3l`', () {
    testWidgets('lista po vremenu, ne stisnuta mreža', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      // Mreža ima zaglavlja kolona sa smjenom; lista ih nema.
      expect(find.text('09:00–17:00 · 2 termina'), findsNothing);
      expect(find.text('Mirza Aliagić'), findsOneWidget);
      expect(find.text('11:00'), findsWidgets);
    });

    testWidgets('velik naslov u tijelu, bez AppBar naslova iznad njega', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Kalendar'), findsWidgets);
      expect(find.text('Ponedjeljak, 18. maj'), findsOneWidget);
    });

    testWidgets('traka dana nosi sedmicu izabranog dana', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('PON'), findsOneWidget);
      expect(find.text('NED'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('tap na dan u traci mijenja prikazani dan', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();

      expect(find.text('Utorak, 19. maj'), findsOneWidget);
    });

    testWidgets('chip traka bira radnika i tada se vidi njegova pauza', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Svi'), findsOneWidget);
      await tester.tap(find.text('Amar').first);
      await tester.pumpAndSettle();

      // Amarova lista: pauza i njegov termin, bez Emirovih.
      expect(find.text('Pauza'), findsOneWidget);
      expect(find.text('Nedim Hodžić'), findsOneWidget);
      expect(find.text('Mirza Aliagić'), findsNothing);
    });

    testWidgets('lista jednog radnika nudi slobodne rupe, „Svi" ne', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      // „Slobodno" preko cijelog salona bi bilo izmišljeno kad radi više ljudi.
      expect(find.textContaining('Slobodno'), findsNothing);

      await tester.tap(find.text('Amar').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Slobodno'), findsWidgets);
    });

    testWidgets('salonska blokada se u listi „Svi" pojavljuje jednom', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Inventura'), findsOneWidget);
    });

    testWidgets('traka u dnu nosi novi termin i blokadu', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('+ Novi termin'), findsOneWidget);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });

    testWidgets('dugme „+ Novi termin" ide preko cijele širine', (
      tester,
    ) async {
      // Task 30 je istu grešku našao na prijavi: dugme široko koliko i njegov tekst,
      // nasred ekrana, izgleda kao da je layout pukao.
      await _naSirini(tester, _telefon, _ekran());

      final sirina = tester
          .getSize(
            find.ancestor(
              of: find.text('+ Novi termin'),
              matching: find.byType(FilledButton),
            ),
          )
          .width;
      expect(sirina, greaterThan(_telefon.width - 120));
    });
  });

  group('prazna stanja', () {
    testWidgets('neradni dan kaže da se ne radi, a ne da nema termina', (
      tester,
    ) async {
      // Nedjelja: salon zatvoren. „Nema termina" bi zvučalo kao da je dan slobodan.
      await _naSirini(
        tester,
        _telefon,
        _ekran(
          dan: DateTime(2026, 5, 17),
          termini: const [],
          blokade: const [],
          radnoVrijeme: [
            WorkingHour(
              id: 'wh-ned',
              salonId: _salonId,
              dayOfWeek: 7,
              startTime: const LocalTime(9, 0),
              endTime: const LocalTime(17, 0),
              isClosed: true,
            ),
          ],
        ),
      );

      expect(find.text('Ovaj dan se ne radi.'), findsOneWidget);
    });

    testWidgets('radni dan bez ijednog zauzeća kaže da nema termina', (
      tester,
    ) async {
      // Bez pauze u rasporedu: pauza je zauzeće i lista sa njom **nije** prazna, što je i
      // ispravno — prvi pokušaj ovog testa je pao upravo na tome.
      await _naSirini(
        tester,
        _telefon,
        _ekran(
          termini: const [],
          blokade: const [],
          radnoVrijeme: [_radnoVrijeme.first],
        ),
      );

      expect(
        find.text('Nema zakazanih termina za ovaj dan.'),
        findsOneWidget,
      );
    });
  });

  group('termin vodi na detalj', () {
    testWidgets('blok u mreži ima ulaz u `/appointments/:id`', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // `InkWell` nad blokom je jedini put do detalja; bez njega je raspored slika.
      final blok = find.ancestor(
        of: find.text('Mirza Aliagić'),
        matching: find.byType(InkWell),
      );
      expect(blok, findsWidgets);
      expect(tester.widget<InkWell>(blok.first).onTap, isNotNull);
    });

    testWidgets('isti ulaz postoji i u mobilnoj listi', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      final red = find.ancestor(
        of: find.text('Mirza Aliagić'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(red.first).onTap, isNotNull);
    });
  });
}
