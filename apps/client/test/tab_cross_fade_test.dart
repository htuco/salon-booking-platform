import 'package:client/src/core/router/tab_cross_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Broji `build` po tabu — dokaz da promjena taba ne gradi ostale tabove iznova.
final Map<int, int> _gradnje = {};

class _Tab extends StatefulWidget {
  const _Tab(this.broj);
  final int broj;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int brojac = 0;

  @override
  Widget build(BuildContext context) {
    _gradnje.update(widget.broj, (n) => n + 1, ifAbsent: () => 1);
    return ColoredBox(
      color: Colors.white,
      child: TextButton(
        onPressed: () => setState(() => brojac++),
        child: Text('tab ${widget.broj}: $brojac'),
      ),
    );
  }
}

// Iste instance kroz sve pumpe, kao što `go_router` drži navigator po grani.
const _tabovi = [_Tab(0), _Tab(1), _Tab(2)];

Widget _app(int indeks, {bool bezAnimacija = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: bezAnimacija),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: TabCrossFade(currentIndex: indeks, children: _tabovi),
  ),
);

double _providnost(WidgetTester tester, String tekst) => tester
    .widget<FadeTransition>(
      find.ancestor(
        of: find.text(tekst),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  setUp(_gradnje.clear);

  testWidgets('pretapanje traje 120 ms, bez pomaka', (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 60));

    // Na pola: dolazeći je djelimično providan, odlazeći pun i još na ekranu.
    expect(_providnost(tester, 'tab 1: 0'), closeTo(0.5, 0.05));
    expect(find.text('tab 0: 0'), findsOneWidget);
    expect(_providnost(tester, 'tab 0: 0'), 1);
    expect(find.byType(SlideTransition), findsNothing);

    await tester.pump(const Duration(milliseconds: 61));
    expect(find.text('tab 0: 0'), findsNothing);
    expect(_providnost(tester, 'tab 1: 0'), 1);
  });

  testWidgets('tab pamti stanje kroz prebacivanje', (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.tap(find.text('tab 0: 0'));
    await tester.pump();
    expect(find.text('tab 0: 1'), findsOneWidget);

    await tester.pumpWidget(_app(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(0));
    await tester.pumpAndSettle();
    expect(find.text('tab 0: 1'), findsOneWidget);
  });

  testWidgets('promjena taba ne gradi ostale tabove iznova', (tester) async {
    await tester.pumpWidget(_app(0));
    final prije = Map.of(_gradnje);
    await tester.pumpWidget(_app(1));
    await tester.pumpAndSettle();
    expect(_gradnje[2], prije[2], reason: 'tab 2 nije dirnut');
    expect(_gradnje[0], prije[0], reason: 'odlazeći tab se ne gradi iznova');
  });

  testWidgets('odlazeći tab ne prima dodir', (tester) async {
    await tester.pumpWidget(_app(0));
    await tester.pumpWidget(_app(1));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.text('tab 0: 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(0));
    await tester.pumpAndSettle();
    expect(find.text('tab 0: 0'), findsOneWidget);
  });

  testWidgets('Reduce Motion: prebacivanje bez pretapanja', (tester) async {
    await tester.pumpWidget(_app(0, bezAnimacija: true));
    await tester.pumpWidget(_app(1, bezAnimacija: true));
    await tester.pump();
    expect(find.text('tab 0: 0'), findsNothing);
    expect(_providnost(tester, 'tab 1: 0'), 1);
  });
}
