/// WCAG 2.1 AA provjera obje admin palete.
library;

import 'dart:math' as math;

import 'package:admin/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double kAa = 4.5;

double odnos(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final naziv = brightness == Brightness.light ? 'light' : 'dark';
    final tema = buildAdminTheme(brightness);
    final scheme = tema.colorScheme;
    final palette = tema.extension<AdminPalette>()!;
    final statusi = tema.extension<AdminStatusColors>()!;

    group('$naziv ColorScheme', () {
      final parovi = <String, (Color, Color)>{
        'onPrimary/primary': (scheme.onPrimary, scheme.primary),
        'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
        'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
        'onError/error': (scheme.onError, scheme.error),
        'onSurface/surface': (scheme.onSurface, scheme.surface),
        'onSurface/surfaceContainer': (
          scheme.onSurface,
          scheme.surfaceContainer,
        ),
        'onSurfaceVariant/surface': (scheme.onSurfaceVariant, scheme.surface),
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
    });

    group('$naziv prilagodjeni tokeni', () {
      // Coral je najtjesnji par u paleti: bijeli tekst na njemu mjeri 3,05:1 i pada AA,
      // pa `onAction` nosi `--foreground`. Mjeri se ono sto se stvarno iscrtava —
      // `filledButtonTheme`, ne samo tokeni — jer se boja dugmeta odlucuje tamo.
      test('glavno dugme (coral) prolazi AA', () {
        final stil = tema.filledButtonTheme.style!;
        final pozadina = stil.backgroundColor!.resolve(<WidgetState>{})!;
        final tekst = stil.foregroundColor!.resolve(<WidgetState>{})!;
        expect(pozadina, palette.action);
        expect(
          odnos(tekst, pozadina),
          greaterThanOrEqualTo(kAa),
          reason: 'coral dugme: ${odnos(tekst, pozadina).toStringAsFixed(2)}:1',
        );
      });

      // FAB je isti CTA kao dugme u top baru; dok je padao na M3 default bio je siv na
      // telefonu i coral na desktopu, a to se u testu tokena ne vidi.
      test('FAB nosi istu boju kao glavno dugme', () {
        final fab = tema.floatingActionButtonTheme;
        expect(fab.backgroundColor, palette.action);
        expect(
          odnos(fab.foregroundColor!, fab.backgroundColor!),
          greaterThanOrEqualTo(kAa),
        );
      });

      test('sidebar tekst i aktivna stavka prolaze AA', () {
        expect(
          odnos(palette.sidebarText, palette.sidebarBackground),
          greaterThanOrEqualTo(kAa),
        );
        expect(
          odnos(palette.sidebarMuted, palette.sidebarBackground),
          greaterThanOrEqualTo(kAa),
        );
        expect(
          odnos(palette.sidebarAccentForeground, palette.sidebarSelected),
          greaterThanOrEqualTo(kAa),
        );
      });

      final tonovi = <String, AdminStatusTone>{
        'positive': statusi.positive,
        'waiting': statusi.waiting,
        'neutral': statusi.neutral,
        'negative': statusi.negative,
        'negativeQuiet': statusi.negativeQuiet,
      };
      for (final unos in tonovi.entries) {
        test('status ${unos.key} prolazi AA', () {
          final ton = unos.value;
          expect(
            odnos(ton.foreground, ton.background),
            greaterThanOrEqualTo(kAa),
            reason:
                '${unos.key}: ${odnos(ton.foreground, ton.background).toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }
}
