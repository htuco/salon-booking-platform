import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sa ekrana potvrde (2026-10-14): „Fade · 20 KM" je počinjalo na sredini kartice, a
  // badge „Na čekanju" ispod njega stajao uz desni rub. Vrijednost i badge moraju
  // završavati na istoj vertikali, bez obzira na dužinu teksta.
  testWidgets('tekstualna vrijednost i badge završavaju na istom desnom rubu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          primary: const Color(0xFFC6A667),
          secondary: const Color(0xFF171717),
          themeName: 'modern_barber',
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 358,
            child: SpecCard(
              rows: [
                SpecRow(label: 'Usluga', value: 'Fade'),
                SpecRow(
                  label: 'Status',
                  trailing: StatusBadge(
                    label: 'Na čekanju',
                    tone: StatusTone.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final vrijednost = tester.getRect(find.text('Fade'));
    final badge = tester.getRect(find.byType(StatusBadge));
    final labela = tester.getRect(find.text('Usluga'));

    // Ne mjeri se kutija `Text`-a nego stvarni kraj teksta: `Expanded` daje kutiju do
    // ruba i kad tekst u njoj stoji lijevo. Vrijednost je kratka namjerno — testni font
    // je širok, i duži tekst bi popunio pola reda pa slučajno završio uz rub.
    final paragraf = tester.renderObject<RenderParagraph>(find.text('Fade'));
    final krajTeksta =
        vrijednost.left +
        paragraf
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: 'Fade'.length),
            )
            .last
            .right;

    expect(krajTeksta, moreOrLessEquals(badge.right, epsilon: 1));
    expect(labela.left, lessThan(vrijednost.left));
  });
}
