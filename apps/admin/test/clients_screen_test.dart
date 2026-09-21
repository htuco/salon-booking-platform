/// Klijenti i profil na dvije širine — `3e` i `3o`.
///
/// Tri stvari koje ovaj test drži, a koje se iz koda ne vide:
///
/// - **Anonimiziran i telefonski klijent moraju proći kroz ekran.** Brisanje naloga
///   (task 17) ostavlja red bez upotrebljivog imena, a ručni unos red bez
///   `auth_identity_id`. Oboje je ispravno stanje, i oboje bi lako palo na `!`.
/// - **Preljevi na 402 px.** Task 34 je našao dva stvarna preljeva tek widget testom,
///   pa se svaka lista ovdje pumpa i na telefonu.
/// - **„Nema podatka" se ne smije nacrtati kao nula.** Klijent bez ijedne cijene ne
///   smije dobiti „0 KM", jer bi vlasnik pročitao da nije ništa potrošio.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/clients/clients_providers.dart';
import 'package:admin/src/features/clients/clients_screen.dart';
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

/// Redovan klijent sa nalogom.
final _haris = Customer(
  id: 'c1',
  salonId: _salonId,
  authIdentityId: 'i1',
  name: 'Haris Delić',
  phone: '061 552 104',
  note: 'Sa strane 1, gore makazama.',
  visitCount: 11,
  lastVisitAt: DateTime(2026, 5, 2),
);

/// Telefonski klijent — nema `auth_identity_id`, i to je ispravno stanje.
const _walkin = Customer(
  id: 'c2',
  salonId: _salonId,
  name: 'Nedim Hodžić',
  phone: '061 234 567',
  visitCount: 1,
  noShowCount: 2,
);

/// Anonimiziran red poslije brisanja naloga (task 17): bez telefona, bez imena.
const _obrisan = Customer(id: 'c3', salonId: _salonId, name: '', visitCount: 3);

final _istorija = [
  Appointment(
    id: 't1',
    salonId: _salonId,
    serviceId: 's1',
    customerId: 'c1',
    serviceName: 'Muško šišanje',
    servicePrice: 15,
    employeeName: 'Emir',
    customerName: 'Haris Delić',
    date: const LocalDate(2026, 5, 2),
    startTime: const LocalTime(14, 20),
    endTime: const LocalTime(14, 50),
    status: AppointmentStatus.completed,
  ),
  Appointment(
    id: 't2',
    salonId: _salonId,
    serviceId: 's2',
    customerId: 'c1',
    serviceName: 'Fade + brada',
    servicePrice: 30,
    customerName: 'Haris Delić',
    date: const LocalDate(2026, 4, 11),
    startTime: const LocalTime(10, 0),
    endTime: const LocalTime(10, 45),
    status: AppointmentStatus.completed,
  ),
  // Otkazan termin **ostaje** u istoriji, ali ne ulazi u zbir potrošenog.
  Appointment(
    id: 't3',
    salonId: _salonId,
    serviceId: 's1',
    customerId: 'c1',
    serviceName: 'Muško šišanje',
    servicePrice: 15,
    customerName: 'Haris Delić',
    date: const LocalDate(2026, 3, 14),
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(9, 30),
    status: AppointmentStatus.cancelled,
  ),
];

Widget _screen({
  List<Customer>? klijenti,
  List<Appointment>? istorija,
  Object? greska,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminSalonProvider.overrideWith((ref) async => _salon),
    pendingCountProvider.overrideWith((ref) async => 0),
    adminKlijentiProvider.overrideWith((ref) async {
      if (greska != null) throw greska;
      return klijenti ?? [_haris, _walkin, _obrisan];
    }),
    klijentProvider.overrideWith((ref, id) async {
      final svi = klijenti ?? [_haris, _walkin, _obrisan];
      for (final k in svi) {
        if (k.id == id) return k;
      }
      return null;
    }),
    klijentIstorijaProvider.overrideWith(
      (ref, id) async => istorija ?? _istorija,
    ),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminClientsScreen(),
  ),
);

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

void main() {
  group('lista', () {
    testWidgets('desktop crta adresar sa imenom, brojem i brojem dolazaka', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen());

      expect(find.text('Klijenti'), findsWidgets);
      expect(find.text('Haris Delić'), findsOneWidget);
      expect(find.text('061 552 104'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      // Zadnji dolazak, ne datum upisa.
      expect(find.text('2. maj 2026.'), findsOneWidget);
    });

    testWidgets('klijent bez dolaska dobija riječ, ne crticu', (tester) async {
      await _pumpAt(tester, _desktop, _screen());

      // `_walkin` i `_obrisan` nemaju `lastVisitAt` — „Nikad" kaže šta stoji u redu,
      // dok bi crtica izgledala kao greška u učitavanju.
      expect(find.text('Nikad'), findsNWidgets(2));
    });

    testWidgets('anonimiziran klijent ne pada i ne crta prazno ime', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen(klijenti: [_obrisan]));

      expect(tester.takeException(), isNull);
      expect(find.text('Bez imena'), findsOneWidget);
      expect(find.text('Bez broja'), findsOneWidget);
    });

    testWidgets('telefon crta kartice bez preljeva', (tester) async {
      await _pumpAt(tester, _telefon, _screen());

      expect(tester.takeException(), isNull);
      expect(find.text('Haris Delić'), findsOneWidget);
      expect(find.text('Nedim Hodžić'), findsOneWidget);
    });

    testWidgets('greška nudi ponovni pokušaj', (tester) async {
      await _pumpAt(tester, _desktop, _screen(greska: Exception('pao upit')));

      expect(find.text('Klijenti se ne mogu učitati.'), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
    });

    testWidgets('prazan adresar objašnjava kako se klijent upisuje', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen(klijenti: const []));

      expect(find.textContaining('Adresar je još prazan'), findsOneWidget);
    });
  });

  group('profil', () {
    testWidgets('otvara se klikom i crta brojače iz reda, ne iz istorije', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen());
      await tester.tap(find.text('Haris Delić'));
      await tester.pumpAndSettle();

      // `visit_count` i `no_show_count` su kolone koje puni `set_appointment_status`;
      // brojanje istorije bi dalo drugi broj, jer je istorija odrezana na `limit`.
      expect(find.text('dolazaka'), findsOneWidget);
      expect(find.text('nedolazaka'), findsOneWidget);
      expect(find.text('Historija'), findsOneWidget);
      expect(find.text('Muško šišanje'), findsNWidgets(2));
    });

    testWidgets('potrošeno broji samo održane termine', (tester) async {
      await _pumpAt(tester, _desktop, _screen());
      await tester.tap(find.text('Haris Delić'));
      await tester.pumpAndSettle();

      // 15 + 30 = 45; otkazanih 15 se **ne** broji. Da se broji, stajalo bi 60.
      expect(find.text('45'), findsOneWidget);
      expect(find.text('KM ukupno'), findsOneWidget);
    });

    testWidgets('bez ijedne cijene ne crta se nula', (tester) async {
      await _pumpAt(
        tester,
        _desktop,
        _screen(klijenti: [_haris], istorija: const []),
      );
      await tester.tap(find.text('Haris Delić'));
      await tester.pumpAndSettle();

      // Nula bi tvrdila da klijent nije ništa potrošio — a ne zna se.
      expect(find.text('nema cijena'), findsOneWidget);
      expect(find.text('KM ukupno'), findsNothing);
    });

    testWidgets('telefonski klijent je označen, ne prikazan kao greška', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen(klijenti: [_walkin]));
      await tester.tap(find.text('Nedim Hodžić'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nema nalog u aplikaciji'), findsOneWidget);
    });

    testWidgets('otkazan termin ostaje u istoriji sa svojom oznakom', (
      tester,
    ) async {
      await _pumpAt(tester, _desktop, _screen());
      await tester.tap(find.text('Haris Delić'));
      await tester.pumpAndSettle();

      // Istorija koja krije otkazane ne bi objasnila `no_show_count` u istom profilu.
      expect(find.text('Otkazano'), findsOneWidget);
    });

    testWidgets('telefon otvara profil preko liste i vraća se nazad', (
      tester,
    ) async {
      await _pumpAt(tester, _telefon, _screen());

      await tester.tap(find.text('Haris Delić'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Historija'), findsOneWidget);
      // `3o` zamjenjuje listu profilom, pa ostali klijenti nestaju.
      expect(find.text('Nedim Hodžić'), findsNothing);

      await tester.tap(find.byTooltip('Zatvori profil'));
      await tester.pumpAndSettle();
      expect(find.text('Nedim Hodžić'), findsOneWidget);
    });
  });

  group('filter', () {
    test('redovan je onaj sa dovoljno dolazaka', () {
      final sada = DateTime(2026, 5, 20);
      expect(ClientsFilter.redovni.prima(_haris, sada), isTrue);
      expect(ClientsFilter.redovni.prima(_walkin, sada), isFalse);
    });

    test('klijent koji nikad nije došao je neaktivan, ne izostavljen', () {
      // `lastVisitAt == null` nije „nema podatka" nego „nijedan termin nije održan" —
      // poređenje sa `null`-om bi ga tiho ispustilo iz liste.
      expect(
        ClientsFilter.neaktivni.prima(_walkin, DateTime(2026, 5, 20)),
        isTrue,
      );
    });

    test('nedavni dolazak ne pada pod neaktivne', () {
      expect(
        ClientsFilter.neaktivni.prima(_haris, DateTime(2026, 5, 20)),
        isFalse,
      );
    });

    test('nedolasci hvataju već prvi nedolazak', () {
      final sada = DateTime(2026, 5, 20);
      expect(ClientsFilter.nedolasci.prima(_walkin, sada), isTrue);
      expect(ClientsFilter.nedolasci.prima(_haris, sada), isFalse);
    });
  });

  group('potroseno', () {
    test('zbraja samo održane termine sa cijenom', () {
      expect(potroseno(_istorija), 45);
    });

    test('bez ijedne cijene vraća null, ne nulu', () {
      expect(potroseno(const []), isNull);
    });
  });
}
