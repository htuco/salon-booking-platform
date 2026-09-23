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

      await listaj(tester);
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

  group('FE-204 — Hero i geste', () {
    testWidgets('ćelija i stranica dijele Hero tag', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      final tag = GalleryLightbox.heroTag(0, dvanaestSlika.first);
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == tag),
        findsOneWidget,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      // Usred leta — `Hero` leti samo između `PageRoute`-ova; u dijalogu ovoga nema.
      await tester.pump();
      await tester.pump(GalleryLightbox.trajanjeLeta ~/ 2);
      expect(find.byType(GalleryLightbox), findsOneWidget);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(GalleryLightbox),
          matching: find.byWidgetPredicate((w) => w is Hero && w.tag == tag),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ista slika dvaput u nizu ne ruši Hero', (tester) async {
      // Sam URL kao tag bi ovdje bacio „multiple heroes that share the same tag".
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: const [
          'https://primjer.test/a.jpg',
          'https://primjer.test/a.jpg',
        ],
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Zatvori'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('brojač stoji u gornjem desnom uglu', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();

      final ekran = tester.getSize(find.byType(GalleryLightbox));
      final brojac = tester.getRect(find.text('1 / 12'));
      expect(brojac.center.dx, greaterThan(ekran.width / 2));
      expect(brojac.top, lessThan(ekran.height / 4));
    });

    testWidgets('pinch uveća sliku, a uvećana slika ne lista', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();

      final centar = tester.getCenter(find.byType(PageView));
      final a = await tester.startGesture(centar - const Offset(20, 0));
      final b = await tester.startGesture(centar + const Offset(20, 0));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-10, 0));
        await b.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Jedan prst po uvećanoj slici pomjera sliku, ne mijenja stranicu.
      await listaj(tester);
      await tester.pumpAndSettle();
      expect(find.text('1 / 12'), findsOneWidget);
    });

    testWidgets('swipe dolje zatvara', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryLightbox), findsNothing);
    });

    testWidgets('kratko povlačenje dolje vraća sliku na mjesto', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: dvanaestSlika,
      );

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();

      await tester.timedDrag(
        find.byType(PageView),
        const Offset(0, 40),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GalleryLightbox), findsOneWidget);
    });

    testWidgets('zatvaranje sa druge slike: mreža ispod pokazuje tu ćeliju', (
      tester,
    ) async {
      final trideset = [
        for (var i = 1; i <= 30; i++) 'https://primjer.test/$i.jpg',
      ];
      // Ušlo se sa prve, izašlo sa zadnje — ćelija 30 je daleko ispod prvog ekrana, pa bez
      // skrola ispod `Hero` ne bi imao gdje sletjeti.
      await pumpEkran(
        tester,
        ruta: ClientRoute.gallery.path,
        galerija: trideset,
      );
      // Harness je visok 3000 px i na njemu je cijela mreža uvijek vidljiva — test
      // bi prošao i bez skrola. Na telefonu (402×874) deset vrsta ne stane.
      tester.view.physicalSize = const Size(402, 874);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PhotoFrame).first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 29; i++) {
        await listaj(tester);
        await tester.pumpAndSettle();
      }
      expect(find.text('30 / 30'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Zatvori'));
      await tester.pumpAndSettle();

      final zadnja = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == GalleryLightbox.heroTag(29, trideset[29]),
      );
      final ekran = tester.getSize(find.byType(MaterialApp));
      final rect = tester.getRect(zadnja);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(ekran.height));
    });
  });
}

/// Jedan swipe na sljedeću sliku. Pomak je udio širine, ne fiksni broj piksela: površina
/// harnessa je široka, pa bi fiksnih 600 px ostalo ispod pola stranice i `PageView` bi se
/// ispravno vratio nazad.
Future<void> listaj(WidgetTester tester) async {
  final sirina = tester.getSize(find.byType(PageView)).width;
  await tester.drag(find.byType(PageView), Offset(-sirina * 0.8, 0));
}
