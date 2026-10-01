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

    // ADR-0026: obje `health` teme, naslov u Newsreaderu na 400 sa `opsz` po veličini.
    for (final tema in [AppTheme.warmWellness, AppTheme.clinicalCalm]) {
      test('${tema.key} je Newsreader + Public Sans, opsz prati veličinu', () {
        final tekst = buildAppTheme(
          primary: _kadulja,
          secondary: _kaduljaSvijetla,
          themeName: tema.key,
        ).textTheme;
        for (final stil in [tekst.displayLarge, tekst.headlineSmall]) {
          expect(stil!.fontFamily, kNewsreaderFamily);
        }
        for (final stil in [
          tekst.titleMedium,
          tekst.bodyLarge,
          tekst.labelLarge,
          tekst.labelSmall,
        ]) {
          expect(stil!.fontFamily, kPublicSansFamily);
        }
        expect(tekst.displayLarge!.fontVariations, [
          const FontVariation('wght', 400),
          const FontVariation('opsz', 52),
        ]);
        expect(tekst.headlineSmall!.fontVariations, [
          const FontVariation('wght', 400),
          const FontVariation('opsz', 26),
        ]);
        expect(tekst.kicker().fontFamily, kPublicSansFamily);
      });
    }

    test('skala je ista u svim temama — mijenja se pismo, ne oblik', () {
      final b = barber().textTheme;
      for (final tema in AppTheme.values) {
        final l = buildAppTheme(
          primary: _kadulja,
          secondary: _kaduljaSvijetla,
          themeName: tema.key,
        ).textTheme;
        for (final (x, y) in [
          (b.displayLarge, l.displayLarge),
          (b.displaySmall, l.displaySmall),
          (b.headlineSmall, l.headlineSmall),
          (b.titleMedium, l.titleMedium),
          (b.bodyLarge, l.bodyLarge),
          (b.labelLarge, l.labelLarge),
          (b.labelSmall, l.labelSmall),
        ]) {
          expect(y!.fontSize, x!.fontSize, reason: tema.key);
          expect(y.height, x.height, reason: tema.key);
        }
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

    // Beauty brandovi na beautyju, plus demo boje `health` tenanata i iste beauty boje na
    // obje `health` teme — neutrale su druge, pa prag mora držati i tamo (ADR-0026).
    final parovi = <(AppTheme, String, Color, Color)>[
      for (final MapEntry(key: ime, value: (brand, secondary))
          in brandovi.entries) ...[
        (AppTheme.elegantBeauty, ime, brand, secondary),
        (AppTheme.warmWellness, ime, brand, secondary),
        (AppTheme.clinicalCalm, ime, brand, secondary),
      ],
      (AppTheme.warmWellness, 'kadulja', _kadulja, _kaduljaSvijetla),
      (AppTheme.clinicalCalm, 'petrolej', _petrolej, _petrolejSvijetla),
    ];

    for (final (appTheme, ime, brand, secondary) in parovi) {
      test('${appTheme.key}/$ime: svaki par drži svoj prag', () {
        final tema = buildAppTheme(
          primary: brand,
          secondary: secondary,
          themeName: appTheme.key,
        );
        final izbor = tema.extension<AppSelectionColors>()!;
        final neutrals = appTheme.neutrals;

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

    // Handoff je kaduljin i petrolejev fill već izabrao iznad AA, pa ih algoritam ne dira —
    // dugme nosi tačnu boju salona.
    for (final (ime, themeName, brand) in [
      ('kadulja', 'warm_wellness', _kadulja),
      ('petrolej', 'clinical_calm', _petrolej),
    ]) {
      test('$ime: primary je tačna boja iz handoffa', () {
        final scheme = buildAppTheme(
          primary: brand,
          secondary: const Color(0xFFFFFFFF),
          themeName: themeName,
        ).colorScheme;
        expect(scheme.primary, _blizu(brand));
        expect(scheme.onPrimary, const Color(0xFFFFFFFF));
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

/// Demo boje `health` tenanata: `primaryFill` iz `prototype/masaza/SPEC.md` i
/// `fizio/SPEC.md`, sa svijetlom sekundarnom kao podlogom izabranog reda.
const _kadulja = Color(0xFF56664F);
const _kaduljaSvijetla = Color(0xFFEEF0E9);
const _petrolej = Color(0xFF2F6F6D);
const _petrolejSvijetla = Color(0xFFE6F0EF);

/// Boja u granici od jedne 8-bitne vrijednosti po kanalu — OKLCH račun je u
/// pokretnom zarezu, handoff je zaokružio na heks.
Matcher _blizu(Color ocekivana) => predicate<Color>(
  (boja) =>
      (boja.r - ocekivana.r).abs() <= 1.5 / 255 &&
      (boja.g - ocekivana.g).abs() <= 1.5 / 255 &&
      (boja.b - ocekivana.b).abs() <= 1.5 / 255,
  'boja blizu ${ocekivana.toARGB32().toRadixString(16)}',
);
