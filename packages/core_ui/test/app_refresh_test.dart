import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppRefresh` — FE-501. Gestu daje `RefreshIndicator.noSpinner`; ovdje se mjeri da
/// povlačenje stvarno zove izvor i da se Material spinner nigdje ne crta.
void main() {
  Future<Completer<void>> pumpaj(
    WidgetTester tester, {
    required void Function() onPoziv,
  }) async {
    final zavrsetak = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefresh(
            onRefresh: () {
              onPoziv();
              return zavrsetak.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 80, child: Text('Red'))],
            ),
          ),
        ),
      ),
    );
    return zavrsetak;
  }

  testWidgets('povlačenje zove onRefresh, bez Material spinnera', (
    tester,
  ) async {
    var pozivi = 0;
    final zavrsetak = await pumpaj(tester, onPoziv: () => pozivi++);

    await tester.fling(find.text('Red'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(pozivi, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    // Sadržaj ostaje dok traje osvježavanje; skeleton bi ga zamijenio.
    expect(find.text('Red'), findsOneWidget);

    zavrsetak.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('traka stoji dok traje, nestaje kad se završi', (tester) async {
    final zavrsetak = await pumpaj(tester, onPoziv: () {});

    Finder traka() => find.descendant(
      of: find.byType(AppRefresh),
      matching: find.byType(AnimatedBuilder),
    );

    await tester.fling(find.text('Red'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(traka(), findsWidgets);

    zavrsetak.complete();
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(AppRefresh),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0);
  });
}
