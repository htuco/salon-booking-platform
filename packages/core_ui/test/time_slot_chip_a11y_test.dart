import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Slotovi termina — FE-502 ih imenuje izričito: mete ≥ 44 px, kontrast na svakoj temi,
/// i 130 % fonta u mreži od tri kolone na 390 px, kako ih crta korak 3 booking flowa.
///
/// Korak 3 traži izabranu uslugu i radnika, pa ga `accessibility_test.dart` klijenta ne
/// podiže; chip se zato mjeri ovdje, u istoj mreži koju ekran koristi.
void main() {
  Widget mreza(AppTheme tema) => MaterialApp(
    theme: buildAppTheme(
      primary: const Color(0xFFB76E79),
      secondary: const Color(0xFFFFF5F5),
      themeName: tema.key,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 110 / AppSize.timeSlot,
          children: [
            TimeSlotChip(label: '09:00', onTap: () {}),
            TimeSlotChip(label: '09:30', selected: true, onTap: () {}),
            const TimeSlotChip(label: '10:00', onTap: null),
          ],
        ),
      ),
    ),
  );

  Future<void> podigni(WidgetTester tester, AppTheme tema) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(mreza(tema));
    await tester.pumpAndSettle();
  }

  for (final tema in AppTheme.values) {
    testWidgets('${tema.key}: mete ≥ 44 px i kontrast', (tester) async {
      final semantika = tester.ensureSemantics();
      await podigni(tester, tema);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantika.dispose();
    });
  }

  testWidgets('130 % fonta ne presijeca chip', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await podigni(tester, AppTheme.modernBarber);
  });
}
