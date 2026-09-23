import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _tema = buildAppTheme(
  primary: const Color(0xFFB76E79),
  secondary: const Color(0xFF171717),
  themeName: 'beauty_salon',
);

Future<BuildContext> _app(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: _tema,
      home: Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return ctx;
}

double _skala(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.ancestor(
        of: find.text('modal'),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

ModalBarrier _scrim(WidgetTester tester) =>
    tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last;

void main() {
  group('dijalog', () {
    testWidgets('raste sa 0,98 na 1 za 180 ms, bez grow-from-center', (
      tester,
    ) async {
      final ctx = await _app(tester);
      AppModal.dialog<void>(
        ctx,
        builder: (_) => const Center(child: Text('modal')),
      );
      await tester.pump();
      expect(_skala(tester), closeTo(AppModal.dialogPocetnaSkala, 0.001));

      await tester.pump(const Duration(milliseconds: 90));
      final sredina = _skala(tester);
      expect(sredina, greaterThan(0.98));
      expect(sredina, lessThan(1));

      // Na 150 ms još raste — kraći prelaz (npr. Materialovih 150) ovdje pada.
      await tester.pump(const Duration(milliseconds: 60));
      expect(_skala(tester), lessThan(1));

      await tester.pump(const Duration(milliseconds: 31));
      expect(_skala(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('scrim je neutralni token teme, ne brand boja', (tester) async {
      final ctx = await _app(tester);
      AppModal.dialog<void>(
        ctx,
        builder: (_) => const Center(child: Text('modal')),
      );
      await tester.pumpAndSettle();
      final boja = (_scrim(tester).color as Color);
      expect(boja, _tema.colorScheme.scrim);
      expect(boja, isNot(_tema.colorScheme.primary));
    });

    testWidgets('zatvara se dodirom na scrim', (tester) async {
      final ctx = await _app(tester);
      AppModal.dialog<void>(
        ctx,
        builder: (_) => const Center(child: Text('modal')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('modal'), findsNothing);
    });

    testWidgets('zatvara se sistemskim nazad', (tester) async {
      final ctx = await _app(tester);
      AppModal.dialog<void>(
        ctx,
        builder: (_) => const Center(child: Text('modal')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('modal'), findsNothing);
    });

    testWidgets('busy: scrim ne zatvara', (tester) async {
      final ctx = await _app(tester);
      AppModal.dialog<void>(
        ctx,
        barrierDismissible: false,
        builder: (_) => const Center(child: Text('modal')),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('modal'), findsOneWidget);
    });

    testWidgets('AppDialog.show ide kroz istu animaciju', (tester) async {
      final ctx = await _app(tester);
      AppDialog.show(
        ctx,
        dialog: const AppDialog(
          title: 'modal',
          message: 'poruka',
          confirmLabel: 'Da',
          cancelLabel: 'Ne',
        ),
      );
      await tester.pump();
      expect(_skala(tester), closeTo(AppModal.dialogPocetnaSkala, 0.001));
      await tester.pumpAndSettle();
    });
  });

  group('bottom sheet', () {
    testWidgets('klizi 240 ms i zatvara se povlačenjem nadolje', (
      tester,
    ) async {
      final ctx = await _app(tester);
      AppModal.sheet<void>(
        ctx,
        builder: (_) => const SizedBox(height: 300, child: Text('sheet')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final vrhSredina = tester.getTopLeft(find.text('sheet')).dy;
      await tester.pump(const Duration(milliseconds: 121));
      final vrhKraj = tester.getTopLeft(find.text('sheet')).dy;
      expect(vrhSredina, greaterThan(vrhKraj), reason: 'još klizi na 120 ms');
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.drag(find.text('sheet'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
    });

    testWidgets('scrim sheeta je isti token', (tester) async {
      final ctx = await _app(tester);
      AppModal.sheet<void>(ctx, builder: (_) => const Text('sheet'));
      await tester.pumpAndSettle();
      expect(_scrim(tester).color, _tema.colorScheme.scrim);
    });
  });

  // Tastatura: Escape zatvara dijalog (web i desktop).
  testWidgets('Escape zatvara dijalog', (tester) async {
    final ctx = await _app(tester);
    AppModal.dialog<void>(
      ctx,
      builder: (_) => const Center(child: Text('modal')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('modal'), findsNothing);
  });
}
