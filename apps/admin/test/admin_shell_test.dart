/// Ljuska na dvije širine — **isti ekran**, dva rasporeda.
///
/// Test je napisan nad jednim ekranom namjerno. Da su dva, prolazio bi i kad bi ljuska
/// imala dva stabla widgeta, a upravo to task 29 zabranjuje: sidebar i donja navigacija
/// čitaju istu listu odredišta.
///
/// Širine su one iz handoffa: 1440×900 i 402×874.
library;

import 'package:admin/src/core/navigation/admin_destinations.dart';
import 'package:admin/src/core/router/admin_router.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/admin_scaffold.dart';
import 'package:admin/src/core/widgets/admin_wordmark.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/placeholder/admin_placeholder_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

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

const Size _desktop = Size(1440, 900);
const Size _telefon = Size(402, 874);

/// Isti ekran u oba slučaja — samo se mijenja širina prozora.
Widget _ekran({
  int naCekanju = 4,
  AdminRoute aktivna = AdminRoute.dashboard,
  StaffMember clan = _vlasnik,
}) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(clan),
    ),
    pendingCountProvider.overrideWith((ref) async => naCekanju),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: AdminScaffold(
      title: 'Pregled',
      aktivna: aktivna,
      body: const Center(child: Text('tijelo ekrana')),
    ),
  ),
);

/// Isti obrazac, ali sa placeholder ekranom jedne od nenapisanih ruta.
Widget _placeholder(AdminRoute route) => ProviderScope(
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    pendingCountProvider.overrideWith((ref) async => 4),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: AdminPlaceholderScreen(
      title: route.title,
      path: route.path,
      route: route,
    ),
  ),
);

/// Postavlja širinu prozora prije gradnje i vraća je poslije testa.
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
  group('desktop 1440×900', () {
    testWidgets('crta sidebar od 236 px, bez donje navigacije', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      expect(find.byType(NavigationBar), findsNothing);

      final sidebar = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(kImeProizvoda.toUpperCase()),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(sidebar.constraints?.maxWidth, AdminSize.sidebarWidth);
    });

    testWidgets('nosi svih osam modula iz sidebara `3b`', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // **Verzal je stil, podatak ostaje isti** (FE-401, `adminv2/export/3b`). Sidebar
      // ispisuje `label.toUpperCase()`, a `kAdminDestinations` i dalje nosi „Danas" — zato
      // se ovdje traži verzal, a telefonski test niže i dalje traži mala slova iz istog
      // izvora. Da je promijenjen sam `label`, donja navigacija bi tiho dobila „DANAS".
      for (final cilj in kAdminDestinations) {
        expect(
          find.text(cilj.label.toUpperCase()),
          findsOneWidget,
          reason: 'sidebar nema stavku „${cilj.label}"',
        );
        expect(
          find.text(cilj.label),
          findsNothing,
          reason: 'sidebar crta „${cilj.label}" malim slovima',
        );
      }
      // „Još" je ćelija telefona, ne modul: na desktopu tih pet stoje u sidebaru.
      expect(find.text(kAdminJos.label), findsNothing);
      expect(find.text(kAdminJos.label.toUpperCase()), findsNothing);
    });

    testWidgets('top bar je visok 66 px', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      final naslovi = find.text('Pregled');
      expect(naslovi, findsOneWidget);

      final visina = tester
          .getSize(
            find.ancestor(of: naslovi, matching: find.byType(Container)).first,
          )
          .height;
      expect(visina, AdminSize.topBarHeight);
    });
  });

  group('telefon 402×874', () {
    testWidgets('crta četiri ćelije, bez sidebara', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text(kImeProizvoda.toUpperCase()), findsNothing);

      final navigacija = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigacija.destinations.length, 4);

      for (final labela in ['Danas', 'Kalendar', 'Zahtjevi', 'Još']) {
        expect(find.text(labela), findsOneWidget);
      }
    });

    testWidgets('moduli iza „Još" nisu ćelije', (tester) async {
      await _naSirini(tester, _telefon, _ekran());

      for (final cilj in adminSporedne(kAdminDestinations)) {
        expect(
          find.text(cilj.label),
          findsNothing,
          reason: '„${cilj.label}" pripada ekranu „Još", ne donjoj navigaciji',
        );
      }
    });

    testWidgets('ekran iza „Još" označava četvrtu ćeliju', (tester) async {
      // Bez ovoga pet od osam ekrana stoji bez ijedne označene ćelije, pa vlasnik na
      // `/services` ne vidi gdje se nalazi.
      await _naSirini(tester, _telefon, _ekran(aktivna: AdminRoute.services));

      final navigacija = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigacija.selectedIndex, 3);
    });
  });

  group('obje širine', () {
    testWidgets('brojač zahtjeva stoji u obje ljuske', (tester) async {
      await _naSirini(tester, _desktop, _ekran(naCekanju: 4));
      expect(find.text('4'), findsOneWidget);

      await _naSirini(tester, _telefon, _ekran(naCekanju: 4));
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('bez zahtjeva nema pilule sa nulom', (tester) async {
      await _naSirini(tester, _desktop, _ekran(naCekanju: 0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('bez zahtjeva nema ni tačke nad ćelijom', (tester) async {
      // **Ovu je našao emulator, ne test.** Donja navigacija je `Badge` crtala uvijek, sa
      // praznim tekstom kad je brojač nula — a Material prazan `label` iscrta kao tačku.
      // Salon bez ijednog zahtjeva je tako vidio crvenu tačku i otvarao prazan ekran.
      // Provjera na `find.text('0')` to ne vidi, jer teksta i nema.
      await _naSirini(tester, _telefon, _ekran(naCekanju: 0));
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('sa zahtjevima tačka postoji', (tester) async {
      // Zaseban test, a ne drugi `pumpWidget` u prethodnom: `ProviderScope` override-e
      // primjenjuje pri montiranju, pa bi drugi pump u istom testu zadržao staru nulu i
      // test bi prolazio iz pogrešnog razloga.
      await _naSirini(tester, _telefon, _ekran(naCekanju: 3));
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('„Zahtjevi" vode na filtriranu listu, ne na svoju rutu', (
      tester,
    ) async {
      // Handoff nema ćeliju „Termini". Da zahtjevi imaju vlastitu rutu, puna lista bi
      // ostala bez ijednog ulaza iz navigacije.
      expect(kZahtjeviPutanja, '/appointments?status=pending');

      final zahtjevi = kAdminDestinations.firstWhere(
        (c) => c.label == 'Zahtjevi',
      );
      expect(zahtjevi.route, AdminRoute.appointments);
      expect(zahtjevi.putanja, kZahtjeviPutanja);
    });

    testWidgets('placeholder modul nije slijepa ulica', (tester) async {
      // **Ovu je našao browser, ne test.** `AdminPlaceholderScreen` je do taska 29 imao
      // vlastiti `Scaffold`, sto nije smetalo dok navigacija nije nudila nenapisane rute.
      // Otkad ih nudi, `/clients` otvoren iz „Još" se crtao bez ikakve navigacije i iz
      // njega se izlazilo samo dugmetom „nazad" u browseru.
      //
      // Test stoji na obje širine jer se greška na svakoj vidi drugačije: na telefonu
      // nedostaje donja navigacija, na desktopu sidebar.
      await _naSirini(tester, _telefon, _placeholder(AdminRoute.clients));
      expect(find.byType(NavigationBar), findsOneWidget);

      await _naSirini(tester, _desktop, _placeholder(AdminRoute.clients));
      expect(find.text(kImeProizvoda.toUpperCase()), findsOneWidget);
    });

    testWidgets('gutter prati širinu, ne ekran', (tester) async {
      // **Brojevi su ovdje namjerno, a ne `AdminSpacing.gutterDesktop`.** Prva verzija
      // ovog testa je poredila token sa samim sobom i prošla je i kad je gutter vraćen na
      // pogrešnih 24 — provjereno pokretanjem. Vrijednosti su izmjerene iz canvasa:
      // radna površina `padding:28px`, mobilni ekrani `padding:… 20px`.
      await _naSirini(tester, _desktop, _ekran());
      expect(
        AdminShell.gutterOf(tester.element(find.text('tijelo ekrana'))),
        28,
      );

      await _naSirini(tester, _telefon, _ekran());
      expect(
        AdminShell.gutterOf(tester.element(find.text('tijelo ekrana'))),
        20,
      );
    });
  });

  group('pojasevi širine (FE-406)', () {
    // **Brojevi su ovdje namjerno, a ne `AdminBreakpoint.*`.** Isti razlog kao kod gutera
    // iznad: test koji poredi token sa samim sobom prolazi i kad se prag pomjeri.
    test('granice pojaseva su 900, 1440 i 1920', () {
      expect(AdminShell.bandZa(899), AdminWidthBand.compact);
      expect(AdminShell.bandZa(900), AdminWidthBand.regular);
      expect(AdminShell.bandZa(1439), AdminWidthBand.regular);
      expect(AdminShell.bandZa(1440), AdminWidthBand.wide);
      expect(AdminShell.bandZa(1919), AdminWidthBand.wide);
      expect(AdminShell.bandZa(1920), AdminWidthBand.ultraWide);
      expect(AdminShell.bandZa(2560), AdminWidthBand.ultraWide);
    });

    test('pojas 840–900 ima sidebar, ali je i dalje jedna kolona', () {
      // Dva praga se namjerno ne poklapaju: `desktop` bira ljusku, pojas bira kolone.
      // Na 860 px sidebar stoji, a sadržaj se još ne dijeli u dvije kolone.
      expect(860 >= AdminBreakpoint.desktop, isTrue);
      expect(AdminShell.bandZa(860), AdminWidthBand.compact);
      expect(AdminWidthBand.compact.kolone, 1);
    });

    testWidgets('bandOf oduzima sidebar, pa 1440 nije `wide`', (tester) async {
      // **Ovo je zamka iz taska.** Radna površina na prozoru od 1440 je 1440 − 236 = 1204,
      // dakle `regular`. Pojas izveden iz `MediaQuery` bez oduzimanja sidebara dao bi
      // `wide` i jednu kolonu viška.
      await _naSirini(tester, _desktop, _ekran());
      final context = tester.element(find.text('tijelo ekrana'));

      expect(AdminShell.bandOf(context), AdminWidthBand.regular);
      expect(AdminShell.bandZa(1440), AdminWidthBand.wide);
    });

    testWidgets('telefon ne oduzima sidebar jer ga nema', (tester) async {
      await _naSirini(tester, _telefon, _ekran());
      final context = tester.element(find.text('tijelo ekrana'));

      expect(AdminShell.bandOf(context), AdminWidthBand.compact);
    });
  });

  group('Melura branding (FE-401)', () {
    testWidgets('sidebar nosi ime proizvoda i ulogu, ne mail', (tester) async {
      // `3b` ispod imena crta **ulogu**, ne mail: u sidebaru je korisnije ko si ovdje nego
      // čime si se prijavio. Mail ostaje dostupan u meniju naloga na telefonu.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text(kImeProizvoda.toUpperCase()), findsOneWidget);
      expect(find.text('vlasnik lokacije'), findsOneWidget);
      expect(find.text(_vlasnik.email), findsNothing);
    });

    testWidgets('logo je placeholder, ne prazno mjesto', (tester) async {
      // Prazan prostor u sidebaru izgleda kao greška u iscrtavanju; isprekidani okvir
      // kaže „ovdje ide logo, još ga nema". Pravog logo asseta još nema.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.text('LOGO'), findsOneWidget);
    });

    testWidgets('pilula brojača je koralna, ne plava', (tester) async {
      // **Ovo je našao browser, ne test.** Poslije prelaska na tamni sidebar pilula uz
      // „Zahtjeve" je ostala `accent` (`#3D5A80`) i na tamnoj podlozi se čitala kao
      // greška; `adminv2/export/3b` mjeri `#EE6C4D` na tom mjestu.
      //
      // Tekst je `onAction` (`#2C2C2C`), ne `onAccent` (bijela): bijela na koralu mjeri
      // 3,05:1 i pada AA — v. `admin_colors.dart`.
      await _naSirini(tester, _desktop, _ekran(naCekanju: 3));

      final pilula = tester.widget<Container>(
        find
            .ancestor(of: find.text('3'), matching: find.byType(Container))
            .first,
      );
      final dekoracija = pilula.decoration! as BoxDecoration;
      expect(dekoracija.color, AdminPalette.light.action);

      final tekst = tester.widget<Text>(find.text('3'));
      expect(tekst.style?.color, AdminPalette.light.onAction);
    });

    test('nepoznata uloga ne ispisuje sirovu vrijednost', () {
      // Enum `public.staff_role` se može proširiti; red koji ovdje ne prepoznajemo ne
      // smije korisniku ispisati `salon_manager`. Tada podnožje pokaže samo ime.
      expect(labelaUloge('salon_admin'), 'vlasnik lokacije');
      expect(labelaUloge('employee'), 'radnik');
      expect(labelaUloge('super_admin'), 'administrator platforme');
      expect(labelaUloge('salon_manager'), isNull);
      expect(labelaUloge(''), isNull);
    });

    test('sidebar je taman i u svijetloj temi', () {
      // Izmjereno iz `adminv2/export/3b`, ne procijenjeno. Razrješava protivrječnost
      // unutar `prototype/admin/SPEC.md`: red 11 traži „stalni tamni sidebar", a tabela
      // tokena u redu 86 daje `#F8F9FA`. Po ADR-0016 izvoz je jači za vizual.
      expect(AdminPalette.light.sidebarBackground, const Color(0xFF141517));
      expect(AdminPalette.light.sidebarSelected, const Color(0xFF373A40));
      expect(
        AdminPalette.light.sidebarAccentForeground,
        const Color(0xFFFFFFFF),
      );

      // Radna površina ostaje svijetla — taman je samo sidebar.
      expect(AdminPalette.light.ground, const Color(0xFFFCFCF9));
    });
  });

  group('akcije u top baru', () {
    /// Regresija: dugmad su stajala **na sredini** top bara, sa prazninom do desne ivice.
    ///
    /// Uzrok nije bio nedostatak `Spacer`-a — on je bio tu. Dashboard je svoje dvije
    /// radnje predavao kao `Row` **bez** `mainAxisSize: MainAxisSize.min`, pa se taj red
    /// razvukao preko cijelog ostatka top bara i dugmad su ostala na njegovom početku.
    ///
    /// Zato test predaje akcije **upravo tako** — neograničenim `Row`-om. Da predaje samo
    /// dugme, prolazio bi i prije popravke i ne bi dokazivao ništa.
    Widget saAkcijama() => ProviderScope(
      overrides: [
        currentStaffProvider.overrideWith(
          (ref) => Stream<StaffMember?>.value(_vlasnik),
        ),
        pendingCountProvider.overrideWith((ref) async => 4),
      ],
      child: MaterialApp(
        theme: buildAdminTheme(),
        home: AdminScaffold(
          title: 'Pregled',
          aktivna: AdminRoute.dashboard,
          actions: [
            Row(
              children: [
                OutlinedButton(onPressed: () {}, child: const Text('Blokiraj')),
                const SizedBox(width: AdminSpacing.md),
                FilledButton(onPressed: () {}, child: const Text('Novi')),
              ],
            ),
          ],
          body: const Center(child: Text('tijelo ekrana')),
        ),
      ),
    );

    testWidgets('zadnja radnja završava uz desnu ivicu, ne na sredini', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, saAkcijama());

      final desnaIvica = tester.getBottomRight(find.byType(FilledButton)).dx;

      // Radna površina ide od sidebara do desne ivice prozora; gutter je jedini razmak
      // koji smije ostati iza zadnjeg dugmeta.
      const ocekivano = 1440 - AdminSpacing.gutterDesktop;

      expect(
        desnaIvica,
        moreOrLessEquals(ocekivano, epsilon: 1),
        reason:
            'Zadnja radnja mora završiti na $ocekivano px (gutter od desne ivice), '
            'a završava na $desnaIvica px.',
      );
    });

    testWidgets('obje radnje ostaju u desnoj polovini top bara', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, saAkcijama());

      // Sredina radne površine: sidebar (236) + pola ostatka.
      const sredina =
          AdminSize.sidebarWidth + (1440 - AdminSize.sidebarWidth) / 2;

      expect(
        tester.getTopLeft(find.byType(OutlinedButton)).dx,
        greaterThan(sredina),
        reason: 'Prva radnja je lijevo od sredine — red se razvukao.',
      );
    });
  });

  // Task 47 — radnik dobija **istu** ljusku, samo nad filtriranom listom. Test je nad
  // istim `_ekran`-om kao vlasnikov: dvije ljuske bi prolazile i kad filter ne radi.
  group('radnik', () {
    const vlasnickiModuli = [
      'Klijenti',
      'Usluge',
      'Osoblje',
      'Radno vrijeme',
      'Postavke',
    ];

    testWidgets('sidebar nosi samo njegove module', (tester) async {
      await _naSirini(tester, _desktop, _ekran(clan: _radnik));

      for (final labela in ['Danas', 'Kalendar', 'Zahtjevi']) {
        expect(
          find.text(labela.toUpperCase()).evaluate().isNotEmpty ||
              find.text(labela).evaluate().isNotEmpty,
          isTrue,
          reason: labela,
        );
      }
      for (final labela in vlasnickiModuli) {
        expect(find.text(labela), findsNothing, reason: labela);
        expect(find.text(labela.toUpperCase()), findsNothing, reason: labela);
      }
      expect(find.text('radnik'), findsOneWidget);
    });

    testWidgets('vlasnik na istom ekranu vidi svih osam', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      for (final labela in vlasnickiModuli) {
        expect(
          find.text(labela).evaluate().isNotEmpty ||
              find.text(labela.toUpperCase()).evaluate().isNotEmpty,
          isTrue,
          reason: labela,
        );
      }
    });

    testWidgets('telefon: tri ćelije i „Još", koji nosi samo odjavu', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran(clan: _radnik));

      final navigacija = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigacija.destinations, hasLength(4));
      expect(
        adminSporedne(adminDestinationsZa(_radnik)),
        isEmpty,
        reason: 'iza „Još" radniku ne smije stajati nijedan modul',
      );
    });

    test('nijedan radnikov modul nije van ruta koje router pušta', () {
      for (final cilj in adminDestinationsZa(_radnik)) {
        expect(dozvoljenaRadniku(cilj.route.path), isTrue, reason: cilj.label);
      }
      for (final cilj in kAdminDestinations) {
        if (adminDestinationsZa(_radnik).contains(cilj)) continue;
        expect(dozvoljenaRadniku(cilj.route.path), isFalse, reason: cilj.label);
      }
    });

    test('radnik bez veze na `employees` nije radnik', () {
      const bezVeze = StaffMember(
        id: 'x',
        name: 'x',
        email: 'x@x.test',
        role: 'employee',
        salonId: _salonId,
      );
      expect(bezVeze.imaPristup, isFalse);
      expect(adminDestinationsZa(bezVeze), kAdminDestinations);
    });
  });
}
