import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppTappable` — FE-502: meta preko slike se dohvata tastaturom i fokus se na njoj vidi.
void main() {
  const primary = Color(0xFFC6A667);

  Future<List<int>> podigni(WidgetTester tester) async {
    final tapovi = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: primary),
        ),
        home: Scaffold(
          body: Row(
            children: [
              for (final i in [0, 1])
                AppTappable(
                  key: ValueKey(i),
                  semanticLabel: 'Fotografija ${i + 1}',
                  onTap: () => tapovi.add(i),
                  child: const SizedBox(width: 80, height: 80),
                ),
            ],
          ),
        ),
      ),
    );
    return tapovi;
  }

  /// Okvir prstena fokusa — `null` kad prstena nema.
  Border? prsten(WidgetTester tester, int i) {
    final kutija = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(ValueKey(i)),
        matching: find.byType(DecoratedBox),
      ),
    );
    return (kutija.decoration as BoxDecoration).border as Border?;
  }

  testWidgets('Tab dolazi do mete i crta prsten u primary boji', (
    tester,
  ) async {
    await podigni(tester);
    expect(prsten(tester, 0), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final okvir = prsten(tester, 0);
    expect(okvir, isNotNull, reason: 'fokus mora biti vidljiv');
    expect(okvir!.top.color, primary);
    expect(okvir.top.width, AppTappable.focusRingWidth);
    expect(
      prsten(tester, 1),
      isNull,
      reason: 'prsten nosi samo fokusirana meta',
    );
  });

  testWidgets('Enter i Space aktiviraju fokusiranu metu', (tester) async {
    final tapovi = await podigni(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(tapovi, [1, 1]);
  });

  testWidgets('tap prstom i dalje radi, bez prstena', (tester) async {
    final tapovi = await podigni(tester);
    await tester.tap(find.byKey(const ValueKey(0)));
    await tester.pump();
    expect(tapovi, [0]);
    expect(prsten(tester, 0), isNull);
  });

  testWidgets('čitač ekrana vidi dugme sa imenom', (tester) async {
    final semantika = tester.ensureSemantics();
    await podigni(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey(0))),
      matchesSemantics(
        label: 'Fotografija 1',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantika.dispose();
  });
}
