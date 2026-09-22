/// Tokeni, pisma i oblik teme — ono što se može provjeriti bez iscrtavanja ekrana.
///
/// Kontrast mjeri `theme_contrast_test.dart`; curenje heksa u ekran hvata
/// `no_hardcoded_colors_test.dart`.
library;

import 'dart:io';

import 'package:admin/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tokeni', () {
    test('osnovni radius je 6, ne 0', () {
      // Klijentska app ima radius 0 iz `prototype/ui/`. Ovo je drugi proizvod i drugi
      // handoff; prepisivanje navike iz `core_ui` je najlakša greška u ovom fajlu.
      expect(AdminRadius.base, 6);
      expect(AdminRadius.pill, 20);
    });

    test('mjere ljuske su one iz SPEC-a i canvasa', () {
      expect(AdminSize.sidebarWidth, 236);
      expect(AdminSize.topBarHeight, 66);
      expect(AdminSpacing.gutterMobile, 20);
      // 28, ne 24: `padding:28px` je u svih sedam desktop prikaza u opsegu, a
      // `padding:24px` se u canvasu ne javlja nijednom.
      expect(AdminSpacing.gutterDesktop, 28);
    });

    test('tema koristi osnovni radius na kartici', () {
      final tema = buildAdminTheme();
      final oblik = tema.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        oblik.borderRadius,
        BorderRadius.circular(AdminRadius.base),
        reason: 'kartica mora nositi radius iz tokena, ne Material default',
      );
    });

    test('tema ne nosi nijednu sjenku — dubina je hairline obrub', () {
      final tema = buildAdminTheme();
      expect(tema.cardTheme.elevation, 0);
      expect(tema.appBarTheme.elevation, 0);
      expect(tema.appBarTheme.scrolledUnderElevation, 0);
    });
  });

  group('pisma', () {
    test('četiri reza Barlowa stoje u repou, uz OFL licencu', () {
      // Fajl koji nedostaje ne obara build — Flutter tiho padne na fallback pismo, i to
      // se vidi tek na ekranu. Ovaj test je jedino mjesto gdje se to primijeti odmah.
      for (final ime in const [
        'assets/fonts/Barlow-Regular.ttf',
        'assets/fonts/Barlow-Medium.ttf',
        'assets/fonts/Barlow-SemiBold.ttf',
        'assets/fonts/Barlow-Bold.ttf',
        'assets/fonts/OFL-Barlow.txt',
      ]) {
        expect(File(ime).existsSync(), isTrue, reason: 'nedostaje $ime');
      }
    });

    test('pubspec pakuje Barlow po težini — nema Google Fonts zavisnosti', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $kAdminSansFamily'));
      // Statični rezovi: bez `weight:` bi Flutter svaki fajl čitao kao 400 i `w600`
      // bi sintetički podebljao Regular.
      for (final tezina in const [400, 500, 600, 700]) {
        expect(pubspec, contains('weight: $tezina'));
      }
      expect(
        pubspec,
        isNot(contains('google_fonts')),
        reason: 'izgled admina ne smije zavisiti od mreže',
      );
    });

    test('tema postavlja Barlow kao podrazumijevanu porodicu', () {
      final tema = buildAdminTheme();
      expect(tema.textTheme.bodyMedium?.fontFamily, kAdminSansFamily);
      expect(tema.textTheme.titleLarge?.fontFamily, kAdminSansFamily);
      expect(tema.textTheme.displayLarge?.fontFamily, kAdminSansFamily);
    });

    test('svaki imenovani stil je Barlow — nema drugog pisma (ADR-0020)', () {
      // `3b` je od naslova do vremena u tabeli jedna porodica. Stil koji tiho ostane na
      // starom mono pismu se na ekranu vidi kao jedna kolona u drugom fontu.
      for (final stil in [
        AdminText.time,
        AdminText.timeLarge,
        AdminText.eyebrow,
        AdminText.dataInline,
        AdminText.display,
        AdminText.metricNumber,
        AdminText.statusLabel,
        AdminText.navigation,
        AdminText.actionLabel,
      ]) {
        expect(stil.fontFamily, kAdminSansFamily);
      }
    });

    test('podatak ima tabularne cifre, tekst ih nema', () {
      // Mono je do ADR-0020 držao cifre u koloni; sada to radi `tnum` nad Barlowom.
      for (final stil in [
        AdminText.time,
        AdminText.timeLarge,
        AdminText.dataInline,
        AdminText.metricNumber,
      ]) {
        expect(stil.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
      expect(AdminText.display.fontFeatures, isNull);
    });

    test('tracking je u em, pa raste sa veličinom', () {
      // Handoff piše `letter-spacing:.08em`. Prepisan u logičke piksele, isti razmak bi
      // na 12 i na 34 px izgledao drugačije.
      final mali = barlow(size: 10, tracking: 0.1);
      final veliki = barlow(size: 30, tracking: 0.1);
      expect(mali.letterSpacing, closeTo(1, 0.0001));
      expect(veliki.letterSpacing, closeTo(3, 0.0001));
      expect(barlow(size: 14).letterSpacing, isNull);
    });
  });

  group('statusni tonovi', () {
    test('svaki status ima svoj par, a otkazan i no-show se razlikuju', () {
      final tonovi = AdminStatusColors.standard();
      expect(tonovi.positive.background, AdminColors.positiveTint);
      expect(tonovi.waiting.background, AdminColors.waitingTint);
      // Otkazao je neko; „nije se pojavio" se prosto desilo. Ista pilula za oboje briše
      // razliku koju vlasnik koristi kad gleda ko mu ne dolazi.
      expect(
        tonovi.negative.background,
        isNot(tonovi.negativeQuiet.background),
      );
    });

    test('lerp ne puca i vraća krajeve', () {
      final a = AdminStatusColors.standard();
      expect(a.lerp(a, 0.5), isA<AdminStatusColors>());
      expect(a.lerp(null, 0.5).positive.background, a.positive.background);
    });

    test('tema nosi ekstenziju, pa je ekran dobija bez fallbacka', () {
      final tema = buildAdminTheme();
      expect(tema.extension<AdminStatusColors>(), isNotNull);
    });
  });
}
