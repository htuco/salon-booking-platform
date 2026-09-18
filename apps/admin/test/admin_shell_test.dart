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
import 'package:admin/src/features/appointments/appointments_providers.dart';
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

const Size _desktop = Size(1440, 900);
const Size _telefon = Size(402, 874);

/// Isti ekran u oba slučaja — samo se mijenja širina prozora.
Widget _ekran({int naCekanju = 4, AdminRoute aktivna = AdminRoute.dashboard}) =>
    ProviderScope(
      overrides: [
        currentStaffProvider.overrideWith(
          (ref) => Stream<StaffMember?>.value(_vlasnik),
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
              of: find.text('Salon OS'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(sidebar.constraints?.maxWidth, AdminSize.sidebarWidth);
    });

    testWidgets('nosi svih osam modula iz sidebara `3b`', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      for (final cilj in kAdminDestinations) {
        expect(
          find.text(cilj.label),
          findsOneWidget,
          reason: 'sidebar nema stavku „${cilj.label}"',
        );
      }
      // „Još" je ćelija telefona, ne modul: na desktopu tih pet stoje u sidebaru.
      expect(find.text(kAdminJos.label), findsNothing);
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

      expect(find.text('Salon OS'), findsNothing);

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

      for (final cilj in adminSporedne) {
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

    testWidgets('gutter prati širinu, ne ekran', (tester) async {
      await _naSirini(tester, _desktop, _ekran());
      expect(
        AdminShell.gutterOf(tester.element(find.text('tijelo ekrana'))),
        AdminSpacing.gutterDesktop,
      );

      await _naSirini(tester, _telefon, _ekran());
      expect(
        AdminShell.gutterOf(tester.element(find.text('tijelo ekrana'))),
        AdminSpacing.gutterMobile,
      );
    });
  });
}
