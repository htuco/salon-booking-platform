/// „Danas" — `6a`–`6m` (task 55), vlasnik i radnik nad **istim** ekranom.
///
/// Sat je fiksan na 13:12 današnjeg dana (`sadaProvider`), pa testovi ne zavise od doba
/// dana. Akcije idu kroz lažni [AppointmentActions] koji bilježi pozive — tako se vidi da
/// potvrda ide u bazu tek kad istekne rok za „Poništi", a ne odmah.
library;

import 'dart:async';

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/admin_skeleton.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/appointments/odgodjene_akcije.dart';
import 'package:admin/src/features/calendar/calendar_screen.dart'
    show KalendarMrezaDana;
import 'package:admin/src/features/clients/clients_providers.dart';
import 'package:admin/src/features/dashboard/danas_providers.dart';
import 'package:admin/src/features/dashboard/dashboard_screen.dart';
import 'package:admin/src/features/dashboard/kontekst_panel.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const Size _desktop = Size(1440, 900);
const Size _siroki = Size(2560, 1440);
const Size _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Emir Besic',
  email: 'emir@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

const _radnik = StaffMember(
  id: '22222222-0000-4000-8000-000000000002',
  name: 'Vedad Radnik',
  email: 'vedad@primjer.test',
  role: 'employee',
  salonId: _salonId,
  employeeId: 'e2',
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

/// Danas u 13:12 — trenutak iz handoffa.
DateTime get _sada {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, 13, 12);
}

LocalDate get _danas => LocalDate(_sada.year, _sada.month, _sada.day);

Appointment _termin(
  String ime,
  int sat,
  int minuta, {
  int trajanje = 40,
  AppointmentStatus status = AppointmentStatus.confirmed,
  String usluga = 's1',
  String? radnik = 'e1',
  LocalDate? dan,
  int? poslanPrije,
}) {
  final kraj = sat * 60 + minuta + trajanje;
  return Appointment(
    id: 'a-$ime',
    salonId: _salonId,
    serviceId: usluga,
    employeeId: radnik,
    customerId: 'c-$ime',
    customerName: ime,
    date: dan ?? _danas,
    startTime: LocalTime(sat, minuta),
    endTime: LocalTime(kraj ~/ 60, kraj % 60),
    status: status,
    createdAt: poslanPrije == null
        ? null
        : _sada.subtract(Duration(minutes: poslanPrije)),
  );
}

final _nedim = _termin(
  'Nedim Hodžić',
  15,
  0,
  status: AppointmentStatus.pending,
  poslanPrije: 26,
);
final _almir = _termin(
  'Almir Šahić',
  17,
  0,
  trajanje: 30,
  status: AppointmentStatus.pending,
  radnik: 'e2',
  usluga: 's2',
  poslanPrije: 12,
);

/// Dan: dva prošla (završen i bez oznake), jedan u toku, dva koja dolaze, dva zahtjeva.
List<Appointment> get _dan => [
  _termin('Kemal Hadžić', 10, 0, status: AppointmentStatus.completed),
  _termin('Edin Ramić', 11, 20, trajanje: 30),
  _termin('Tarik Selimović', 12, 40, radnik: 'e2'),
  _termin('Haris Delić', 13, 30, trajanje: 30),
  _termin('Faruk Begić', 14, 30, radnik: 'e2'),
  _nedim,
  _almir,
];

List<WorkingHour> _raspored({bool salonZatvoren = false}) => [
  WorkingHour(
    id: 'wh-salon',
    salonId: _salonId,
    dayOfWeek: _sada.weekday,
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(20, 0),
    isClosed: salonZatvoren,
  ),
  // Sljedeći dan radi, da `6h` ima šta reći.
  WorkingHour(
    id: 'wh-salon-sutra',
    salonId: _salonId,
    dayOfWeek: _sada.weekday % 7 + 1,
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(20, 0),
  ),
  for (final (id, od, doSata) in const [('e1', 9, 17), ('e2', 10, 19)])
    WorkingHour(
      id: 'wh-$id',
      salonId: _salonId,
      employeeId: id,
      dayOfWeek: _sada.weekday,
      startTime: LocalTime(od, 0),
      endTime: LocalTime(doSata, 0),
      breakStartTime: const LocalTime(14, 0),
      breakEndTime: const LocalTime(14, 30),
    ),
];

/// Akcije koje samo bilježe — RPC se u testu ne zove.
class _LazneAkcije extends AppointmentActions {
  _LazneAkcije(super.ref, this.log);

  final List<String> log;

  @override
  Future<Appointment?> potvrdi(String appointmentId) async {
    log.add('potvrdi $appointmentId');
    return null;
  }

  @override
  Future<Appointment?> odbij(String appointmentId, {String? razlog}) async {
    log.add('odbij $appointmentId: $razlog');
    return null;
  }

  @override
  Future<Appointment?> zavrsen(String appointmentId) async {
    log.add('zavrsen $appointmentId');
    return null;
  }

  @override
  Future<Appointment?> nijeDosao(String appointmentId, {String? razlog}) async {
    log.add('nijeDosao $appointmentId');
    return null;
  }
}

/// Prikaz „Ostatak dana" fiksiran za test — većina testova gleda listu iz `6a`.
class _FiksanPrikaz extends PrikazDanaNotifier {
  _FiksanPrikaz(this.prikaz);

  final PrikazDana prikaz;

  @override
  PrikazDana build() => prikaz;
}

Widget _ekran({
  PrikazDana? prikaz = PrikazDana.lista,
  List<Appointment>? termini,
  List<Appointment>? zahtjevi,
  List<WorkingHour>? raspored,
  Object? greskaZahtjeva,
  Object? greskaTermina,
  bool terminiCekaju = false,
  StaffMember clan = _vlasnik,
  List<String>? log,
}) {
  final dan = termini ?? _dan;
  return ProviderScope(
    overrides: [
      sadaProvider.overrideWith((ref) => Stream.value(_sada)),
      currentStaffProvider.overrideWith(
        (ref) => Stream<StaffMember?>.value(clan),
      ),
      adminSalonProvider.overrideWith((ref) async => _salon),
      adminServicesProvider.overrideWith((ref) async => _usluge),
      adminEmployeesProvider.overrideWith((ref) async => _radnici),
      dashboardRasporedProvider.overrideWith(
        (ref) async => raspored ?? _raspored(),
      ),
      dashboardBlokadeProvider.overrideWith((ref) async => const []),
      sedmicaProvider.overrideWith((ref) async => 38),
      sljedeciRadniDanProvider.overrideWith(
        (ref) async => (
          dan: _sada.add(const Duration(days: 1)),
          otvara: const LocalTime(9, 0),
          termina: 16,
        ),
      ),
      danasnjiTerminiProvider.overrideWith((ref) async {
        // Completer koji se ne završi, ne `Future.delayed`: tajmer bi ostao viseći.
        if (terminiCekaju) await Completer<void>().future;
        if (greskaTermina != null) throw greskaTermina;
        final radnikId = ref.watch(adminRadnikIdProvider);
        return [
          for (final t in dan)
            if (radnikId == null || t.employeeId == radnikId) t,
        ];
      }),
      zahtjeviProvider.overrideWith((ref) async {
        if (greskaZahtjeva != null) throw greskaZahtjeva;
        final lista =
            zahtjevi ??
            dan.where((t) => t.status == AppointmentStatus.pending).toList();
        final radnikId = ref.watch(adminRadnikIdProvider);
        return [
          for (final t in lista)
            if (radnikId == null || t.employeeId == radnikId) t,
        ];
      }),
      pendingCountProvider.overrideWith((ref) async => 2),
      if (prikaz != null)
        prikazDanaProvider.overrideWith(() => _FiksanPrikaz(prikaz)),
      klijentProvider.overrideWith((ref, id) async => null),
      if (log != null)
        appointmentActionsProvider.overrideWith(
          (ref) => _LazneAkcije(ref, log),
        ),
    ],
    child: MaterialApp(
      theme: buildAdminTheme(),
      home: const AdminDashboardScreen(),
    ),
  );
}

Future<void> _naSirini(WidgetTester tester, Size velicina, Widget w) async {
  tester.view.physicalSize = velicina;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

/// Toast odbrojava 5 s i rok „Poništi" je isti — ovo ih pusti da isteknu.
Future<void> _pustiRok(WidgetTester tester) async {
  await tester.pump(kRokPonistavanja);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  pristupacnostEkrana('Danas', _ekran);

  group('vlasnik · desktop `6a`', () {
    testWidgets('naslov: datum, „U smjeni" i broj termina, bez padeža', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('U smjeni 2 · 7 termina'), findsOneWidget);
      expect(find.text('Otvoreno do 20:00'), findsOneWidget);
      expect(find.textContaining('majstor'), findsNothing);
    });

    testWidgets('redoslijed: zahtjevi, pa raspored; brojke sa strane', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      final zahtjevi = tester.getTopLeft(find.text('Zahtjevi na odobrenju'));
      final raspored = tester.getTopLeft(find.text('Ostatak dana'));
      final sljedeci = tester.getTopLeft(find.text('SLJEDEĆI'));
      expect(zahtjevi.dy, lessThan(raspored.dy));
      expect(sljedeci.dx, greaterThan(raspored.dx));
      expect(find.text('Naplaćeno'), findsOneWidget);
      expect(find.text('Zauzetost danas'), findsOneWidget);
    });

    testWidgets('zahtjevi po vremenu termina, sa „čeka X min"', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('najstariji prije 26 min'), findsOneWidget);
      expect(find.text('čeka 26 min'), findsOneWidget);
      final nedim = tester.getTopLeft(find.text('Nedim Hodžić').first);
      final almir = tester.getTopLeft(find.text('Almir Šahić').first);
      expect(nedim.dy, lessThan(almir.dy));
    });

    testWidgets('Sljedeći: prvi potvrđen koji dolazi, i ko je u toku', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.textContaining('za 18 min'), findsWidgets);
      expect(find.text('U TOKU'), findsOneWidget);
      expect(find.text('Tarik · Vedad'), findsOneWidget);
    });

    testWidgets('prognoza kaže koliko čeka potvrdu', (tester) async {
      await _naSirini(tester, _desktop, _ekran());
      // Nedim 20 + Almir 15 na čekanju.
      expect(find.text('od toga 35 KM čeka potvrdu'), findsOneWidget);
    });

    testWidgets('raspored: linija „Sad" i „Bez oznake" za prošli potvrđen', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Sad 13:12'), findsOneWidget);
      expect(find.text('Bez oznake'), findsOneWidget);
      expect(find.text('Edin Ramić — je li došao?'), findsOneWidget);
    });

    testWidgets('više od dva prošla se sklope u „Još N ranijih"', (
      tester,
    ) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(
          termini: [
            for (final (i, sat) in [8, 9, 10, 11].indexed)
              _termin('Prošli $i', sat, 0, status: AppointmentStatus.completed),
            _termin('Haris Delić', 14, 0),
          ],
        ),
      );

      expect(find.text('Još 2 ranija termina'), findsOneWidget);
      expect(find.text('Prošli 0'), findsNothing);
      await tester.tap(find.text('Prikaži'));
      await tester.pumpAndSettle();
      expect(find.text('Prošli 0'), findsOneWidget);
    });

    testWidgets('filter po radniku sužava raspored i crta njegove rupe', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.textContaining('Slobodno ·'), findsNothing);
      expect(find.text('Edin Ramić'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Vedad'));
      await tester.pumpAndSettle();
      // Edin je Emirov; „Haris" bi se i dalje vidio u kartici „Sljedeći".
      expect(find.text('Edin Ramić'), findsNothing);
      expect(find.textContaining('Slobodno ·'), findsWidgets);
      expect(find.text('Pauza · 30 min'), findsOneWidget);
    });

    testWidgets('top bar: Blokiraj vrijeme, Dodaj uslugu, Novi termin', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('Blokiraj vrijeme'), findsOneWidget);
      expect(find.text('Dodaj uslugu'), findsOneWidget);
      expect(find.text('+ NOVI TERMIN'), findsOneWidget);
    });
  });

  group('akcije sa „Poništi" (`6m`)', () {
    testWidgets(
      'potvrda: red nestaje odmah, a u bazu ide tek kad rok istekne',
      (tester) async {
        final log = <String>[];
        await _naSirini(tester, _desktop, _ekran(log: log));

        await tester.tap(find.text('POTVRDI').first);
        await tester.pump();
        expect(find.text('Zahtjev potvrđen'), findsOneWidget);
        expect(find.text('čeka 26 min'), findsNothing);
        expect(log, isEmpty, reason: 'RPC prije roka ne bi dao „Poništi"');

        await _pustiRok(tester);
        expect(log, ['potvrdi ${_nedim.id}']);
      },
    );

    testWidgets('„Poništi" vraća zahtjev i ništa ne ide u bazu', (
      tester,
    ) async {
      final log = <String>[];
      await _naSirini(tester, _desktop, _ekran(log: log));

      await tester.tap(find.text('POTVRDI').first);
      // Toast ulazi s desna 320 ms; jedan veliki `pump` ne prođe kroz animaciju.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('PONIŠTI'));
      await tester.pump();
      expect(find.text('čeka 26 min'), findsOneWidget);

      await _pustiRok(tester);
      expect(log, isEmpty);
    });

    testWidgets('„Završeno" iz bloka „je li došao?" ide istim tokom', (
      tester,
    ) async {
      final log = <String>[];
      await _naSirini(tester, _desktop, _ekran(log: log));

      await tester.tap(find.text('✓ Završeno'));
      await tester.pump();
      expect(find.text('Edin Ramić — je li došao?'), findsNothing);
      await _pustiRok(tester);
      expect(log, ['zavrsen a-Edin Ramić']);
    });

    testWidgets('aplikacija u pozadini upiše ono što čeka, bez čekanja roka', (
      tester,
    ) async {
      final log = <String>[];
      await _naSirini(tester, _desktop, _ekran(log: log));

      await tester.tap(find.text('POTVRDI').first);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(log, ['potvrdi ${_nedim.id}']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pustiRok(tester);
      expect(log, hasLength(1), reason: 'isti zahtjev se ne potvrđuje dvaput');
    });

    testWidgets('odbijanje pita za razlog (`6l`) i upisuje odmah', (
      tester,
    ) async {
      final log = <String>[];
      await _naSirini(tester, _desktop, _ekran(log: log));

      await tester.tap(find.text('Odbij').first);
      await tester.pumpAndSettle();
      expect(find.text('Odbiti zahtjev?'), findsOneWidget);
      expect(find.text('Razlog — čuva se uz termin'), findsOneWidget);

      await tester.tap(find.text('Odabrana osoba ne radi u to vrijeme'));
      await tester.tap(find.text('ODBIJ ZAHTJEV'));
      await tester.pumpAndSettle();
      expect(log, ['odbij ${_nedim.id}: Odabrana osoba ne radi u to vrijeme']);
      await _pustiRok(tester);
    });
  });

  group('stanja', () {
    testWidgets('`6i` bez zahtjeva: jedan tihi red', (tester) async {
      await _naSirini(tester, _desktop, _ekran(zahtjevi: const []));
      expect(find.text('Nema zahtjeva na čekanju'), findsOneWidget);
      expect(find.text('POTVRDI'), findsNothing);
    });

    testWidgets('`6j` puno zahtjeva: tri, pa „Još N" i masovna potvrda', (
      tester,
    ) async {
      final mnogo = [
        for (var i = 0; i < 12; i++)
          _termin(
            'Klijent $i',
            9 + i % 8,
            0,
            status: AppointmentStatus.pending,
            dan: LocalDate(_sada.year, _sada.month, _sada.day + 1 + i ~/ 8),
            poslanPrije: 10 + i,
          ),
      ];
      await _naSirini(tester, _desktop, _ekran(zahtjevi: mnogo));

      expect(find.text('POTVRDI'), findsNWidgets(3));
      expect(find.text('Još 9 zahtjeva'), findsOneWidget);
      expect(find.text('Potvrdi sve bez preklapanja'), findsOneWidget);
    });

    testWidgets('`6k` greška jednog bloka ne sakriva ostale', (tester) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(greskaZahtjeva: const NetworkError('pala veza')),
      );

      expect(find.text('Blok zahtjeva se nije učitao.'), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
      expect(find.text('Sad 13:12'), findsOneWidget);
    });

    testWidgets('`6f` učitavanje je skeleton, ne spinner', (tester) async {
      tester.view.physicalSize = _desktop;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_ekran(terminiCekaju: true));
      await tester.pump();

      expect(find.byType(AdminSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('`6g` prazan dan', (tester) async {
      await _naSirini(tester, _desktop, _ekran(termini: const []));
      expect(find.text('Danas nema termina.'), findsOneWidget);
      expect(find.text('nema termina'), findsOneWidget);
    });

    testWidgets('`6h` neradni dan: zahtjevi ostaju, pa sljedeći radni dan', (
      tester,
    ) async {
      await _naSirini(
        tester,
        _telefon,
        _ekran(
          termini: const [],
          zahtjevi: [
            _termin(
              'Nedim Hodžić',
              15,
              0,
              status: AppointmentStatus.pending,
              dan: LocalDate(_sada.year, _sada.month, _sada.day + 1),
            ),
          ],
          raspored: _raspored(salonZatvoren: true),
        ),
      );

      expect(find.text('Danas ne radimo'), findsOneWidget);
      expect(find.text('Nedim Hodžić'), findsOneWidget);
      expect(find.text('SLJEDEĆI RADNI DAN'), findsOneWidget);
      expect(find.text('16 termina'), findsOneWidget);
      expect(find.text('Ostatak dana'), findsNothing);
    });
  });

  group('kontekstni panel (`6b`)', () {
    testWidgets('na 2560 stoji uvijek i pokazuje prvi zahtjev', (tester) async {
      await _naSirini(tester, _siroki, _ekran());

      expect(find.byType(KontekstPanel), findsOneWidget);
      expect(find.text('ZAHTJEV · ČEKA 26 MIN'), findsOneWidget);
      expect(find.textContaining('je slobodan · Emir'), findsOneWidget);
    });

    testWidgets('na 1440 se otvara klikom na red, kao drawer', (tester) async {
      await _naSirini(tester, _desktop, _ekran());
      expect(find.byType(KontekstPanel), findsNothing);

      await tester.ensureVisible(find.text('Faruk Begić'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faruk Begić'));
      await tester.pumpAndSettle();
      expect(find.byType(KontekstPanel), findsOneWidget);
      expect(find.text('TERMIN · POTVRĐENO'), findsOneWidget);

      await tester.tap(find.byTooltip('Zatvori'));
      await tester.pumpAndSettle();
      expect(find.byType(KontekstPanel), findsNothing);
    });
  });

  group('vlasnik · telefon `6c`', () {
    testWidgets('jedan zahtjev otvoren, ostali iza „Još N"', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Zahtjevi · 2'), findsOneWidget);
      expect(find.text('Prihvati'), findsOneWidget);
      expect(find.text('Još 1 zahtjev'), findsOneWidget);
    });

    testWidgets('brojke dana su na dnu, a dodavanje u „Dodaj"', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      // Zaglavlje više ne nosi „+ Novi" ni „⋯": brze akcije su u donjoj navigaciji
      // `AppShell`-a (mobile-refresh), a brojke su sažetak na kraju dana, ne prvi red.
      expect(find.text('+ NOVI'), findsNothing);
      expect(find.byTooltip('Još radnji'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('naplaćeno'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('naplaćeno'), findsOneWidget);
      expect(find.text('prognoza'), findsOneWidget);
    });
  });

  group('radnik (`6d`, `6e`)', () {
    testWidgets('desktop: „Moj dan", bez prometa i vlasnikovih akcija', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran(clan: _radnik));

      expect(find.text('Moj dan'), findsOneWidget);
      expect(find.text('Smjena 10:00–19:00 · 3 termina'), findsOneWidget);
      expect(find.text('Moji termini'), findsOneWidget);
      expect(find.text('Naplaćeno'), findsNothing);
      expect(find.text('Zauzetost danas'), findsNothing);
      expect(find.text('Dodaj uslugu'), findsNothing);
      expect(find.text('+ NOVI TERMIN'), findsNothing);
      // Radnik vidi samo svoje.
      expect(find.text('Haris Delić'), findsNothing);
    });

    testWidgets('desktop: rupe i pauza iz njegove smjene', (tester) async {
      await _naSirini(tester, _desktop, _ekran(clan: _radnik));

      expect(find.text('Slobodno · 40 min'), findsOneWidget);
      expect(find.text('Pauza · 30 min'), findsOneWidget);
    });

    testWidgets('telefon: zauzetost umjesto prometa', (tester) async {
      await _naSirini(tester, _telefon, _ekran(clan: _radnik));

      await tester.scrollUntilVisible(
        find.text('zauzetost'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('zauzetost'), findsOneWidget);
      expect(find.text('naplaćeno'), findsNothing);
      expect(find.text('+ NOVI'), findsNothing);
    });
  });

  group('kalendar u „Ostatak dana"', () {
    testWidgets('desktop počinje mrežom kalendara, bez filtera radnika', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran(prikaz: null));

      expect(find.byType(KalendarMrezaDana), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Vedad'), findsNothing);
      expect(find.text('Lista'), findsOneWidget);
    });

    testWidgets('„Lista" vraća vremensku liniju iz `6a`', (tester) async {
      await _naSirini(tester, _desktop, _ekran(prikaz: null));

      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.byType(KalendarMrezaDana), findsNothing);
      expect(find.text('Sad 13:12'), findsOneWidget);
    });

    testWidgets('telefon ostaje lista', (tester) async {
      await _naSirini(tester, _telefon, _ekran(prikaz: null));

      expect(find.byType(KalendarMrezaDana), findsNothing);
      // „Kalendar" je i ćelija donje navigacije; prekidač se prepoznaje po ikoni.
      expect(find.byIcon(Icons.calendar_view_week_outlined), findsNothing);
    });

    testWidgets('radnik vidi samo svoju kolonu', (tester) async {
      await _naSirini(tester, _desktop, _ekran(prikaz: null, clan: _radnik));

      expect(find.byType(KalendarMrezaDana), findsOneWidget);
      expect(find.text('Vedad'), findsWidgets);
      expect(find.text('Emir'), findsNothing);
    });
  });
}
