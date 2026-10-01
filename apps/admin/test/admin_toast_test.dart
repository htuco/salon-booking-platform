/// Toast admina — pravila iz `prototype/adminv2/toast/README.md`.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/admin_toast.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

late BuildContext _ctx;

Future<void> _podigni(WidgetTester tester, Size velicina) async {
  tester.view
    ..physicalSize = velicina
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAdminTheme(),
      builder: (context, child) => AdminToastSloj(child: child!),
      home: Builder(
        builder: (context) {
          _ctx = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
}

void main() {
  testWidgets('uspjeh se sam skloni za 5 s, hover zaustavlja odbrojavanje', (
    tester,
  ) async {
    await _podigni(tester, kDesktop);
    AdminToast.uspjeh(_ctx, 'Termin potvrđen', opis: 'Haris Delić · 14:20');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Termin potvrđen'), findsOneWidget);
    expect(find.text('Haris Delić · 14:20'), findsOneWidget);

    final mis = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mis.addPointer(
      location: tester.getCenter(find.text('Termin potvrđen')),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(
      find.text('Termin potvrđen'),
      findsOneWidget,
      reason: 'hover pauzira',
    );

    await mis.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Termin potvrđen'), findsNothing);
  });

  testWidgets('greška stoji dok se ne zatvori ×', (tester) async {
    final semantika = tester.ensureSemantics();
    await _podigni(tester, kDesktop);
    AdminToast.greska(_ctx, 'Slanje nije uspjelo');
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Slanje nije uspjelo'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Zatvori'));
    await tester.pumpAndSettle();
    expect(find.text('Slanje nije uspjelo'), findsNothing);
    semantika.dispose();
  });

  testWidgets('akcija je u verzalu, izvrši se i zatvori toast', (tester) async {
    await _podigni(tester, kDesktop);
    var pozvano = 0;
    AdminToast.upozorenje(
      _ctx,
      'Termin se preklapa',
      akcija: AdminToastAkcija('Prikaži', () => pozvano++),
    );
    final semantika = tester.ensureSemantics();
    await tester.pumpAndSettle();
    expect(find.text('PRIKAŽI'), findsOneWidget);
    expect(find.bySemanticsLabel('Prikaži'), findsOneWidget);

    await tester.tap(find.text('PRIKAŽI'));
    await tester.pumpAndSettle();
    expect(pozvano, 1);
    expect(find.text('Termin se preklapa'), findsNothing);
    semantika.dispose();
  });

  testWidgets('desktop: najviše tri, najnoviji gore desno ispod top bara', (
    tester,
  ) async {
    await _podigni(tester, kDesktop);
    for (final n in ['Jedan', 'Dva', 'Tri', 'Četiri']) {
      AdminToast.greska(_ctx, n);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.text('Jedan'), findsNothing, reason: 'najstariji ispada');
    final y = [
      for (final n in ['Četiri', 'Tri', 'Dva'])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue, reason: 'najnoviji na vrhu: $y');

    final kartica = tester.getRect(
      find
          .ancestor(
            of: find.text('Četiri'),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    expect(kartica.top, AdminSize.topBarHeight + 16);
    expect(kartica.right, kDesktop.width - 24);
    expect(kartica.width, 360);
  });

  testWidgets('telefon: jedan po jedan, povlačenje gore zatvara', (
    tester,
  ) async {
    await _podigni(tester, kTelefon);
    AdminToast.greska(_ctx, 'Stari');
    await tester.pumpAndSettle();
    AdminToast.greska(_ctx, 'Novi');
    await tester.pumpAndSettle();
    expect(find.text('Stari'), findsNothing);
    expect(find.text('Novi'), findsOneWidget);

    await tester.drag(find.text('Novi'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('Novi'), findsNothing);
  });

  testWidgets('isti naslov dvaput je jedan toast', (tester) async {
    await _podigni(tester, kDesktop);
    AdminToast.upozorenje(_ctx, 'Osvježavanje nije dostupno');
    AdminToast.upozorenje(_ctx, 'Osvježavanje nije dostupno');
    await tester.pumpAndSettle();
    expect(find.text('Osvježavanje nije dostupno'), findsOneWidget);
  });

  testWidgets('toast stoji iznad dijaloga otvorenog poslije njega', (
    tester,
  ) async {
    await _podigni(tester, kDesktop);
    AdminToast.greska(_ctx, 'Iznad');
    await tester.pumpAndSettle();
    showDialog<void>(
      context: _ctx,
      builder: (_) =>
          const AlertDialog(content: SizedBox(width: 2000, height: 2000)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Iznad').hitTestable(), findsOneWidget);
  });

  testWidgets('dodirne mete toasta su ≥ 44 px', (tester) async {
    await _podigni(tester, kTelefon);
    AdminToast.greska(
      _ctx,
      'Slanje nije uspjelo',
      akcija: AdminToastAkcija('Pokušaj ponovo', () {}),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
