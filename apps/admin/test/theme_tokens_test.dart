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
    test('oba fajla stoje u repou, uz svoju OFL licencu', () {
      // Fajl koji nedostaje ne obara build — Flutter tiho padne na fallback pismo, i to
      // se vidi tek na ekranu. Ovaj test je jedino mjesto gdje se to primijeti odmah.
      for (final ime in const [
        'assets/fonts/SpaceGrotesk[wght].ttf',
        'assets/fonts/JetBrainsMono[wght].ttf',
        'assets/fonts/OFL-SpaceGrotesk.txt',
        'assets/fonts/OFL-JetBrainsMono.txt',
      ]) {
        expect(File(ime).existsSync(), isTrue, reason: 'nedostaje $ime');
      }
    });

    test('pubspec pakuje obje porodice — nema Google Fonts zavisnosti', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: $kAdminSansFamily'));
      expect(pubspec, contains('family: $kAdminMonoFamily'));
      expect(
        pubspec,
        isNot(contains('google_fonts')),
        reason: 'izgled admina ne smije zavisiti od mreže',
      );
    });

    test('tema postavlja Space Grotesk kao podrazumijevanu porodicu', () {
      final tema = buildAdminTheme();
      expect(tema.textTheme.bodyMedium?.fontFamily, kAdminSansFamily);
      expect(tema.textTheme.titleLarge?.fontFamily, kAdminSansFamily);
      // `fontFamily` na `ThemeData` hvata widget koji ne gleda `textTheme`.
      expect(tema.textTheme.displayLarge?.fontFamily, kAdminSansFamily);
    });

    test('svaki stil iz TextTheme-a nosi FontVariation za svoju težinu', () {
      // Space Grotesk je varijabilan sa **defaultom na 300**. Bez `FontVariation` cijeli
      // admin bi bio tanji od handoffa — ujednačeno, pa izgleda kao izbor, ne kao greška.
      final tema = buildAdminTheme();
      final stilovi = <String, TextStyle?>{
        'displayLarge': tema.textTheme.displayLarge,
        'titleMedium': tema.textTheme.titleMedium,
        'bodyMedium': tema.textTheme.bodyMedium,
        'labelLarge': tema.textTheme.labelLarge,
      };

      for (final unos in stilovi.entries) {
        final stil = unos.value!;
        final osa = stil.fontVariations?.singleWhere((v) => v.axis == 'wght');
        expect(osa, isNotNull, reason: '${unos.key} nema wght osu');
        expect(
          osa!.value,
          stil.fontWeight!.value.toDouble(),
          reason: '${unos.key}: osa i fontWeight se ne slažu',
        );
      }
    });

    test('wght vrijednosti ostaju unutar ose oba pisma', () {
      // Space Grotesk: 300–700. JetBrains Mono: 100–800. Vrijednost izvan raspona font
      // tiho odsiječe na granicu.
      for (final stil in [
        AdminText.display,
        AdminText.metricNumber,
        buildAdminTheme().textTheme.labelLarge!,
      ]) {
        final w = stil.fontVariations!.single.value;
        expect(w, inInclusiveRange(300, 700), reason: 'Space Grotesk osa');
      }
      for (final stil in [
        AdminText.time,
        AdminText.timeLarge,
        AdminText.eyebrow,
        AdminText.dataInline,
      ]) {
        final w = stil.fontVariations!.single.value;
        expect(w, inInclusiveRange(100, 800), reason: 'JetBrains Mono osa');
      }
    });

    test('mono nosi vrijeme i podatak, Space Grotesk naslov i status', () {
      // Podjela iz `SPEC.md`, uz dvije ispravke izmjerene iz finalnog canvasa: velika
      // brojka i statusna oznaka **nisu** mono.
      expect(AdminText.time.fontFamily, kAdminMonoFamily);
      expect(AdminText.timeLarge.fontFamily, kAdminMonoFamily);
      expect(AdminText.eyebrow.fontFamily, kAdminMonoFamily);
      expect(AdminText.dataInline.fontFamily, kAdminMonoFamily);

      expect(AdminText.display.fontFamily, kAdminSansFamily);
      expect(AdminText.metricNumber.fontFamily, kAdminSansFamily);
      expect(AdminText.statusLabel.fontFamily, kAdminSansFamily);
    });

    test('mono uvijek ima tabularne cifre', () {
      // Lista termina se čita kao kolona; cifre moraju stajati jedna ispod druge i kad se
      // promijeni tekstualna skala uređaja.
      expect(
        AdminText.time.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('tracking je u em, pa raste sa veličinom', () {
      // Handoff piše `letter-spacing:-.02em`. Prepisan u logičke piksele, isti potez bi
      // na 13 i na 34 px izgledao drugačije.
      final mali = grotesk(size: 10, tracking: -0.02);
      final veliki = grotesk(size: 30, tracking: -0.02);
      expect(mali.letterSpacing, closeTo(-0.2, 0.0001));
      expect(veliki.letterSpacing, closeTo(-0.6, 0.0001));
      expect(grotesk(size: 14).letterSpacing, isNull);
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
