/// `AppHeader` — korijen taba bez naslova, detalj sa inline naslovom i „nazad".
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/app_header.dart';
import 'package:admin/src/core/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const Size _telefon = Size(402, 874);

Widget _lista() => ListView.builder(
  itemCount: 60,
  itemBuilder: (_, i) => SizedBox(height: 56, child: Text('red $i')),
);

Widget _ekran(AppHeader header, {double tekst = 1}) => MaterialApp(
  theme: buildAdminTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      size: _telefon,
      padding: const EdgeInsets.only(top: 47),
      textScaler: TextScaler.linear(tekst),
    ),
    child: Scaffold(
      body: AppHeaderLayout(header: header, body: _lista()),
    ),
  ),
);

Future<void> _podigni(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = _telefon;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

double _providnost(WidgetTester tester, String kljuc) =>
    tester.widget<Opacity>(find.byKey(ValueKey(kljuc))).opacity;

Future<void> _skrolaj(WidgetTester tester, double koliko) async {
  await tester.drag(find.text('red 3'), Offset(0, -koliko));
  await tester.pump();
}

void main() {
  testWidgets('korijen taba nema naslov — ime nosi donja traka', (
    tester,
  ) async {
    await _podigni(tester, _ekran(AppHeader(title: 'Kalendar')));

    expect(find.text('Kalendar'), findsNothing);
    expect(find.byKey(const ValueKey('app-header-inline')), findsNothing);
  });

  testWidgets('korijen taba bez akcija nema ni traku, `bottom` ostaje', (
    tester,
  ) async {
    await _podigni(
      tester,
      _ekran(AppHeader(title: 'Zahtjevi', bottom: const Text('prekidač'))),
    );

    expect(find.text('prekidač'), findsOneWidget);
    // 47 safe area + 48 `bottom` + hairline: traka od 44 px se ne crta.
    expect(tester.getTopLeft(find.text('red 0')).dy, closeTo(47 + 48 + 0.5, 1));
  });

  testWidgets('korijen taba sa akcijama zadržava traku, bez naslova', (
    tester,
  ) async {
    await _podigni(
      tester,
      _ekran(
        AppHeader(
          title: 'Kalendar',
          actions: [
            HeaderAction(icon: Icons.add, semanticLabel: 'Novo', onTap: () {}),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Novo'), findsOneWidget);
    expect(find.text('Kalendar'), findsNothing);
  });

  testWidgets('scroll tijela upali liniju ispod zaglavlja', (tester) async {
    await _podigni(tester, _ekran(AppHeader(title: 'Termin', tabRoot: false)));
    expect(_providnost(tester, 'app-header-linija'), 0);

    await _skrolaj(tester, 4);
    expect(_providnost(tester, 'app-header-linija'), closeTo(0.5, 0.2));

    await _skrolaj(tester, 200);
    expect(_providnost(tester, 'app-header-linija'), 1);
  });

  testWidgets('detalj u grani ima inline naslov', (tester) async {
    await _podigni(tester, _ekran(AppHeader(title: 'Termin', tabRoot: false)));
    expect(find.text('Termin'), findsOneWidget);
  });

  testWidgets('forma: „Sačuvaj" je ugašen dok forma nije ispravna', (
    tester,
  ) async {
    await _podigni(
      tester,
      _ekran(
        AppHeader.forma(title: 'Novi termin', onCancel: () {}, onSave: null),
      ),
    );
    expect(find.text('Otkaži'), findsOneWidget);
    final sacuvaj = find.ancestor(
      of: find.text('Sačuvaj'),
      matching: find.byType(Pressable),
    );
    expect(tester.widget<Pressable>(sacuvaj).onTap, isNull);
    final providnost = tester.widget<Opacity>(
      find.ancestor(of: sacuvaj, matching: find.byType(Opacity)).first,
    );
    expect(providnost.opacity, 0.45);
  });

  test('više od dvije akcije je greška', () {
    HeaderAction akcija() =>
        HeaderAction(icon: Icons.add, semanticLabel: 'a', onTap: () {});
    expect(
      () => AppHeader(title: 'x', actions: [akcija(), akcija(), akcija()]),
      throwsAssertionError,
    );
  });

  testWidgets('130 % sistemskog fonta ne preliva zaglavlje', (tester) async {
    await _podigni(
      tester,
      _ekran(
        AppHeader(
          title: 'Barber Studio Vitez sa jako dugim imenom',
          tabRoot: false,
          actions: [
            HeaderAction(icon: Icons.add, semanticLabel: 'Novo', onTap: () {}),
          ],
        ),
        tekst: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('u grani je lijevo „nazad" sa imenom ekrana ispod', (
    tester,
  ) async {
    final ruter = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (_, _) => const Text('kalendar'),
          routes: [
            GoRoute(
              path: 'appointment/:id',
              builder: (_, _) => Scaffold(
                body: AppHeaderLayout(
                  header: AppHeader(title: 'Termin', tabRoot: false),
                  body: _lista(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    tester.view.physicalSize = _telefon;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAdminTheme(), routerConfig: ruter),
    );
    ruter.push('/calendar/appointment/1');
    await tester.pumpAndSettle();

    expect(find.text('Kalendar'), findsOneWidget);
    expect(find.bySemanticsLabel('Nazad na Kalendar'), findsOneWidget);

    await tester.tap(find.text('Kalendar'));
    await tester.pumpAndSettle();
    expect(find.text('kalendar'), findsOneWidget);
  });
}
