import 'package:admin/src/features/appointments/appointment_card.dart';
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
    // Kraj termina se od taska 30 **ne piše** u kartici: canvas (`3k`, `3m`) nosi samo
    // početak, a trajanje stoji u detalju. Lista se skenira po satu početka.
    expect(find.text('do 10:40'), findsNothing);
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
    // Suzeno na celiju: „Otkazani" stoji i u filter cipu iznad liste — ali u **mnozini**,
    // dok pilula uz termin od taska 30 nosi jedninu („Otkazano").
    expect(
      find.descendant(
        of: find.byType(AppointmentCard),
        matching: find.text('Otkazano'),
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

    expect(find.text('Nema termina za ovaj dan.'), findsOneWidget);
  });

  testWidgets('prazno zbog statusa nudi „Prikaži sve statuse" (FE-501)', (
    tester,
  ) async {
    await tester.pumpWidget(_ekran(const []));
    await tester.pumpAndSettle();
    // Prazan dan bez filtera nema šta poništiti.
    expect(find.text('Prikaži sve statuse'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminAppointmentsScreen)),
    );
    container
        .read(appointmentsFilterProvider.notifier)
        .postaviStatusTacno(AppointmentStatus.confirmed);
    await tester.pumpAndSettle();

    expect(find.textContaining('Nema termina sa statusom'), findsOneWidget);
    await tester.tap(find.text('Prikaži sve statuse'));
    await tester.pumpAndSettle();

    expect(container.read(appointmentsFilterProvider).status, isNull);
    expect(find.text('Nema termina za ovaj dan.'), findsOneWidget);
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
        of: find.byType(AppointmentCard),
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

  group('fluidna širina (FE-406)', () {
    /// Širina koju lista stvarno zauzme, mjerena preko kartica u njoj.
    ///
    /// Mjeri se **desna ivica najdešnje kartice**, jer to je ono što se vidi kao prazna
    /// margina: ranija verzija je centrirala kolonu od 1176 px, pa je na 2560 px ostajalo
    /// po ~690 px praznine sa svake strane.
    double desnaIvica(WidgetTester tester) {
      final kartice = find.byType(AppointmentCard);
      expect(kartice, findsWidgets);
      var desno = 0.0;
      for (var i = 0; i < kartice.evaluate().length; i++) {
        final r = tester.getRect(kartice.at(i));
        if (r.right > desno) desno = r.right;
      }
      return desno;
    }

    Future<void> naSirini(WidgetTester tester, Size velicina) async {
      tester.view.physicalSize = velicina;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _ekran([
          _termin(ime: 'Adnan Music', sat: 9),
          _termin(ime: 'Emir Hodzic', sat: 10),
          _termin(ime: 'Lejla Begic', sat: 11),
          _termin(ime: 'Ivana Maric', sat: 12),
        ]),
      );
      await tester.pumpAndSettle();
    }

    /// Koliko kartica stoji u prvom redu — broj kolona, mjeren iz rasporeda.
    ///
    /// **Ovo je prava provjera, a ne sama desna ivica.** Prva verzija ovog testa je gledala
    /// samo dokle sadržaj seže i prolazila je i kad se lista srozala na *jednu* razvučenu
    /// karticu preko cijelog stola — jer i ona dopire do desne ivice. Provjereno
    /// sabotažom: `band` prikovan na `compact` nije oborio test.
    int koloneUPrvomRedu(WidgetTester tester) {
      final kartice = find.byType(AppointmentCard);
      final prviVrh = tester.getRect(kartice.first).top;
      var broj = 0;
      for (var i = 0; i < kartice.evaluate().length; i++) {
        if (tester.getRect(kartice.at(i)).top == prviVrh) broj++;
      }
      return broj;
    }

    testWidgets('na 2560 px četiri kolone, bez prazne desne polovine', (
      tester,
    ) async {
      await naSirini(tester, const Size(2560, 1200));

      // Radna površina je 2560 − 236 (sidebar) = 2324; sa guterom od 28 sadržaj ide do
      // 2532. Prije FE-406 je kolona bila centrirana na 1176 px i stajala bi oko 1868.
      expect(koloneUPrvomRedu(tester), 4);
      expect(desnaIvica(tester), greaterThan(2400));
    });

    testWidgets('na 1920 px tri kolone', (tester) async {
      await naSirini(tester, const Size(1920, 1080));

      expect(koloneUPrvomRedu(tester), 3);
      expect(desnaIvica(tester), greaterThan(1800));
    });

    testWidgets('na 1440 px dvije kolone — sidebar se oduzima', (tester) async {
      // Radna površina je 1204 px, dakle pojas `regular`. Da se pojas računao iz širine
      // prozora, ovdje bi stajale tri kolone.
      await naSirini(tester, const Size(1440, 900));

      expect(koloneUPrvomRedu(tester), 2);
    });

    testWidgets('kartica se ne sužava ispod čitljivog', (tester) async {
      // Na 1100 px radna površina je 864 — dvije kolone bi dale kartice od ~420 px, što
      // pojas `compact` (< 900) ionako ne dozvoljava. Jedna kolona, puna širina.
      await naSirini(tester, const Size(1100, 900));

      expect(koloneUPrvomRedu(tester), 1);
      expect(tester.getRect(find.byType(AppointmentCard).first).width, 808);
    });

    testWidgets('telefon ostaje jedna kolona', (tester) async {
      await naSirini(tester, const Size(402, 874));

      // Sve kartice dijele istu lijevu ivicu — nema druge kolone.
      final kartice = find.byType(AppointmentCard);
      final prva = tester.getRect(kartice.first).left;
      for (var i = 1; i < kartice.evaluate().length; i++) {
        expect(tester.getRect(kartice.at(i)).left, prva);
      }
    });
  });
}
