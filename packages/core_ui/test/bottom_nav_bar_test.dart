import 'package:core_ui/core_ui.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart'
    show barberPrimary, barberSecondary, beautyPrimary, beautySecondary;

const _celije = [
  AppBottomNavItem(icon: Icons.content_cut, label: 'Usluge'),
  AppBottomNavItem(icon: Icons.calendar_today, label: 'Termini'),
  AppBottomNavItem(icon: Icons.home_outlined, label: 'Pocetna'),
  AppBottomNavItem(icon: Icons.notifications_none, label: 'Obavijesti'),
  AppBottomNavItem(icon: Icons.tune, label: 'Postavke'),
];

Widget _traka({
  required ThemeData tema,
  int aktivna = 2,
  ValueChanged<int>? onSelect,
}) => MaterialApp(
  theme: tema,
  home: Scaffold(
    bottomNavigationBar: AppBottomNav(
      items: _celije,
      currentIndex: aktivna,
      onSelect: onSelect ?? (_) {},
    ),
  ),
);

ThemeData _barber() => buildAppTheme(
  primary: barberPrimary,
  secondary: barberSecondary,
  themeName: AppTheme.modernBarber.key,
);

ThemeData _beauty() => buildAppTheme(
  primary: beautyPrimary,
  secondary: beautySecondary,
  themeName: AppTheme.elegantBeauty.key,
);

void main() {
  group('raspored iz handoffa', () {
    testWidgets('pet celija, Pocetna u sredini', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber()));

      // Redoslijed iz `SPEC.md`, citан sa ekrana a ne iz ulazne liste: da komponenta
      // negdje obrne ili sortira celije, ovo bi palo.
      final labele = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AppBottomNav),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();

      expect(labele, [
        'Usluge',
        'Termini',
        'Pocetna',
        'Obavijesti',
        'Postavke',
      ]);
      expect(
        labele[2],
        'Pocetna',
        reason: 'Pocetna je treca od pet — u sredini',
      );
    });

    testWidgets('celije dijele sirinu na jednake dijelove', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber()));

      final sirine = <double>[];
      for (final celija in _celije) {
        sirine.add(tester.getSize(find.text(celija.label)).width);
      }
      // Labele nisu jednake, ali njihove celije jesu — mjeri se roditelj.
      final ivice = _celije
          .map(
            (c) => tester.getRect(
              find.ancestor(
                of: find.text(c.label),
                matching: find.byType(InkWell),
              ),
            ),
          )
          .toList();
      for (final ivica in ivice) {
        expect(ivica.width, closeTo(ivice.first.width, 0.5));
      }
      expect(sirine.length, 5);
    });

    testWidgets('svaka celija je preko minimalne dodirne mete', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber()));

      for (final celija in _celije) {
        final visina = tester
            .getSize(
              find.ancestor(
                of: find.text(celija.label),
                matching: find.byType(InkWell),
              ),
            )
            .height;
        expect(
          visina,
          greaterThanOrEqualTo(AppSize.touchTarget),
          reason: '${celija.label}: docs/02 §14 trazi 44 dp',
        );
      }
    });
  });

  group('aktivno stanje', () {
    testWidgets('traka iznad aktivne celije postoji, i samo jedna', (
      tester,
    ) async {
      await tester.pumpWidget(_traka(tema: _barber(), aktivna: 2));

      final trake = find.byWidgetPredicate(
        (w) => w is Container && _visinaOf(w) == AppSize.navIndicator,
      );
      expect(
        trake,
        findsOneWidget,
        reason: 'jedna aktivna celija, jedna traka',
      );
    });

    testWidgets('traka je uvucena 16% s obje strane celije', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber(), aktivna: 0));

      final celija = tester.getRect(
        find.ancestor(of: find.text('Usluge'), matching: find.byType(InkWell)),
      );
      final traka = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is Container && _visinaOf(w) == AppSize.navIndicator,
        ),
      );

      expect(
        traka.left - celija.left,
        closeTo(celija.width * AppSize.navIndicatorInset, 0.5),
      );
      expect(
        celija.right - traka.right,
        closeTo(celija.width * AppSize.navIndicatorInset, 0.5),
      );
    });

    testWidgets('aktivna labela je 600, neaktivna 400', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber(), aktivna: 2));

      final aktivna = tester.widget<Text>(find.text('Pocetna'));
      final neaktivna = tester.widget<Text>(find.text('Usluge'));

      expect(aktivna.style?.fontWeight, FontWeight.w600);
      expect(neaktivna.style?.fontWeight, FontWeight.w400);
      // Archivo je varijabilan font — bez pomjerene ose `fontWeight` sam zna ostati
      // bez efekta, pa se testira i osa (v. `typography.dart`).
      expect(
        aktivna.style?.fontVariations,
        contains(const FontVariation('wght', 600)),
      );
    });

    testWidgets('aktivna celija je jedina oznacena kao selected za citac', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_traka(tema: _barber(), aktivna: 3));

      expect(find.bySemanticsLabel('Obavijesti'), findsOneWidget);
      final semantika = tester.getSemantics(
        find.bySemanticsLabel('Obavijesti'),
      );
      expect(semantika.flagsCollection.isSelected, Tristate.isTrue);

      final druga = tester.getSemantics(find.bySemanticsLabel('Postavke'));
      expect(druga.flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
    });
  });

  group('izbor', () {
    testWidgets('tap na drugu celiju javlja njen indeks', (tester) async {
      final tapnuti = <int>[];
      await tester.pumpWidget(
        _traka(tema: _barber(), aktivna: 2, onSelect: tapnuti.add),
      );

      await tester.tap(find.text('Termini'));
      await tester.pump();

      expect(tapnuti, [1]);
    });

    testWidgets('tap na vec aktivnu celiju se takodje javlja', (tester) async {
      // Ovo nosi "ponovni tap vraca tab na korijen" iz `SPEC.md`. Komponenta koja
      // preskoci poziv kad je indeks isti bi tu funkciju tiho ubila.
      final tapnuti = <int>[];
      await tester.pumpWidget(
        _traka(tema: _barber(), aktivna: 2, onSelect: tapnuti.add),
      );

      await tester.tap(find.text('Pocetna'));
      await tester.pump();

      expect(tapnuti, [2]);
    });

    testWidgets('indeks van raspona ne obara traku', (tester) async {
      await tester.pumpWidget(_traka(tema: _barber(), aktivna: 9));
      expect(tester.takeException(), isNull);
      expect(find.text('Postavke'), findsOneWidget);
    });
  });

  group('boja dolazi iz teme, ne iz handoffa', () {
    testWidgets('svijetla tema ne crta bijeli tekst na svijetloj traci', (
      tester,
    ) async {
      // Ovo je greska koju prepisan heks iz `SPEC.md` napravi: `#FFFFFF` za aktivnu
      // celiju je tacno za barber, a nevidljivo na beauty paleti.
      await tester.pumpWidget(_traka(tema: _beauty(), aktivna: 2));

      final tema = _beauty();
      final aktivna = tester.widget<Text>(find.text('Pocetna'));
      expect(aktivna.style?.color, tema.colorScheme.onSurface);
      expect(
        contrastRatio(aktivna.style!.color!, tema.colorScheme.surfaceDim),
        greaterThanOrEqualTo(4.5),
      );
    });

    // Svaka paleta ima **svoj** test, a ne jednu petlju sa dva `pumpWidget`-a:
    // `MaterialApp` interpolira `ThemeData` izmedju dvije teme, pa drugi pumpWidget
    // vrati boju na pola prelaza. Petlja je ovdje prvo bila napisana i pala je sa
    // odnosom 1.50 — barberov svijetli tekst mjeren na beauty pozadini.
    for (final (ime, tema) in [('barber', _barber), ('beauty', _beauty)]) {
      testWidgets('$ime: neaktivna labela prolazi AA', (tester) async {
        final t = tema();
        await tester.pumpWidget(_traka(tema: t, aktivna: 2));
        final neaktivna = tester.widget<Text>(find.text('Usluge'));
        expect(
          contrastRatio(neaktivna.style!.color!, t.colorScheme.surfaceDim),
          greaterThanOrEqualTo(4.5),
          reason: 'prigusen tekst nije izuzet od AA (docs/02 §14)',
        );
      });
    }

    testWidgets('traka je odvojena od pozadine ekrana', (tester) async {
      for (final tema in [_barber(), _beauty()]) {
        expect(
          tema.colorScheme.surfaceDim,
          isNot(tema.colorScheme.surface),
          reason: 'bez razlike tona traka se stapa sa ekranom iznad nje',
        );
      }
    });
  });
}

double? _visinaOf(Container container) {
  final constraints = container.constraints;
  if (constraints != null) return constraints.maxHeight;
  return null;
}
