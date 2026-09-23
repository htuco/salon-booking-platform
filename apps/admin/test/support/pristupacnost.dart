/// Provjera pristupačnosti jednog admin ekrana — FE-502.
///
/// Namjerno **ne** nosi svoj harness: svaki test fajl ekrana već zna podići ekran sa
/// svojim override-ima, pa ovdje dolazi gotov widget. Druga kopija override liste bi se
/// razišla sa prvom pri prvoj izmjeni providera, i to tiho.
///
/// Šta se mjeri, na obje širine iz handoffa (1440×900 i 402×874):
/// - dodirne mete ≥ 44×44 (`docs/02 §14`, iOS HIG), svaka meta ima labelu i svaka se
///   može fokusirati — fokus koji se ne može dobiti ne može se ni vidjeti;
/// - kontrast teksta po WCAG-u (4,5:1 tekst, 3:1 veliki tekst) na stvarno iscrtanim
///   pikselima, ne na tokenima;
/// - na telefonu, sistemski font uvećan na 130 % ne presijeca nijedan red.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const Size kDesktop = Size(1440, 900);
const Size kTelefon = Size(402, 874);

/// Registruje testove za ekran koji gradi [ekran].
///
/// [mjeriKontrast] se gasi samo uz napisan razlog: `textContrastGuideline` čita piksele
/// ispod teksta, pa slika ili gradijent mogu dati lažan pad.
void pristupacnostEkrana(
  String ime,
  Widget Function() ekran, {
  bool mjeriKontrast = true,
}) => pristupacnostPodignutog(
  ime,
  (tester, velicina) => _podigni(tester, velicina, ekran()),
  mjeriKontrast: mjeriKontrast,
);

/// Isto kao [pristupacnostEkrana], za test fajl čiji harness sam pumpa ekran (npr.
/// `employees_screen_test.dart`) umjesto da vraća widget.
void pristupacnostPodignutog(
  String ime,
  Future<void> Function(WidgetTester tester, Size velicina) podigni, {
  bool mjeriKontrast = true,
}) {
  group('$ime — pristupačnost (FE-502)', () {
    for (final (sirina, velicina) in [
      ('desktop', kDesktop),
      ('telefon', kTelefon),
    ]) {
      testWidgets('$sirina: mete ≥ 44 px i sa labelom', (tester) async {
        final semantika = tester.ensureSemantics();
        await podigni(tester, velicina);
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expectSveMeteFokusabilne(tester);
        semantika.dispose();
      });

      if (mjeriKontrast) {
        testWidgets('$sirina: kontrast teksta po WCAG-u', (tester) async {
          final semantika = tester.ensureSemantics();
          await podigni(tester, velicina);
          await tester.pump(const Duration(milliseconds: 400));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantika.dispose();
        });
      }
    }

    testWidgets('telefon: font 130 % ne presijeca nijedan red', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await podigni(tester, kTelefon);
      await tester.pump(const Duration(milliseconds: 400));
      // Bez `takeException`: presječen red je `FlutterError` koji framework sam prijavi
      // kao pad testa — sa widgetom i brojem reda, koje bi `takeException` progutao.
    });
  });
}

Future<void> _podigni(WidgetTester tester, Size velicina, Widget w) async {
  tester.view
    ..physicalSize = velicina
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  // Ne `pumpAndSettle`: skeleton pulsira dok je vidljiv (FE-205) i istekao bi.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Svaki čvor koji prima tap mora primiti i fokus (FE-502).
///
/// Material kontrole crtaju fokus same; ono što ga ne crta je meta koju tastatura uopšte ne
/// dohvata — goli `GestureDetector`. Na webu je to kontrola do koje korisnik bez miša ne
/// dolazi, pa se ne pita „vidi li se fokus" nego „postoji li".
void expectSveMeteFokusabilne(WidgetTester tester) {
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
