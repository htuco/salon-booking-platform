/// Detalj termina — prikaz `3n`.
///
/// Ekran čita **jedan** termin iz baze po `id`-u iz adrese, pa se testira i ono što se ne
/// vidi na slici: da obrisan i tuđi termin daju istu poruku, i da zatvoren termin nema
/// nijednu radnju.
library;

import 'package:admin/src/core/router/admin_router.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointment_detail_screen.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/appointments/new_appointment_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _terminId = 'aa000000-0000-4000-8000-000000000001';

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
    name: 'Muško šišanje',
    price: 15,
    durationMinutes: 30,
  ),
];

const _radnici = [Employee(id: 'e1', salonId: _salonId, name: 'Emir')];

Appointment _termin({
  AppointmentStatus status = AppointmentStatus.confirmed,
  String? napomena,
  String? telefon = '061 552 104',
  String? radnik = 'e1',
  String source = 'app',
  String? razlog,
  String? otkazao,
}) => Appointment(
  id: _terminId,
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: 'Haris Delić',
  customerPhone: telefon,
  customerNote: napomena,
  date: LocalDate(2026, 5, 18),
  startTime: const LocalTime(14, 20),
  endTime: const LocalTime(14, 50),
  status: status,
  source: source,
  cancelReason: razlog,
  cancelledBy: otkazao,
);

Widget _ekran(Appointment? termin) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    pendingCountProvider.overrideWith((ref) async => 0),
    adminServicesProvider.overrideWith((ref) async => _usluge),
    adminEmployeesProvider.overrideWith((ref) async => _radnici),
    terminProvider(_terminId).overrideWith((ref) async => termin),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AppointmentDetailScreen(appointmentId: _terminId),
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
  testWidgets('naslov je vrijeme i ime, uz statusnu oznaku', (tester) async {
    await _naSirini(tester, _telefon, _ekran(_termin()));

    expect(find.text('14:20 · Haris Delić'), findsOneWidget);
    expect(find.text('Potvrđeno'), findsOneWidget);
    expect(find.text('Termini'), findsWidgets);
  });

  testWidgets('tabela nosi zapis iz `3n`', (tester) async {
    await _naSirini(tester, _telefon, _ekran(_termin()));

    // `3n` (adminv2): dan u sedmici i dd.mm., trajanje se čita iz raspona.
    expect(find.text('ponedjeljak, 18.05.'), findsOneWidget);
    expect(find.text('14:20–14:50'), findsOneWidget);
    expect(find.text('Muško šišanje'), findsOneWidget);
    expect(find.text('15 KM'), findsOneWidget);
    expect(find.text('Emir'), findsOneWidget);
    // „Zakazano": bez `created_at` ostaje samo izvor.
    expect(find.text('aplikacija'), findsOneWidget);
    expect(find.text('061 552 104'), findsOneWidget);
  });

  testWidgets('ručni unos se vidi kao unos salona', (tester) async {
    await _naSirini(tester, _telefon, _ekran(_termin(source: 'admin')));

    expect(find.text('ručni unos'), findsOneWidget);
  });

  testWidgets('termin bez radnika piše „bilo ko"', (tester) async {
    await _naSirini(tester, _telefon, _ekran(_termin(radnik: null)));

    expect(find.text('bilo ko'), findsOneWidget);
  });

  testWidgets('napomena klijenta stoji u svojoj sekciji', (tester) async {
    await _naSirini(
      tester,
      _telefon,
      _ekran(_termin(napomena: 'Ne kratiti brkove.')),
    );

    // Na 402×874 napomena stoji ispod pregiba, a `ListView` je lijen — bez skrola je
    // widget ne bi ni napravio.
    await tester.dragUntilVisible(
      find.text('Ne kratiti brkove.'),
      find.byType(ListView),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();

    expect(find.text('Napomena'), findsOneWidget);
    expect(find.text('Ne kratiti brkove.'), findsOneWidget);
  });

  testWidgets('razlog otkazivanja se vidi, jer ga vidi i klijent', (
    tester,
  ) async {
    await _naSirini(
      tester,
      _telefon,
      _ekran(
        _termin(
          status: AppointmentStatus.cancelled,
          razlog: 'Majstor je bolestan.',
          otkazao: 'salon',
        ),
      ),
    );

    await tester.dragUntilVisible(
      find.text('Majstor je bolestan.'),
      find.byType(ListView),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();

    expect(find.text('Razlog otkazivanja'), findsOneWidget);
    expect(find.text('Majstor je bolestan.'), findsOneWidget);
    expect(find.text('salon'), findsOneWidget);
  });

  group('radnje', () {
    testWidgets('potvrđen termin nudi radnje iz `3n`', (tester) async {
      await _naSirini(tester, _telefon, _ekran(_termin()));

      // Primarna radnja je cijela rečenica, u verzalu (ADR-0020).
      expect(find.text('OZNAČI KAO ZAVRŠENO'), findsOneWidget);
      expect(find.text('Nije došao'), findsOneWidget);
      expect(find.text('Otkaži'), findsOneWidget);
      // „Pomjeri" je nacrtan kao u `3n`, ali nema RPC putanju — tap kaže „uskoro".
      expect(find.text('Pomjeri'), findsOneWidget);
    });

    testWidgets('„Pomjeri" ne glumi radnju, nego kaže „uskoro"', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran(_termin()));

      await tester.tap(find.text('Pomjeri'));
      await tester.pump();

      expect(find.text('Pomjeranje termina — uskoro.'), findsOneWidget);
    });

    testWidgets('zahtjev nudi potvrdu i odbijanje', (tester) async {
      await _naSirini(
        tester,
        _telefon,
        _ekran(_termin(status: AppointmentStatus.pending)),
      );

      expect(find.text('POTVRDI'), findsOneWidget);
      expect(find.text('Odbij'), findsOneWidget);
    });

    testWidgets('zatvoren termin nema nijednu radnju', (tester) async {
      // Završen termin se ne može „završiti" drugi put, a otkazan potvrditi — baza bi to
      // odbila, pa dugme vodi u grešku koja se mogla izbjeći.
      await _naSirini(
        tester,
        _telefon,
        _ekran(_termin(status: AppointmentStatus.completed)),
      );

      expect(find.byType(FilledButton), findsNothing);
      // „Pozovi · Poruka · Profil" ostaju (OutlinedButton), ali nijedna radnja nad statusom.
      for (final radnja in ['Nije došao', 'Otkaži', 'Pomjeri', 'Odbij']) {
        expect(find.text(radnja), findsNothing);
      }
    });
  });

  testWidgets('termin kojeg nema ne otkriva da postoji negdje drugdje', (
    tester,
  ) async {
    // Obrisan termin i termin tuđeg salona daju **istu** poruku: RLS vraća nula redova u
    // oba slučaja, a poruka „nemate pravo" bi potvrdila da taj termin postoji.
    await _naSirini(tester, _telefon, _ekran(null));

    expect(find.text('Ovaj termin više ne postoji.'), findsOneWidget);
    expect(find.text('Nazad na termine'), findsOneWidget);
    expect(find.textContaining('prava'), findsNothing);
  });

  testWidgets('na desktopu detalj ne ide preko cijele radne površine', (
    tester,
  ) async {
    // Jedan zapis, ne tabela: red od 1900 px između labele i vrijednosti se ne čita.
    await _naSirini(tester, _desktop, _ekran(_termin()));

    final sirina = tester.getSize(find.byType(ListView)).width;
    expect(sirina, lessThanOrEqualTo(720));
  });

  testWidgets('na 2560 px površina je puna, a sadržaj i dalje u koloni', (
    tester,
  ) async {
    // **Ovo je našao browser, ne test.** Prva verzija FE-406 je cijeli detalj — zajedno sa
    // zaglavljem i trakom radnji, koji crtaju svoju pozadinu — držala u `ConstrainedBox`-u
    // od 720 px. Pozadina je zato prestajala na 720 px i kroz stranicu je išao uspravan
    // šav. Druga verzija je popravila šav, ali je pilulu statusa odbacila skroz desno, a
    // „Potvrdi" razvukla preko 2324 px, jer je sadržaj ostao bez granice.
    //
    // Oba stanja prolaze test iznad (on mjeri samo `ListView`), pa granica mora biti
    // izmjerena i na zaglavlju i na traci radnji.
    await _naSirini(
      tester,
      const Size(2560, 1200),
      _ekran(_termin(status: AppointmentStatus.pending)),
    );

    // Radna površina je 2560 − 236 (sidebar) = 2324.
    final zaglavlje = tester
        .getSize(
          find
              .ancestor(
                of: find.text('Termini'),
                matching: find.byType(Container),
              )
              .last,
        )
        .width;
    expect(zaglavlje, greaterThan(2000), reason: 'pozadina mora biti puna');

    // Sadržaj u njemu ostaje u koloni: dugme „Potvrdi" ne smije preći mjeru čitljivosti.
    final potvrdi = tester.getSize(
      find.widgetWithText(FilledButton, 'POTVRDI'),
    );
    expect(
      potvrdi.width,
      lessThanOrEqualTo(720),
      reason: 'radnje ne smiju biti razvučene preko cijele radne površine',
    );
  });

  group('ruta', () {
    test('`/appointments/:id` ima tijelo, nije placeholder', () {
      // Rutu je do taska 30 pokrivala petlja placeholdera — enum ju je imao, ekran ne.
      expect(AdminRoute.appointmentDetails.path, '/appointments/:id');
    });

    testWidgets('`/appointments/new` se ne čita kao `:id`', (tester) async {
      // Statički segment mora stajati **prije** parametra; obrnut redoslijed otvori detalj
      // termina sa `id = "new"`.
      final container = ProviderContainer(
        overrides: [
          currentStaffProvider.overrideWith(
            (ref) => Stream<StaffMember?>.value(_vlasnik),
          ),
          pendingCountProvider.overrideWith((ref) async => 0),
          adminServicesProvider.overrideWith((ref) async => _usluge),
          adminEmployeesProvider.overrideWith((ref) async => _radnici),
          adminEmployeeLinksProvider.overrideWith(
            (ref) async => const <EmployeeService>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(adminRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildAdminTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go(AdminRoute.appointmentNew.path);
      await tester.pumpAndSettle();

      expect(find.byType(NewAppointmentScreen), findsOneWidget);
      expect(find.byType(AppointmentDetailScreen), findsNothing);
    });
  });
}
