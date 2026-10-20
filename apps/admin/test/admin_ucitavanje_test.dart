import 'package:admin/src/core/theme/admin_colors.dart';
import 'package:admin/src/core/theme/admin_theme.dart';
import 'package:admin/src/core/widgets/admin_ucitavanje.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool bezAnimacija = false, bool tamna = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: bezAnimacija),
      child: MaterialApp(
        theme: buildAdminTheme(),
        darkTheme: buildAdminTheme(Brightness.dark),
        themeMode: tamna ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: Center(child: child)),
      ),
    );

TerminISadaPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TerminISadaPainter>()
    .single;

void main() {
  group('pokret je prepis SVG-a', () {
    test('od vrha do dna termina i nazad', () {
      expect(pomakSada(0), closeTo(-34, 1e-9));
      expect(pomakSada(0.5), closeTo(34, 1e-9));
      expect(pomakSada(0.999), closeTo(-34, 0.01));
    });

    test('kriva se primjenjuje na svaku polovinu, kao CSS keyframes', () {
      // Nazad je ogledalo puta naprijed: ista kriva, obrnut smjer.
      for (final t in [0.1, 0.2, 0.3, 0.4]) {
        expect(pomakSada(t + 0.5), closeTo(-pomakSada(t), 1e-9));
      }
      // `cubic-bezier(.45, 0, .25, 1)` polako kreće: na desetini prolaza linija je
      // prešla manje od desetine puta.
      expect(pomakSada(0.05), lessThan(-34 + 68 * 0.1));
    });
  });

  testWidgets('linija klizi, termin stoji; boje iz palete', (tester) async {
    await tester.pumpWidget(_app(const AdminUcitavanje()));

    final prije = _painter(tester);
    expect(prije.termin, AdminPalette.light.action);
    expect(prije.sada, AdminPalette.light.nowLine);
    expect(prije.tacka, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).pomak, isNot(prije.pomak));

    expect(find.bySemanticsLabel('Učitavanje'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tamna tema uzima tamnu liniju', (tester) async {
    await tester.pumpWidget(_app(const AdminUcitavanje(), tamna: true));
    expect(_painter(tester).sada, AdminPalette.dark.nowLine);
    expect(_painter(tester).termin, AdminPalette.dark.action);
  });

  testWidgets('bez animacija linija stoji na sredini i ništa ne vrti kadrove', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AdminUcitavanje(), bezAnimacija: true));
    expect(_painter(tester).pomak, 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).pomak, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('dugme: linija bez tačke, u boji teksta dugmeta', (tester) async {
    const boja = Color(0xFF2C2C2C);
    await tester.pumpWidget(_app(const AdminButtonBusy(color: boja)));

    final p = _painter(tester);
    expect(p.tacka, isFalse, reason: 'Na 20 px tačka i linija se stope');
    expect(p.sada, boja);
    expect(p.termin, boja.withValues(alpha: 0.35));
    expect(
      find.bySemanticsLabel('Radnja je u toku'),
      findsOneWidget,
      reason: 'Stanje radnje mora biti čitljivo i čitaču ekrana',
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).pomak, isNot(p.pomak));
  });

  testWidgets('dugme bez animacija miruje', (tester) async {
    await tester.pumpWidget(_app(const AdminButtonBusy(), bezAnimacija: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).pomak, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
