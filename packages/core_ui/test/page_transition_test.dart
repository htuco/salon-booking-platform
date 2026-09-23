import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _tema(TargetPlatform platforma) => buildAppTheme(
  primary: const Color(0xFFC6A667),
  secondary: const Color(0xFF171717),
).copyWith(platform: platforma);

Future<GlobalKey<NavigatorState>> _app(
  WidgetTester tester, {
  TargetPlatform platforma = TargetPlatform.iOS,
  bool bezAnimacija = false,
}) async {
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: bezAnimacija),
      child: MaterialApp(
        navigatorKey: nav,
        theme: _tema(platforma),
        home: const Scaffold(body: Text('prvi')),
      ),
    ),
  );
  return nav;
}

void _otvoriDrugi(GlobalKey<NavigatorState> nav) => nav.currentState!.push(
  MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Center(child: Text('drugi'))),
  ),
);

double _pomakDrugog(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.text('drugi'), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  test('isti builder je registrovan za svaku platformu', () {
    final builders = _tema(TargetPlatform.android)
        .pageTransitionsTheme
        .builders;
    for (final platforma in TargetPlatform.values) {
      expect(
        builders[platforma],
        isA<AppPageTransitionsBuilder>(),
        reason: '$platforma',
      );
    }
  });

  test('push 220 ms, pop 180 ms — ispod 300 ms iz docs/02 §14', () {
    const b = AppPageTransitionsBuilder();
    expect(b.transitionDuration, const Duration(milliseconds: 220));
    expect(b.reverseTransitionDuration, const Duration(milliseconds: 180));
  });

  for (final platforma in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('push traje 220 ms i pomjera novi ekran po X ($platforma)', (
      tester,
    ) async {
      final nav = await _app(tester, platforma: platforma);
      _otvoriDrugi(nav);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final pocetak = _pomakDrugog(tester);
      expect(pocetak, greaterThan(0));
      expect(pocetak, lessThanOrEqualTo(AppPageTransitionsBuilder.pomak));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_pomakDrugog(tester), 0);
      // Ticker zatvara animaciju u sljedećem frameu.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('Reduce Motion: samo fade, bez pomaka', (tester) async {
    final nav = await _app(tester, bezAnimacija: true);
    _otvoriDrugi(nav);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final pomaci = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.text('drugi'),
            matching: find.byType(Transform),
          ),
        )
        .map((t) => t.transform.getTranslation().x);
    expect(pomaci.every((x) => x == 0), isTrue);
    expect(
      find.ancestor(
        of: find.text('drugi'),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
  });

  testWidgets('iOS: povlačenje sa lijeve ivice vraća nazad', (tester) async {
    final nav = await _app(tester);
    _otvoriDrugi(nav);
    await tester.pumpAndSettle();
    expect(find.text('drugi'), findsOneWidget);

    await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('drugi'), findsNothing);
    expect(find.text('prvi'), findsOneWidget);
  });

  testWidgets('iOS: kratko povlačenje se vraća, ekran ostaje', (tester) async {
    final nav = await _app(tester);
    _otvoriDrugi(nav);
    await tester.pumpAndSettle();

    final gest = await tester.startGesture(const Offset(5, 300));
    await gest.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gest.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gest.up();
    await tester.pumpAndSettle();
    expect(find.text('drugi'), findsOneWidget);
  });

  testWidgets('Android: nema povlačenja sa ivice', (tester) async {
    final nav = await _app(tester, platforma: TargetPlatform.android);
    _otvoriDrugi(nav);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('drugi'), findsOneWidget);
  });
}
