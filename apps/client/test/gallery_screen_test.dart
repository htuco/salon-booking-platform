import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/gallery/gallery_lightbox.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// `/gallery` i lightbox — `SPEC.md` 5l i 5q, `12-galerija.png`, `17-lightbox-galerije.png`.
///
/// Slike se u testu ne učitavaju (nema mreže), pa se mjeri **raspored i ponašanje**, ne
/// piksel. Ono što se ovdje može dokazati je tačno ono što je u tasku 22 promaklo: da red
/// sa URL-om i red bez njega nisu isti slučaj.
void main() {
  /// Dvanaest, koliko ih barber ima u seedu — mreža od tri kolone daje četiri pune vrste.
  final dvanaestSlika = [
    for (var i = 1; i <= 12; i++) 'https://primjer.test/$i.jpg',
  ];

  group('mreža', () {
    testWidgets('tri kolone, kvadrat, sve fotografije', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      // Cijela lista, ne izlog od šest — Početna je izlog, ovaj ekran je album.
      expect(find.byType(PhotoFrame), findsNWidgets(12));

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.childAspectRatio, 1);
      // `gap 8` iz DoD-a — `AppSpacing.sm`, ne gola osmica u ekranu.
      expect(delegate.crossAxisSpacing, AppSpacing.sm);
      expect(delegate.mainAxisSpacing, AppSpacing.sm);
    });

    testWidgets('podnaslov stoji iznad mreže', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      expect(find.text('Naši radovi iz zadnjih mjeseci.'), findsOneWidget);
    });

    testWidgets('pod-ekran: bez tab bara, sa zaglavljem', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      expect(find.byType(AppBottomNav), findsNothing);

      // Zaglavlje je **`BackHeader`, ne `AppBar`** — v. isti test na drugom ekranu.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackHeader), findsOneWidget);
      expect(find.text('Početna'), findsOneWidget);
    });
  });

  group('prazno stanje', () {
    testWidgets('salon bez slika dobije poruku, ne praznu mrežu', (
      tester,
    ) async {
      // Sekcija na Početnoj se sakriva, ali `/gallery` je deep link i mora izdržati
      // direktan dolazak. Beauty salon u seedu je tačno taj slučaj.
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: const [],
      );

      expect(find.text('Salon još nije dodao fotografije.'), findsOneWidget);
      expect(find.byType(PhotoFrame), findsNothing);
    });
  });

  group('lightbox', () {
    testWidgets('tap na ćeliju otvara lightbox na toj slici', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      // Četvrta ćelija — isti slučaj koji handoff crta kao „4 / 18".
      await tester.tap(find.byType(PhotoFrame).at(3));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryLightbox), findsOneWidget);
      expect(find.text('4 / 12'), findsOneWidget);
    });

    testWidgets('brojač prati listanje', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 12'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 12'), findsOneWidget);
      expect(find.text('1 / 12'), findsNothing);
    });

    testWidgets('✕ zatvara i vraća na mrežu', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();
      expect(find.byType(GalleryLightbox), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Zatvori'));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryLightbox), findsNothing);
      expect(find.byType(SliverGrid), findsOneWidget);
    });

    testWidgets('jedna fotografija ne dobija traku sličica', (tester) async {
      // Traka od jedne sličice ne nudi nijedan izbor, a jede visinu ispod slike.
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: const ['https://primjer.test/jedina.jpg'],
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
