/// Radno vrijeme na dvije širine — `3h` i `3s`, plus uređivač blokade.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/working_hours/working_hours_providers.dart';
import 'package:admin/src/features/working_hours/working_hours_dialogs.dart';
import 'package:admin/src/features/working_hours/working_hours_screen.dart';
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

/// Pon–pet 09–20 sa pauzom 13–14, subota 08–18, nedjelja zatvorena — kao u `3h`.
List<WorkingHour> _raspored() => [
  for (var dan = 1; dan <= 5; dan++)
    WorkingHour(
      id: 'w$dan',
      salonId: _salonId,
      dayOfWeek: dan,
      startTime: const LocalTime(9, 0),
      endTime: const LocalTime(20, 0),
      breakStartTime: const LocalTime(13, 0),
      breakEndTime: const LocalTime(14, 0),
    ),
  const WorkingHour(
    id: 'w6',
    salonId: _salonId,
    dayOfWeek: 6,
    startTime: LocalTime(8, 0),
    endTime: LocalTime(18, 0),
  ),
  const WorkingHour(
    id: 'w7',
    salonId: _salonId,
    dayOfWeek: 7,
    startTime: LocalTime(9, 0),
    endTime: LocalTime(17, 0),
    isClosed: true,
  ),
];

final _blokada = BlockedSlot(
  id: 'b1',
  salonId: _salonId,
  date: const LocalDate(2026, 5, 27),
  startTime: const LocalTime(0, 0),
  endTime: const LocalTime(23, 59),
  reason: 'Kurban-bajram',
);

class _FakeWorkingHoursActions extends WorkingHoursActions {
  _FakeWorkingHoursActions(super.ref, this._konflikti);

  final List<ScheduleConflict> _konflikti;

  @override
  Future<List<ScheduleConflict>> konflikti(
    List<WorkingHoursInput> dani, {
    String? employeeId,
  }) async => _konflikti;

  @override
  Future<void> sacuvaj(
    List<WorkingHoursInput> dani, {
    String? employeeId,
  }) async {}
}

/// Termini koje `working_hours_conflicts` vrati kad se radno vrijeme suzi.
List<ScheduleConflict> _konflikti(int koliko) => [
  for (var i = 0; i < koliko; i++)
    ScheduleConflict(
      appointmentId: 'a$i',
      date: LocalDate(2026, 5, 4 + (i % 7)),
      startTime: const LocalTime(18, 30),
      endTime: const LocalTime(19, 15),
      customerName: 'Klijent $i',
      employeeName: 'Emir Besic',
      reason: 'Van radnog vremena',
    ),
];

/// Otvara `prikaziKonflikte` iz stvarnog `BuildContext`-a — isto kako ga zovu oba ulaza:
/// snimanje radnog vremena i snimanje blokade.
Future<void> _otvoriKonflikte(
  WidgetTester tester,
  List<ScheduleConflict> konflikti, {
  Size size = _desktop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAdminTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => prikaziKonflikte(context, konflikti),
              child: const Text('otvori'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('otvori'));
  await tester.pumpAndSettle();
}

Widget _screen({
  List<WorkingHour>? raspored,
  List<BlockedSlot> blokade = const [],
  List<ScheduleConflict> konflikti = const [],
  Object? greska,
  List<Employee> osoblje = const [],
  TextScaler? skala,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminSalonProvider.overrideWith((ref) async => _salon),
    pendingCountProvider.overrideWith((ref) async => 0),
    radnoVrijemeProvider.overrideWith((ref) async {
      if (greska != null) throw greska;
      return raspored ?? _raspored();
    }),
    buduceBlokadeProvider.overrideWith((ref) async => blokade),
    osobljeZaBlokadeProvider.overrideWith((ref) async => osoblje),
    workingHoursActionsProvider.overrideWith(
      (ref) => _FakeWorkingHoursActions(ref, konflikti),
    ),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: skala == null
        ? const AdminWorkingHoursScreen()
        : MediaQuery(
            data: MediaQueryData(textScaler: skala),
            child: const AdminWorkingHoursScreen(),
          ),
  ),
);

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

/// Sedam dana plus blokade ne stanu ni na `1440×900` ni na telefon, a `ListView` gradi
/// samo ono što je na ekranu. Bez ovoga test ne bi tvrdio da nedjelje nema — tvrdio bi
/// samo da nije vidljiva bez skrolanja, što je druga stvar.
Future<void> _doDna(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('+ Dodaj neradni dan'),
    find.byType(ListView),
    const Offset(0, -220),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop crta svih sedam dana, pauzu i zatvorenu nedjelju', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());

    expect(find.text('Kad je salon otvoren'), findsOneWidget);
    for (final dan in const [
      'Ponedjeljak',
      'Utorak',
      'Srijeda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedjelja',
    ]) {
      await tester.dragUntilVisible(
        find.text(dan),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text(dan), findsOneWidget, reason: '$dan mora biti u listi');
    }
    // Nedjelja je zatvorena, pa umjesto vremena stoji rijec.
    expect(find.text('Zatvoreno'), findsOneWidget);
    // Subota 08:00–18:00 je jedini dan sa tim pocetkom.
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
  });

  testWidgets('pauza stoji na svih pet radnih dana', (tester) async {
    await _pumpAt(tester, _desktop, _screen());

    // Broji se odozgo prema dolje, jer `ListView` gradi samo vidljivo: pet dana sa
    // pauzom su prvih pet redova, pa su svi u prvom ekranu ili odmah ispod.
    await tester.dragUntilVisible(
      find.text('Petak'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    // Pauza više nije u redu dana nego jedna pločica „Dnevne pauze" za cijeli salon;
    // pet dana sa istim vremenom se sažme u jedan opis.
    expect(find.text('Pauza'), findsOneWidget);
    expect(
      find.textContaining('13:00–14:00 · cijeli salon'),
      findsOneWidget,
    );
  });

  testWidgets('salon bez ijednog reda dobija sedam zatvorenih dana', (
    tester,
  ) async {
    // Prazna tabela nije „nije podeseno" nego „zatvoreno" — isto kako je cita
    // `get_available_slots`. Ekran i engine moraju vidjeti istu stvar.
    await _pumpAt(tester, _desktop, _screen(raspored: const []));
    // Zatvoren dan je niži red (nema vremena ni pauze), pa svih sedam stane bez skrolanja.
    await _doDna(tester);

    expect(find.text('Zatvoreno'), findsNWidgets(7));
    expect(find.text('Pauza'), findsNothing);
  });

  testWidgets('„Sačuvaj izmjene" je neaktivno dok se ništa nije promijenilo', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());

    final dugme = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SAČUVAJ IZMJENE'),
    );
    expect(
      dugme.onPressed,
      isNull,
      reason: 'neizmijenjena sedmica se ne snima',
    );
  });

  testWidgets('prekidač zatvara dan i aktivira snimanje', (tester) async {
    await _pumpAt(tester, _desktop, _screen());

    // Prvi prekidač je ponedjeljkov. U dvije kolone `3h` cijela sedmica stane u ekran,
    // pa se vidi i nedjelja — jedini zatvoren dan u fixtureu.
    expect(find.text('Zatvoreno'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    // Ponedjeljak je sada zatvoren uz nedjelju.
    expect(find.text('Zatvoreno'), findsNWidgets(2));
    final dugme = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SAČUVAJ IZMJENE'),
    );
    expect(
      dugme.onPressed,
      isNotNull,
      reason: 'izmijenjena sedmica se može snimiti',
    );
  });

  testWidgets('telefon `3s` nema desktop naslov, ali ima sve dane', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    expect(find.text('Ponedjeljak'), findsOneWidget);
    await _doDna(tester);
    expect(find.text('Nedjelja'), findsOneWidget);
    // Red dana na telefonu piše vrijeme u jednom tekstu (subota je jedina 08–18).
    expect(find.text('08:00 – 18:00'), findsOneWidget);
    // Dugme je u traci na dnu, van liste — vidi se i bez skrolanja.
    expect(find.text('SAČUVAJ IZMJENE'), findsOneWidget);
  });

  testWidgets('blokade se prikazuju sa razlogom i datumom', (tester) async {
    await _pumpAt(tester, _desktop, _screen(blokade: [_blokada]));
    await _doDna(tester);

    expect(find.text('Kurban-bajram'), findsOneWidget);
    // Kratki datum iz `3h`: „27.05." (godina se dopisuje samo kad nije tekuća).
    expect(find.textContaining('27.05.'), findsOneWidget);
    expect(find.textContaining('salon zatvoren'), findsOneWidget);
  });

  testWidgets('bez blokada stoji prazno stanje, ne prazna lista', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());
    await _doDna(tester);

    expect(find.text('Nema zakazanih neradnih dana.'), findsOneWidget);
    expect(find.text('+ Dodaj neradni dan'), findsOneWidget);
  });

  testWidgets('greška u čitanju nudi ponovni pokušaj', (tester) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(greska: const ServerError('pao upit')),
    );

    expect(find.text('Radno vrijeme se ne može učitati.'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  // Tri regresije iz pregleda ekrana (task 34). Sve tri su reprodukovane prije popravke.

  testWidgets('poslije snimanja sa sedam redova dugme se gasi', (tester) async {
    // Prvi prolaz je stanje resetovao kroz `ValueKey(sve.length)`, a `weekFromWorkingHours`
    // uvijek vraca sedam — kljuc je bio isti prije i poslije snimanja, pa se `_dani` nikad
    // nije osvjezio. Radilo je samo u prelazu 0 → 7, koji je jedini bio pokriven.
    await _pumpAt(tester, _desktop, _screen());

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'SAČUVAJ IZMJENE'),
          )
          .onPressed,
      isNotNull,
    );

    // Isto sto radi `sacuvaj()` poslije uspjesnog upisa.
    final element = tester.element(find.byType(AdminWorkingHoursScreen));
    ProviderScope.containerOf(element).invalidate(radnoVrijemeProvider);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'SAČUVAJ IZMJENE'),
          )
          .onPressed,
      isNull,
      reason: 'svježa sedmica iz baze mora ugasiti dugme',
    );
  });

  testWidgets('uvecan sistemski font ne preliva telefon', (tester) async {
    // Popravka za sirinu (vremena ispod imena) nije pokrivala skalu teksta: red dana je
    // prelivao 82 px, a red vremena 44 px na skali 2.0.
    await _pumpAt(
      tester,
      _telefon,
      _screen(skala: const TextScaler.linear(2.0)),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dugo ime radnika ne preliva dropdown blokade', (tester) async {
    await _pumpAt(
      tester,
      _telefon,
      _screen(
        osoblje: const [
          Employee(
            id: 'e1',
            salonId: _salonId,
            name: 'Amar Hadziabdic-Mehmedagic iz Travnika',
          ),
        ],
      ),
    );
    await _doDna(tester);
    await tester.tap(find.text('+ Dodaj neradni dan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('„Dodaj pauzu" je jedno dugme u kartici pauza', (tester) async {
    // Pauza je sada sekcija za cijeli salon, ne kolona u redu dana: dugme stoji jednom,
    // ispod pločica, bez obzira koliko dana nema pauzu.
    await _pumpAt(tester, _desktop, _screen());

    expect(find.text('+ Dodaj pauzu'), findsOneWidget);
  });

  // --- Dijalog konflikata (task 38) ---

  testWidgets('snimanje sa konfliktom otvori dijalog umjesto da obori layout', (
    tester,
  ) async {
    // Regresija za task 38. `AlertDialog` mjeri sadrzaj kroz `IntrinsicWidth`, a viewport
    // intrinsicne dimenzije ne podrzava, pa je „Sacuvaj" sa ijednim konfliktom rusio
    // ekran u `performLayout()` — izvan svakog `try/catch`, jer to nije greska poziva
    // nego crtanja. Jedan konflikt je dovoljan: dijalog se otvara samo kad lista nije
    // prazna, zbog cega demo ulaz bez termina ovo nikad nije pogodio.
    await _pumpAt(tester, _desktop, _screen(konflikti: _konflikti(1)));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAČUVAJ IZMJENE'));
    // Dugme pokazuje indeterminate spinner dok dijalog čeka odgovor, pa se animacija
    // namjerno ne može `settle`-ovati. Dva framea su dovoljna da se dijalog izgradi.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Jedan zakazan termin'), findsOneWidget);
    expect(find.text('SAČUVAJ IPAK'), findsOneWidget);
  });

  testWidgets('duga lista konflikata se skrola umjesto da se prelije', (
    tester,
  ) async {
    // Telefon je uza strana: 40 termina ne stane, pa dijalog mora skrolati. Bez ovoga bi
    // popravka koja samo makne viewport prosla, a vratila preliv koji je task 34 vec
    // jednom placao.
    await _otvoriKonflikte(tester, _konflikti(40), size: _telefon);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('40 zakazanih termina'), findsOneWidget);

    final zadnji = find.text(
      'Klijent 39 \u00b7 Emir Besic \u00b7 Van radnog vremena',
    );
    await tester.scrollUntilVisible(
      zadnji,
      -220,
      scrollable: find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(zadnji, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
