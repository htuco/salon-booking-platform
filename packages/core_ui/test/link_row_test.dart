import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart' show barberPrimary, barberSecondary;

/// [LinkRow] ima tri stanja i razlika među njima je ono što se ovdje mjeri.
///
/// Onemogućen red je razlog zbog kojeg komponenta uopšte ima treće stanje: „Ocijenite
/// aplikaciju" mora ostati **vidljiv** dok app nije u prodavnici, ali ne smije primiti
/// dodir. Red koji nestane pa se vrati kad app ode u store je lista koja se mijenja pod
/// korisnikom; red koji se tapne i ne uradi ništa je kvar.
Widget _uTemi(Widget dijete) => MaterialApp(
  theme: buildAppTheme(primary: barberPrimary, secondary: barberSecondary),
  home: Scaffold(body: dijete),
);

void main() {
  group('LinkRow', () {
    testWidgets('red sa akcijom nosi chevron i reaguje na dodir', (
      tester,
    ) async {
      var tapnut = 0;
      await tester.pumpWidget(
        _uTemi(LinkRow(label: 'Pravila korištenja', onTap: () => tapnut++)),
      );

      expect(find.text('Pravila korištenja'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);

      await tester.tap(find.text('Pravila korištenja'));
      expect(tapnut, 1);
    });

    testWidgets('red bez akcije nema chevron', (tester) async {
      await tester.pumpWidget(_uTemi(const LinkRow(label: 'Jezik · Bosanski')));

      expect(find.text('Jezik · Bosanski'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('onemogućen red ostaje vidljiv, sa chevronom i objašnjenjem', (
      tester,
    ) async {
      await tester.pumpWidget(
        _uTemi(
          const LinkRow(
            label: 'Ocijenite aplikaciju',
            note: 'Aktivira se kad aplikacija bude objavljena.',
            disabled: true,
          ),
        ),
      );

      expect(find.text('Ocijenite aplikaciju'), findsOneWidget);
      expect(
        find.text('Aktivira se kad aplikacija bude objavljena.'),
        findsOneWidget,
      );
      // Chevron ostaje: red **jeste** link, samo još ne vodi nigdje.
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('onemogućen red ne prima dodir i nosi 45% prozirnosti', (
      tester,
    ) async {
      await tester.pumpWidget(
        _uTemi(const LinkRow(label: 'Ocijenite aplikaciju', disabled: true)),
      );

      // `SPEC.md` §Interactions: „disabled = 45% opacity".
      final prozirnost = tester.widget<Opacity>(find.byType(Opacity));
      expect(prozirnost.opacity, 0.45);

      // Nema `InkWell`-a, pa nema ni šta da primi tap. Tap koji ne uradi ništa bi prošao
      // i kroz `onTap: () {}`, pa se mjeri odsustvo same dodirne mete.
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onemogućen red se čitaču ekrana javlja kao neaktivno dugme', (
      tester,
    ) async {
      final semantika = tester.ensureSemantics();
      await tester.pumpWidget(
        _uTemi(const LinkRow(label: 'Ocijenite aplikaciju', disabled: true)),
      );

      // Prozirnost ne govori ništa čitaču ekrana. Bez `enabled: false` bi red bio
      // objavljen kao dugme koje se može pritisnuti, a ne može.
      expect(
        tester.getSemantics(find.byType(LinkRow)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      semantika.dispose();
    });
  });

  group('LinkRowGroup', () {
    testWidgets(
      'razdjelnik ide između redova, ne iznad prvog ni ispod zadnjeg',
      (tester) async {
        await tester.pumpWidget(
          _uTemi(
            LinkRowGroup(
              rows: [
                LinkRow(label: 'Prvi', onTap: () {}),
                LinkRow(label: 'Drugi', onTap: () {}),
                LinkRow(label: 'Treći', onTap: () {}),
              ],
            ),
          ),
        );

        // Tri reda, dva razdjelnika. Obrub grupe već crta liniju na krajevima, pa bi
        // dodatni potez tamo bio deblji nego ostali.
        expect(find.byType(Divider), findsNWidgets(2));
      },
    );
  });
}
