/// Pristupačnost klijenta — FE-502.
///
/// Svaki ekran na telefonu (390 × 844) mjeri tri stvari:
/// - **mete** ≥ 44 × 44 (`docs/02 §14`, iOS HIG), svaka sa labelom i svaka fokusabilna;
/// - **kontrast** teksta po WCAG-u (4,5:1 tekst, 3:1 veliki tekst) na stvarno
///   iscrtanim pikselima — **na svakom tenantu iz registra**, jer brand boja nije
///   konstanta nego podatak iz `tenant.yaml` (ADR-0018), a svijetla i tamna tema nose
///   tekst na različitim površinama;
/// - **130 % sistemskog fonta** ne presijeca nijedan red.
///
/// Booking koraci 2–4 traže stanje flowa i mjere se kroz `booking_flow_screens_test.dart`;
/// ovdje je korak 1, jer je on ulaz.
library;

import 'dart:ui' show Tristate;

import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/screen_harness.dart';

final _rute = <String>[
  ClientRoute.home.path,
  ClientRoute.services.path,
  ClientRoute.appointments.path,
  ClientRoute.notifications.path,
  ClientRoute.settings.path,
  ClientRoute.about.path,
  ClientRoute.gallery.path,
  ClientRoute.reviews.path,
  ClientRoute.aboutApp.path,
  ClientRoute.login.path,
  ClientRoute.bookService.path,
];

String _heks(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Demo salon obučen u paletu i temu [tenant]-a — tema se gradi iz `salons.*` boja.
Salon _salonTenanta(TenantConfig tenant) => demoSalon.copyWith(
  primaryColor: _heks(tenant.primaryColor),
  secondaryColor: _heks(tenant.secondaryColor),
  theme: tenant.themeName,
);

Future<void> _telefon(
  WidgetTester tester,
  String ruta, {
  double skala = 1,
  TenantConfig? tenant,
}) async {
  await pumpEkran(
    tester,
    ruta: ruta,
    salon: tenant == null ? demoSalon : _salonTenanta(tenant),
    usluge: [
      usluga(id: 's1', name: 'Šišanje i brijanje brade', category: 'Kosa'),
    ],
    authRepository: FakeAuthRepository(
      pocetnaSesija: FakeAuthRepository.sesijaNakonPrijave,
    ),
    // Galerija sa slikama: Početna i `/gallery` tada crtaju `AppTappable` mete.
    galerija: [for (var i = 1; i <= 6; i++) 'https://primjer.test/$i.jpg'],
    pumpaj: false,
  );
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = skala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Drugi prelaz: `AnimatedTheme` tenanta se završi u frejmu iznad, a tek tada dugmad
  // krenu svoj `AnimatedDefaultTextStyle` od stare boje teksta. Mjereno u tom frejmu,
  // natpis na beauty temi je još bijel (1,03:1) — mjerenje u pogrešnom trenutku, ista
  // zamka kao u `tenant_theme_test.dart`.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final ruta in _rute) {
    testWidgets('$ruta mete', (tester) async {
      final h = tester.ensureSemantics();
      await _telefon(tester, ruta);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      _expectSveMeteFokusabilne(tester);
      h.dispose();
    });
    for (final tenant in kTenants.values) {
      testWidgets('$ruta kontrast — ${tenant.flavor}', (tester) async {
        final h = tester.ensureSemantics();
        await _telefon(tester, ruta, tenant: tenant);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }
    testWidgets('$ruta 130%', (tester) async {
      await _telefon(tester, ruta, skala: 1.3);
      // Bez `takeException`: presječen red je `FlutterError` koji framework sam prijavi
      // kao pad testa — sa widgetom i brojem reda, koje bi `takeException` progutao.
    });
  }
}

/// Svaki čvor koji prima tap mora primiti i fokus — blizanac provjere iz
/// `apps/admin/test/support/pristupacnost.dart`. Dvije kopije, jer aplikacije ne dijele
/// test kod, a `core_ui` ga ne smije nositi u `lib/`.
void _expectSveMeteFokusabilne(WidgetTester tester) {
  final korijen = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final bez = <String>[];
  void obidji(SemanticsNode cvor) {
    final data = cvor.getSemanticsData();
    if (data.hasAction(SemanticsAction.tap) &&
        data.flagsCollection.isFocused == Tristate.none &&
        !cvor.isInvisible) {
      bez.add('"${data.label}" ${cvor.rect}');
    }
    cvor.visitChildren((d) {
      obidji(d);
      return true;
    });
  }

  obidji(korijen);
  expect(bez, isEmpty, reason: 'tap bez fokusa — tastatura ne dolazi do: $bez');
}
