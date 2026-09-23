import 'dart:async';

import 'package:client/src/features/home/widgets/contact_card.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// `/about` — „O nama", `prototype/ui/` `02-o-nama.png`.
///
/// Dvije stvari koje ovaj ekran mora dokazati:
///
/// 1. **Radno vrijeme i kontakt su ponovo u aplikaciji.** Task 18 ih je skinuo sa
///    Početne jer ih handoff drži ovdje, a ovog ekrana nije bilo — pa ih aplikacija
///    nekoliko commitova nije imala nigdje. To je regresija sa datumom, ne stilska
///    zaostavština, i test je jedino što je drži zatvorenom.
/// 2. **Sekcija bez podataka se sakriva.** Salon bez opisa, bez slika i bez Instagrama je
///    uredno stanje, ne greška — prazan naslov izgleda kao app koji nije učitao podatke.
void main() {
  const ruta = '/about';

  /// Sedmica u kojoj se dva dana razlikuju — tačno ono što jedan red „09:00 – 20:00" iz
  /// handoffa ne može prikazati.
  List<WorkingHour> sedmica() => [
    for (var dan = 1; dan <= 5; dan++)
      WorkingHour(
        id: 'wh-$dan',
        salonId: salonId,
        dayOfWeek: dan,
        startTime: const LocalTime(9, 0),
        endTime: const LocalTime(20, 0),
      ),
    WorkingHour(
      id: 'wh-6',
      salonId: salonId,
      dayOfWeek: 6,
      startTime: const LocalTime(9, 0),
      endTime: const LocalTime(15, 0),
    ),
    // Nedjelja namjerno nedostaje — dan bez reda je zatvoren dan.
  ];

  testWidgets(
    'dugme stoji na istom mjestu u kosturu i kad salon stigne (FE-301)',
    (tester) async {
      // Isti kvar kao na Početnoj: kostur je crtao hero od 320 plus razmak, pravi hero je
      // 420 bez razmaka. Dugme je skakalo 78 px kad salon stigne.
      final salon = Completer<Salon>();
      await pumpEkran(tester, ruta: ruta, salonBuilder: () => salon.future);

      final kostur = find.byWidgetPredicate(
        (w) => w is SkeletonLoader && w.height == AppSize.ctaHeight,
      );
      final vrhKostura = tester.getTopLeft(kostur.first).dy;

      salon.complete(demoSalon);
      await tester.pump();
      await tester.pump();

      expect(tester.getTopLeft(find.byType(AppButton).first).dy, vrhKostura);
    },
  );

  group('regresija taska 18 je zatvorena', () {
    testWidgets('radno vrijeme je opet u aplikaciji, i to puna sedmica', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ruta, radnoVrijeme: sedmica());

      expect(find.text('Radno vrijeme'), findsOneWidget);
      for (final dan in const [
        'Ponedjeljak',
        'Utorak',
        'Srijeda',
        'Četvrtak',
        'Petak',
        'Subota',
        'Nedjelja',
      ]) {
        expect(find.text(dan), findsOneWidget, reason: '$dan fali u sedmici');
      }
    });

    testWidgets('subota koja se razlikuje se i vidi kao drugačija', (
      tester,
    ) async {
      // Ovo je razlog zašto ekran ne prati handoff doslovno: jedan red „09:00 – 20:00"
      // bi ovdje lagao, i to bi se otkrilo tek pred zatvorenim vratima.
      await pumpEkran(tester, ruta: ruta, radnoVrijeme: sedmica());

      expect(find.text('09:00 – 20:00'), findsNWidgets(5));
      expect(find.text('09:00 – 15:00'), findsOneWidget);
      expect(find.text('Zatvoreno'), findsOneWidget, reason: 'nedjelja');
    });

    testWidgets('kontakt je opet u aplikaciji — adresa, telefon, mreže', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ruta);

      expect(find.text('Kontakt'), findsOneWidget);
      expect(find.text('Adresa'), findsOneWidget);
      expect(find.text('Trg Slobode 15, Vitez'), findsOneWidget);
      expect(find.text('Telefon'), findsOneWidget);
      expect(find.text('+387 62 123 456'), findsOneWidget);
    });

    testWidgets('URL profila se prikazuje kao nadimak, ne kao link', (
      tester,
    ) async {
      // Baza čuva cijeli URL jer je to ono što se otvara; `https://instagram.com/…` na
      // ekranu je šum koji se prelomi u dva reda.
      await pumpEkran(tester, ruta: ruta);

      expect(find.text('@barberstudiovitez'), findsOneWidget);
      expect(find.text('/barberstudiovitez'), findsOneWidget);
      expect(find.textContaining('https://'), findsNothing);
    });
  });

  group('sekcija bez podataka se sakriva', () {
    testWidgets('salon bez opisa nema priču', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        salon: demoSalon.copyWith(description: ''),
      );

      expect(find.text('Ko smo mi?'), findsNothing);
      expect(find.text('O NAMA'), findsNothing);
    });

    testWidgets('salon sa opisom dobija kicker, naslov i tekst', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ruta);

      expect(find.text('O nama'), findsWidgets);
      expect(find.text('Ko smo mi?'), findsOneWidget);
      expect(find.textContaining('već devet godina'), findsOneWidget);
    });

    testWidgets('salon bez galerije nema foto par', (tester) async {
      await pumpEkran(tester, ruta: ruta, galerija: const []);

      expect(find.byType(PhotoFrame), findsNothing);
    });

    testWidgets('foto par uzima najviše dvije slike', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        galerija: const [
          'https://primjer.test/1.jpg',
          'https://primjer.test/2.jpg',
          'https://primjer.test/3.jpg',
        ],
      );

      expect(find.byType(PhotoFrame), findsNWidgets(2));
    });

    testWidgets('salon bez ijednog reda radnog vremena sakriva sekciju', (
      tester,
    ) async {
      // Sedam redova „Zatvoreno" bi tvrdilo da salon ne radi nikad; ovo je stanje tek
      // postavljenog tenanta.
      await pumpEkran(tester, ruta: ruta, radnoVrijeme: const []);

      expect(find.text('Radno vrijeme'), findsNothing);
      expect(find.text('Zatvoreno'), findsNothing);
    });

    testWidgets('vertikala bez društvenih mreža ih ne prikazuje', (
      tester,
    ) async {
      // Ordinacija nema Instagram u aplikaciji; adresa i telefon ostaju.
      await pumpEkran(
        tester,
        ruta: ruta,
        vertical: vertikala(socialLinks: false),
      );

      expect(find.text('Instagram'), findsNothing);
      expect(find.text('Facebook'), findsNothing);
      expect(find.text('Telefon'), findsOneWidget);
    });

    testWidgets('salon bez ijednog kontakt podatka sakriva cijelu sekciju', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        salon: const Salon(
          id: salonId,
          name: 'Bez kontakta',
          slug: 'bez',
          city: '',
        ),
      );

      expect(find.text('Kontakt'), findsNothing);
      expect(find.byType(ContactRow), findsNothing);
    });
  });

  group('stanja i tema', () {
    testWidgets('dok salon stiže, ekran je skeleton — ne spinner', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        salonBuilder: () => Completer<Salon>().future,
        pumpaj: false,
      );
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('CTA nosi tekst iz terminologije vertikale', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        vertical: vertikala(bookCta: 'Zakaži pregled'),
      );

      expect(find.text('Zakaži pregled'), findsOneWidget);
    });

    testWidgets('ekran radi bez prijave', (tester) async {
      // `isSignedInProvider` je u harnessu `false`. Ako bilo koji provider ovdje zatraži
      // korisnički token, ekran padne — a „O nama" mora raditi prije prijave.
      await pumpEkran(tester, ruta: ruta, radnoVrijeme: sedmica());

      expect(find.text('Barber Studio Vitez'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
