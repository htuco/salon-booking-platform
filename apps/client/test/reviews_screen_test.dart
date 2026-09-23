import 'package:client/src/core/router/app_router.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// `/reviews` — `SPEC.md` 5m, `13-recenzije.png`.
void main() {
  /// Raspodjela iz seeda: 21×5 + 3×4 + 1×3 = 120 / 25 = 4,8 — broj sa handoffa.
  const ocjena = SalonRatingSummary(
    salonId: salonId,
    average: 4.8,
    total: 25,
    count5: 21,
    count4: 3,
    count3: 1,
  );

  Review recenzija({
    required String id,
    required String autor,
    int rating = 5,
    String? tekst = 'Fade je uvijek isti, tačno kako tražim.',
    Duration starost = const Duration(days: 3),
  }) => Review(
    id: id,
    salonId: salonId,
    authorName: autor,
    rating: rating,
    comment: tekst,
    createdAt: DateTime.now().subtract(starost),
  );

  group('sažetak', () {
    testWidgets('prosjek, histogram i broj ocjena dolaze iz agregata', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: [recenzija(id: 'r1', autor: 'Nedim H.')],
      );

      expect(find.text('4,8'), findsOneWidget);
      expect(find.text('od 5'), findsOneWidget);
      // 25 ocjena, a ne 1 — broj iznad histograma broji **sve** ocjene, ne kartice.
      expect(find.text('25 ocjena'), findsOneWidget);
      // Pet redova histograma, uvijek, i kad su neki nula.
      for (final zvjezdica in [5, 4, 3, 2, 1]) {
        expect(find.text('$zvjezdica'), findsOneWidget);
      }
    });

    testWidgets('histogram nosi semantičku labelu sa brojem', (tester) async {
      // Trake su obojene pravougaonike — čitač ekrana bez labele ne pročita ništa.
      // Semantičko stablo se u testu ne gradi samo od sebe; bez `ensureSemantics` bi
      // ovaj test prolazio i nad ekranom bez ijedne labele.
      final handle = tester.ensureSemantics();

      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: const [],
      );

      expect(find.bySemanticsLabel('5 zvjezdica: 21'), findsOneWidget);
      expect(find.bySemanticsLabel('2 zvjezdica: 0'), findsOneWidget);

      // Rucno, ne kroz `addTearDown`: provjera da su svi handle-ovi otpusteni ide
      // **prije** tearDown-a, pa bi test pao i sa prolaznim asercijama.
      handle.dispose();
    });
  });

  group('lista', () {
    testWidgets('kartica nosi ime, relativan datum, zvjezdice i tekst', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: [
          recenzija(id: 'r1', autor: 'Nedim H.'),
          recenzija(
            id: 'r2',
            autor: 'Haris M.',
            rating: 4,
            tekst: 'Sve super, jedino subotom zna biti gužva.',
            starost: const Duration(days: 31),
          ),
        ],
      );

      expect(find.text('Nedim H.'), findsOneWidget);
      expect(find.text('prije 3 dana'), findsOneWidget);
      expect(find.text('Haris M.'), findsOneWidget);
      expect(find.text('prije mjesec'), findsOneWidget);
      expect(find.byType(StarRating), findsNWidgets(2));
      expect(find.bySemanticsLabel('4 od 5 zvjezdica'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('duga recenzija je skraćena, kratka nema „Prikaži više"', (
      tester,
    ) async {
      final dugi = List.filled(
        40,
        'Šišanje je bilo odlično i sve je prošlo na vrijeme.',
      ).join(' ');

      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: [
          recenzija(id: 'r1', autor: 'Nedim H.', tekst: dugi),
          recenzija(id: 'r2', autor: 'Haris M.', tekst: 'Kratko i jasno.'),
        ],
      );

      // Samo jedno dugme: kratki komentar stane i ne obećava sadržaj kojeg nema.
      expect(find.text('Prikaži više'), findsOneWidget);
      final skracen = tester.widget<Text>(find.text(dugi));
      expect(skracen.maxLines, 4);

      await tester.tap(find.text('Prikaži više'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.text(dugi)).maxLines, isNull);
      expect(find.text('Prikaži manje'), findsOneWidget);
    });

    testWidgets('ocjene bez teksta dobiju objašnjenje umjesto prazne liste', (
      tester,
    ) async {
      // Salon sa 25 ocjena i nijednom napisanom recenzijom. Prazan prostor ispod
      // „25 ocjena" se čita kao lista koja se nije učitala.
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: const [],
      );

      expect(find.text('25 ocjena'), findsOneWidget);
      expect(find.textContaining('ne prikazuju u listi'), findsOneWidget);
    });
  });

  group('prazno stanje', () {
    testWidgets('salon bez ijedne ocjene ne crta „0,0 od 5"', (tester) async {
      // Agregat nema red za takav salon — `null`, ne red sa nulama. Beauty salon u
      // seedu je tačno taj slučaj.
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: null,
        recenzije: const [],
      );

      expect(find.text('Još nema recenzija.'), findsOneWidget);
      expect(find.text('0,0'), findsNothing);
      expect(find.text('od 5'), findsNothing);
    });
  });

  group('ekran je read-only', () {
    testWidgets('nema dugmeta „Ostavi recenziju"', (tester) async {
      // Handoff ga crta na dnu 13-recenzije.png, ali klijent nad `reviews` nema nijedan
      // write grant. Dugme koje otvori formu koja ne može spasiti tekst je gore od
      // dugmeta kojeg nema — odluka je zapisana u doc komentaru ekrana.
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: [recenzija(id: 'r1', autor: 'Nedim H.')],
      );

      expect(find.textContaining('Ostavi'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('pod-ekran bez tab bara', () {
    testWidgets('`SPEC.md` 5m: traka se ne crta', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: const [],
      );

      expect(find.byType(AppBottomNav), findsNothing);

      // Zaglavlje je **`BackHeader`, ne `AppBar`** — handoff crta „← Početna" pa naslov
      // kao veliki serif u tijelu. `AppBar` je davao mali sans naslov i platformski
      // chevron; vidjelo se tek na uređaju, pored ekrana koji to rade ispravno.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackHeader), findsOneWidget);
      expect(find.text('Početna'), findsOneWidget);
    });

    testWidgets('naslov ekrana je serif u tijelu, ne sitan sans u zaglavlju', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.reviews.path,
        ocjena: ocjena,
        recenzije: const [],
      );

      final naslov = tester.widget<Text>(find.text('Recenzije'));
      final tema = Theme.of(tester.element(find.text('Recenzije')));

      expect(
        naslov.style?.fontFamily ?? tema.textTheme.displaySmall?.fontFamily,
        tema.textTheme.displaySmall?.fontFamily,
        reason: 'Naslov mora nositi serif porodicu iz displaySmall',
      );
      expect(
        naslov.style?.fontSize ?? tema.textTheme.displaySmall?.fontSize,
        tema.textTheme.displaySmall?.fontSize,
        reason: 'Naslov u AppBar-u je bio titleLarge — upola manji od handoffa',
      );
    });
  });
}
