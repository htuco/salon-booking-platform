/// Kontrast admin palete po WCAG 2.1 AA.
///
/// `core_ui` isti odnos računa **u runtime-u**, jer tamo brand boju bira vlasnik salona i
/// niko je ne vidi prije builda. Ovdje su boje konstante, pa se mjeri jednom — u testu.
/// Zato admin nema svoj `contrast.dart` u `lib/`: funkcija koja se poziva samo iz testa
/// ne pripada produkcijskom kodu.
library;

import 'dart:math' as math;

import 'package:admin/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prag za normalan tekst.
const double kAa = 4.5;

double odnos(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final tema = buildAdminTheme();
  final scheme = tema.colorScheme;

  group('ColorScheme parovi', () {
    final parovi = <String, (Color, Color)>{
      'onPrimary/primary': (scheme.onPrimary, scheme.primary),
      'onPrimaryContainer/primaryContainer': (
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
      'onSecondaryContainer/secondaryContainer': (
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
      'onTertiaryContainer/tertiaryContainer': (
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      'onError/error': (scheme.onError, scheme.error),
      'onErrorContainer/errorContainer': (
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      'onSurface/surface': (scheme.onSurface, scheme.surface),
      'onSurface/surfaceContainer': (
        scheme.onSurface,
        scheme.surfaceContainer,
      ),
      'onSurface/surfaceContainerHighest': (
        scheme.onSurface,
        scheme.surfaceContainerHighest,
      ),
      'onInverseSurface/inverseSurface': (
        scheme.onInverseSurface,
        scheme.inverseSurface,
      ),
    };

    for (final unos in parovi.entries) {
      test('${unos.key} prolazi AA', () {
        final (fg, bg) = unos.value;
        expect(
          odnos(fg, bg),
          greaterThanOrEqualTo(kAa),
          reason: '${unos.key}: ${odnos(fg, bg).toStringAsFixed(2)}:1',
        );
      });
    }

    test('onSurfaceVariant je čitljiv i na podlozi i na kartici', () {
      // Ovo je razlog zašto `onSurfaceVariant` nosi `textSecondary`, a ne `textMuted`:
      // sekundarni tekst stoji i na radnoj pozadini i unutar bijele kartice, a `#6B757B`
      // na pozadini mjeri 4,35:1. SPEC tabela daje obje vrijednosti i ne kaže koja je koja.
      expect(
        odnos(scheme.onSurfaceVariant, AdminColors.ground),
        greaterThanOrEqualTo(kAa),
      );
      expect(
        odnos(scheme.onSurfaceVariant, AdminColors.surface),
        greaterThanOrEqualTo(kAa),
      );
    });
  });

  group('boje van šeme', () {
    test('textMuted prolazi na kartici, ali ne i na radnoj pozadini', () {
      // Test namjerno tvrdi i **pad**: da je ovo samo komentar, prva sljedeća izmjena bi
      // `textMuted` stavila na pozadinu i ništa je ne bi zaustavilo.
      expect(
        odnos(AdminColors.textMuted, AdminColors.surface),
        greaterThanOrEqualTo(kAa),
      );
      expect(
        odnos(AdminColors.textMuted, AdminColors.ground),
        lessThan(kAa),
        reason:
            'ako ovo prođe, boja je promijenjena i doc komentar uz nju više ne važi',
      );
    });

    test('sidebar tekst je čitljiv na tamnoj plohi', () {
      expect(
        odnos(AdminColors.sidebarText, AdminColors.ink),
        greaterThanOrEqualTo(kAa),
      );
      expect(
        odnos(AdminColors.sidebarMuted, AdminColors.ink),
        greaterThanOrEqualTo(kAa),
      );
    });

    test('accentSoft nije podloga za tekst i nije ušao u šemu', () {
      // Sekundarni akcent iz SPEC tabele: finalni canvas ga ne crta nijednom, a nijedan
      // tekst na njemu ne prolazi AA. Ovaj test pada ako ga neko ubaci u `ColorScheme`.
      expect(odnos(AdminColors.onAccent, AdminColors.accentSoft), lessThan(kAa));
      expect(odnos(AdminColors.ink, AdminColors.accentSoft), lessThan(kAa));

      final uSemi = <Color>[
        scheme.primary,
        scheme.onPrimary,
        scheme.secondary,
        scheme.onSecondary,
        scheme.tertiary,
        scheme.onTertiary,
        scheme.primaryContainer,
        scheme.secondaryContainer,
        scheme.tertiaryContainer,
        scheme.surface,
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.outline,
        scheme.outlineVariant,
      ];
      expect(uSemi, isNot(contains(AdminColors.accentSoft)));
    });
  });

  group('statusne oznake', () {
    final tonovi = AdminStatusColors.standard();
    final imenovani = <String, AdminStatusTone>{
      'positive': tonovi.positive,
      'waiting': tonovi.waiting,
      'neutral': tonovi.neutral,
      'negative': tonovi.negative,
      'negativeQuiet': tonovi.negativeQuiet,
    };

    for (final unos in imenovani.entries) {
      test('${unos.key} prolazi AA', () {
        final ton = unos.value;
        final r = odnos(ton.foreground, ton.background);
        expect(
          r,
          greaterThanOrEqualTo(kAa),
          reason: '${unos.key}: ${r.toStringAsFixed(2)}:1',
        );
      });
    }

    test('canvas par za „Završeno" bi pao — zato je tekst spušten', () {
      // `background:#eef1f3;color:#6b757b` iz handoffa mjeri 4,15:1. Ovo stoji kao test,
      // a ne kao komentar, da se vrijednost ne vrati „nazad na handoff" bez razloga.
      expect(
        odnos(AdminColors.textMuted, AdminColors.neutralTint),
        lessThan(kAa),
      );
      expect(
        odnos(tonovi.neutral.foreground, tonovi.neutral.background),
        greaterThanOrEqualTo(kAa),
      );
    });
  });
}
