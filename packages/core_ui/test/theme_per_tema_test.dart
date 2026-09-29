import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart'
    show barberPrimary, barberSecondary, beautyPrimary, beautySecondary;

/// Tema nosi pismo i uloge izbora (ADR-0025).
///
/// Dvije stvari koje se ovdje dokazuju ne vide se oku na jednom tenantu: da barber ostaje
/// **isti** (uloge izbora su tačno one koje su komponente crtale prije), i da algoritam iz
/// `prototype/beauty/README.md` drži prag za **svaku** boju salona, ne samo za demo ružu.
void main() {
  ThemeData barber() => buildAppTheme(
    primary: barberPrimary,
    secondary: barberSecondary,
    themeName: 'modern_barber',
  );
  ThemeData beauty() => buildAppTheme(
    primary: beautyPrimary,
    secondary: beautySecondary,
    themeName: 'elegant_beauty',
  );

  group('pismo po temi', () {
    test('barber ostaje na DM Serif Display + Archivo', () {
      final tekst = barber().textTheme;
      expect(tekst.displayLarge!.fontFamily, kSerifFamily);
      expect(tekst.bodyLarge!.fontFamily, kBodyFamily);
      expect(tekst.kicker().fontFamily, kBodyFamily);
    });

    test('beauty je Jost za sve, naslovi na 500', () {
      final tekst = beauty().textTheme;
      for (final stil in [
        tekst.displayLarge,
        tekst.headlineSmall,
        tekst.titleMedium,
        tekst.bodyLarge,
        tekst.labelLarge,
        tekst.labelSmall,
      ]) {
        expect(stil!.fontFamily, kJostFamily);
      }
      expect(tekst.displayLarge!.fontVariations, [
        const FontVariation('wght', 500),
      ]);
      expect(tekst.kicker().fontFamily, kJostFamily);
    });

    test('skala je ista u obje teme — mijenja se pismo, ne oblik', () {
      final b = barber().textTheme;
      final l = beauty().textTheme;
      for (final (x, y) in [
        (b.displayLarge, l.displayLarge),
        (b.displaySmall, l.displaySmall),
        (b.headlineSmall, l.headlineSmall),
        (b.titleMedium, l.titleMedium),
        (b.bodyLarge, l.bodyLarge),
        (b.labelLarge, l.labelLarge),
        (b.labelSmall, l.labelSmall),
      ]) {
        expect(y!.fontSize, x!.fontSize);
        expect(y.height, x.height);
      }
    });
  });

  group('uloge izbora', () {
    test('barber: izbor je invertovan u boji teksta, kao prije ADR-0025', () {
      final tema = barber();
      final izbor = tema.extension<AppSelectionColors>()!;
      final scheme = tema.colorScheme;
      expect(izbor.selected, scheme.onSurface);
      expect(izbor.onSelected, scheme.surface);
      expect(izbor.accentLine, scheme.onSurface);
      expect(izbor.accentInk, scheme.onSurface);
      expect(
        izbor.selectedContainer,
        Color.alphaBlend(
          scheme.onSurface.withValues(alpha: 0.10),
          scheme.surface,
        ),
      );
      // Barberovo dugme nosi tačnu brand boju iz `SPEC.md`, ne izvedenu.
      expect(scheme.primary, barberPrimary);
    });

    test('beauty: ruža daje vrijednosti iz handoffa', () {
      final tema = beauty();
      final izbor = tema.extension<AppSelectionColors>()!;
      // `prototype/beauty/README.md` §Brand uloge, kolona „Ruža".
      expect(tema.colorScheme.primary, _blizu(const Color(0xFFA7606B)));
      expect(tema.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(izbor.selected, tema.colorScheme.primary);
      expect(izbor.accentLine, _blizu(const Color(0xFFB76E79)));
      expect(izbor.selectedContainer, beautySecondary);
    });

    // Testni brandovi iz handoffa, plus dva koja salon realno može izabrati: žuta i
    // barberova tamna sekundarna prenesena na beauty temu.
    const brandovi = <String, (Color, Color)>{
      'ruža': (Color(0xFFB76E79), Color(0xFFFFF5F5)),
      'bordo': (Color(0xFF7A2E3B), Color(0xFFFFF0F1)),
      'pudrasta': (Color(0xFFD4A29B), Color(0xFFFDF2F0)),
      'zlatna': (Color(0xFFB08D57), Color(0xFFFBF3E8)),
      'šljiva': (Color(0xFF6E3B5C), Color(0xFFFDF0F8)),
      'žuta': (Color(0xFFFFEB3B), Color(0xFF212121)),
      'ruža sa tamnom sekundarnom': (Color(0xFFB76E79), Color(0xFF171717)),
    };

    for (final MapEntry(key: ime, value: (brand, secondary))
        in brandovi.entries) {
      test('beauty/$ime: svaki par drži svoj prag', () {
        final tema = buildAppTheme(
          primary: brand,
          secondary: secondary,
          themeName: 'elegant_beauty',
        );
        final izbor = tema.extension<AppSelectionColors>()!;
        final neutrals = AppTheme.elegantBeauty.neutrals;

        expect(
          contrastRatio(izbor.onSelected, izbor.selected),
          greaterThanOrEqualTo(kWcagAa),
          reason: 'tekst na izabranom slotu i dugmetu',
        );
        expect(
          contrastRatio(izbor.accentLine, neutrals.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'traka u tab baru je non-text, traži 3:1',
        );
        expect(
          contrastRatio(izbor.accentInk, neutrals.navSurface),
          greaterThanOrEqualTo(kWcagAa),
          reason: 'aktivna labela u tab baru',
        );
        expect(
          contrastRatio(neutrals.textPrimary, izbor.selectedContainer),
          greaterThanOrEqualTo(kWcagAa),
          reason: 'naziv usluge u izabranom redu',
        );
        final link = tema.extension<AppBrandColors>()!.primaryOnSurface;
        expect(
          contrastRatio(link, neutrals.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(link, neutrals.surfaceContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    testWidgets('tema bez extensiona (admin) pada na invertovan izbor', (
      tester,
    ) async {
      late AppSelectionColors izbor;
      final tema = ThemeData(colorScheme: const ColorScheme.light());
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: Builder(
            builder: (context) {
              izbor = context.selectionColors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(izbor.selected, tema.colorScheme.onSurface);
      expect(izbor.onSelected, tema.colorScheme.surface);
    });
  });

  group('OKLCH', () {
    test('boja preživi put tamo i nazad', () {
      for (final boja in const [
        Color(0xFFB76E79),
        Color(0xFF7A2E3B),
        Color(0xFFC6A667),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
      ]) {
        expect(Oklch.fromColor(boja).toColor(), _blizu(boja));
      }
    });

    test('darkenTo drži ton, mijenja samo svjetlinu', () {
      const ruza = Color(0xFFB76E79);
      final tamnija = darkenTo(ruza, const Color(0xFFFFFFFF), 4.6);
      final prije = Oklch.fromColor(ruza);
      final poslije = Oklch.fromColor(tamnija);
      expect(poslije.l, lessThan(prije.l));
      expect(poslije.h, closeTo(prije.h, 1.0));
      expect(poslije.c, closeTo(prije.c, 0.01));
    });
  });
}

/// Boja u granici od jedne 8-bitne vrijednosti po kanalu — OKLCH račun je u
/// pokretnom zarezu, handoff je zaokružio na heks.
Matcher _blizu(Color ocekivana) => predicate<Color>(
  (boja) =>
      (boja.r - ocekivana.r).abs() <= 1.5 / 255 &&
      (boja.g - ocekivana.g).abs() <= 1.5 / 255 &&
      (boja.b - ocekivana.b).abs() <= 1.5 / 255,
  'boja blizu ${ocekivana.toARGB32().toRadixString(16)}',
);
