import 'package:admin/src/features/appointments/appointment_tile.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/appointments/appointments_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _vlasnik = StaffMember(
  id: '11111111-0000-4000-8000-000000000001',
  name: 'Vlasnik',
  email: 'admin@primjer.test',
  role: 'salon_admin',
  salonId: _salonId,
);

Appointment _termin({
  required String ime,
  required int sat,
  AppointmentStatus status = AppointmentStatus.confirmed,
  String? napomena,
  String? telefon,
}) => Appointment(
  id: 'a-$ime-$sat',
  salonId: _salonId,
  serviceId: 's1',
  customerId: 'c1',
  customerName: ime,
  customerPhone: telefon,
  customerNote: napomena,
  date: LocalDate(2026, 9, 14),
  startTime: LocalTime(sat, 0),
  endTime: LocalTime(sat, 40),
  status: status,
);

Widget _ekran(List<Appointment> termini, {AppointmentStatus? trazeniStatus}) =>
    ProviderScope(
      overrides: [
        currentStaffProvider.overrideWith(
          (ref) => Stream<StaffMember?>.value(_vlasnik),
        ),
        filtriraniTerminiProvider.overrideWith((ref) async => termini),
      ],
      child: MaterialApp(
        home: AdminAppointmentsScreen(trazeniStatus: trazeniStatus),
      ),
    );

void main() {
  testWidgets('lista prikazuje termine sa vremenom i imenom', (tester) async {
    await tester.pumpWidget(
      _ekran([
        _termin(ime: 'Adnan Music', sat: 10),
        _termin(ime: 'Emir Hodzic', sat: 11),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adnan Music'), findsOneWidget);
    expect(find.text('Emir Hodzic'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('do 10:40'), findsOneWidget);
  });

  testWidgets('otkazan termin ostaje u listi', (tester) async {
    // Dan sa tri termina od kojih je jedan otkazan nije isto sto i dan sa dva —
    // skrivanje bi izgledalo kao da termin nikad nije ni postojao.
    await tester.pumpWidget(
      _ekran([
        _termin(ime: 'Adnan Music', sat: 10),
        _termin(
          ime: 'Tarik Begic',
          sat: 12,
          status: AppointmentStatus.cancelled,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tarik Begic'), findsOneWidget);
    // Suzeno na celiju: „Otkazani" stoji i u filter cipu iznad liste.
    expect(
      find.descendant(
        of: find.byType(AppointmentTile),
        matching: find.text('Otkazani'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('napomena klijenta se vidi u listi', (tester) async {
    // Napomena nosi ono sto vlasnik mora znati prije termina.
    await tester.pumpWidget(
      _ekran([
        _termin(
          ime: 'Lejla Karic',
          sat: 13,
          napomena: 'Alergija na jedan proizvod.',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alergija na jedan proizvod.'), findsOneWidget);
  });

  testWidgets('prazan dan ima svoje stanje', (tester) async {
    await tester.pumpWidget(_ekran(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nema zakazanih termina za ovaj dan.'), findsOneWidget);
  });

  testWidgets('status se uz boju uvijek pise i tekstom', (tester) async {
    // WCAG 1.4.1: boja ne smije biti jedini nosilac informacije.
    await tester.pumpWidget(
      _ekran([
        _termin(ime: 'Emir', sat: 11, status: AppointmentStatus.pending),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppointmentTile),
        matching: find.text('Na čekanju'),
      ),
      findsOneWidget,
    );
  });

  group('AppointmentsFilter', () {
    test('pocinje na danas, svi statusi', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = container.read(appointmentsFilterProvider);
      final danas = DateTime.now();

      expect(filter.status, isNull);
      expect(filter.dan.day, danas.day);
      expect(filter.dan.month, danas.month);
    });

    test('ponovni tap na isti status ga iskljucuje', () {
      // Inace se filter ne moze ponistiti bez trazenja dugmeta „Svi".
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appointmentsFilterProvider.notifier);

      notifier.postaviStatus(AppointmentStatus.pending);
      expect(
        container.read(appointmentsFilterProvider).status,
        AppointmentStatus.pending,
      );

      notifier.postaviStatus(AppointmentStatus.pending);
      expect(container.read(appointmentsFilterProvider).status, isNull);
    });

    test('pomjeranje dana cuva izabrani status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appointmentsFilterProvider.notifier);

      notifier.postaviStatus(AppointmentStatus.confirmed);
      final prije = container.read(appointmentsFilterProvider).dan;
      notifier.pomjeriDan(1);
      final poslije = container.read(appointmentsFilterProvider);

      expect(poslije.status, AppointmentStatus.confirmed);
      expect(poslije.dan.difference(prije).inDays, 1);
    });
  });

  group('filter iz adrese (`?status=`)', () {
    test('statusIzUpita mapira samo stvarne statuse', () {
      expect(statusIzUpita('pending'), AppointmentStatus.pending);
      expect(statusIzUpita('no_show'), AppointmentStatus.noShow);
    });

    test('smece u adresi znaci „svi", ne prazan ekran', () {
      // `AppointmentStatus.fromWire` bi ovdje vratilo `unknown`, sto je tacno za red iz
      // baze a pogresno za adresu: filter po statusu koji nijedan termin nema daje praznu
      // listu, pa `/appointments?status=blabla` izgleda kao dan bez termina.
      expect(AppointmentStatus.fromWire('blabla'), AppointmentStatus.unknown);

      expect(statusIzUpita('blabla'), isNull);
      expect(statusIzUpita('unknown'), isNull);
      expect(statusIzUpita(''), isNull);
      expect(statusIzUpita(null), isNull);
    });

    test('postaviStatusTacno ne prebacuje', () {
      // Zamka zbog koje metoda uopste postoji: `postaviStatus` je prebacivac, pa bi
      // otvaranje `?status=pending` nad vec filtriranom listom ocistilo filter — ista
      // adresa dala bi dva razlicita ekrana.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appointmentsFilterProvider.notifier);

      notifier.postaviStatusTacno(AppointmentStatus.pending);
      notifier.postaviStatusTacno(AppointmentStatus.pending);

      expect(
        container.read(appointmentsFilterProvider).status,
        AppointmentStatus.pending,
      );
    });

    testWidgets('ekran otvoren sa `?status=pending` filtrira listu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ekran(const [], trazeniStatus: AppointmentStatus.pending),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zahtjevi'), findsWidgets);
    });
  });

  test('statusLabela pokriva svaki status', () {
    // `switch` nad enumom je iscrpan, ali ovo hvata prazan string ako se neki doda
    // pa povrsno popuni.
    for (final status in AppointmentStatus.values) {
      expect(statusLabela(status), isNotEmpty);
    }
  });
}
