import 'dart:ui' as ui;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/auth/admin_lava_panel.dart';
import 'package:admin/src/features/auth/pozivnica_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lava shader loads, paints, pauses and disposes', (tester) async {
    // Explicitly await asset IO: ordinary widget pumps can finish before loading.
    final program = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/admin_lava.frag'),
    );
    expect(program, isNotNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: const Scaffold(body: AdminLavaPanel()),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion leaves the lava composition still', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(400, 800), disableAnimations: true),
          child: Scaffold(body: AdminLavaPanel(hero: true)),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1440, 900), const Size(402, 874)]) {
    testWidgets('invitation layout and fields at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAdminTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AdminPozivnicaScreen(kod: 'ABCDEF'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byType(AdminLavaPanel);
      expect(panel, findsOneWidget);
      expect(
        tester.getSize(panel),
        size.width >= 1000
            ? Size(size.width - 560, size.height)
            : Size(size.width, 280),
      );
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('ABCDEF'), findsOneWidget);
      if (size.width < 1000) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Napravi nalog'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
