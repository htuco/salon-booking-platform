import 'package:admin/src/core/theme/admin_theme.dart';
import 'package:admin/src/core/widgets/admin_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Size velicina = const Size(1440, 900)}) =>
    MaterialApp(
      theme: buildAdminTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: velicina.width,
            height: velicina.height,
            child: child,
          ),
        ),
      ),
    );

void main() {
  testWidgets('kostur se crta umjesto spinnera', (tester) async {
    await tester.pumpWidget(_app(const AdminSkeletonList()));
    await tester.pump();

    expect(find.byType(AdminSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('lista se skracuje umjesto da prelije uski prikaz', (
    tester,
  ) async {
    // Regresija: prva verzija je crtala fiksnih šest redova i prelivala za 68 px.
    // Kostur koji prelijeva je gori od spinnera — prelivanje ostane i poslije.
    await tester.pumpWidget(
      _app(const AdminSkeletonList(), velicina: const Size(400, 120)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // U 120 px stanu najviše dva reda od 44 px sa razmakom od 12.
    expect(find.byType(AdminSkeleton), findsNWidgets(2));
  });

  testWidgets('bez animacija kostur miruje, ali se i dalje vidi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const AdminSkeletonList(redova: 2)),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AdminSkeleton).first,
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
      reason: 'Uz reduce motion kostur ne pulsira',
    );
    expect(find.byType(AdminSkeleton), findsNWidgets(2));
  });

  testWidgets('dugme u radnji nosi tacke, ne Material spinner', (tester) async {
    await tester.pumpWidget(_app(const AdminButtonBusy()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.bySemanticsLabel('Radnja je u toku'),
      findsOneWidget,
      reason: 'Stanje radnje mora biti citljivo i citacu ekrana',
    );
  });
}
