import 'dart:async';

import 'package:client/src/core/router/app_router.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// `/services` — pun cjenovnik, `prototype/ui/` `09-usluge.png`.
///
/// Mjeri tri stvari koje ekran obećava: grupisanje po kategoriji koje se **vidi samo kad
/// ima šta da se grupiše**, tap koji vodi pravo u booking sa preselektovanom uslugom, i
/// tri stanja prije sretnog slučaja.
void main() {
  const ruta = '/services';

  group('stanja', () {
    testWidgets('dok katalog stiže, ekran je skeleton — ne spinner', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        uslugeBuilder: () => Completer<List<Service>>().future,
        pumpaj: false,
      );
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('salon bez usluga dobija prazno stanje, ne praznu listu', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ruta, usluge: const []);

      expect(find.text('Cjenovnik još nije objavljen.'), findsOneWidget);
      expect(find.byType(SelectableRow), findsNothing);
    });

    testWidgets('greška daje poruku i retry koji stvarno ponovi upit', (
      tester,
    ) async {
      var pozivi = 0;
      await pumpEkran(
        tester,
        ruta: ruta,
        uslugeBuilder: () {
          pozivi++;
          return pozivi == 1
              ? Future<List<Service>>.error(const NetworkError('nema mreže'))
              : Future.value([usluga(id: 's1', name: 'Fade')]);
        },
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pump();
      await tester.pump();

      expect(pozivi, 2, reason: 'retry mora zaista ponoviti upit');
      expect(find.text('Fade'), findsOneWidget);
    });
  });

  group('grupisanje po kategoriji', () {
    testWidgets('jedna kategorija ne dobija zaglavlje — lista je ravna', (
      tester,
    ) async {
      // Ovako izgleda `09-usluge.png`. Zaglavlje iznad cijele liste ne grupiše ništa, a
      // pojede prvi ekran telefona.
      await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [
          usluga(id: 's1', name: 'Fade', category: 'Šišanje'),
          usluga(id: 's2', name: 'Muško šišanje', category: 'Šišanje'),
        ],
      );

      expect(find.text('Fade'), findsOneWidget);
      expect(find.text('Muško šišanje'), findsOneWidget);
      expect(
        find.text('Šišanje'),
        findsNothing,
        reason: 'jedna grupa nema šta da grupiše',
      );
    });

    testWidgets('dvije kategorije dobijaju zaglavlja', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [
          usluga(id: 's1', name: 'Brijanje britvom', category: 'Brada'),
          usluga(id: 's2', name: 'Fade', category: 'Šišanje'),
        ],
      );

      expect(find.text('Brada'), findsOneWidget);
      expect(find.text('Šišanje'), findsOneWidget);
      expect(find.text('Brijanje britvom'), findsOneWidget);
      expect(find.text('Fade'), findsOneWidget);
    });

    testWidgets('usluge bez kategorije uz imenovane dobijaju „Ostalo"', (
      tester,
    ) async {
      // Bez imena bi ti redovi izgledali kao nastavak prethodne grupe.
      await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [
          usluga(id: 's1', name: 'Nešto'),
          usluga(id: 's2', name: 'Fade', category: 'Šišanje'),
        ],
      );

      expect(find.text('Ostalo'), findsOneWidget);
      expect(find.text('Šišanje'), findsOneWidget);
    });

    testWidgets('nijedna usluga nema kategoriju — nema nijednog zaglavlja', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [
          usluga(id: 's1', name: 'Fade'),
          usluga(id: 's2', name: 'Brada'),
        ],
      );

      expect(find.text('Ostalo'), findsNothing);
      expect(find.byType(SelectableRow), findsNWidgets(2));
    });
  });

  group('sadržaj i tap', () {
    testWidgets('red nosi ime, formatirano trajanje i cijenu', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [
          usluga(
            id: 's1',
            name: 'Fade šišanje',
            price: 20,
            durationMinutes: 40,
          ),
        ],
      );

      expect(find.text('Fade šišanje'), findsOneWidget);
      expect(find.text('40 minuta'), findsOneWidget);
      expect(find.text('20 KM'), findsOneWidget);
    });

    testWidgets('vertikala bez cijena ne prikazuje cijenu', (tester) async {
      await pumpEkran(
        tester,
        ruta: ruta,
        vertical: vertikala(prices: false, servicePlural: 'Tretmani'),
        usluge: [usluga(id: 's1', name: 'Pregled', price: 50)],
      );

      expect(find.text('Pregled'), findsOneWidget);
      expect(find.text('50 KM'), findsNothing);
    });

    testWidgets('naslov ekrana dolazi iz terminologije vertikale', (
      tester,
    ) async {
      // Ordinacija ovdje ima „Pregledi". Literal „Usluge" u ekranu bi to zaključao do
      // sljedećeg store submissiona.
      await pumpEkran(
        tester,
        ruta: ruta,
        vertical: vertikala(servicePlural: 'Pregledi'),
        usluge: [usluga(id: 's1', name: 'Kontrola')],
      );

      // Dvaput: naslov ekrana i ćelija tab bara ispod njega.
      expect(find.text('Pregledi'), findsNWidgets(2));
    });

    testWidgets('tap na uslugu vodi u booking sa preselektovanom uslugom', (
      tester,
    ) async {
      final container = await pumpEkran(
        tester,
        ruta: ruta,
        usluge: [usluga(id: 's-fade', name: 'Fade')],
      );

      await tester.tap(find.text('Fade'));
      await tester.pumpAndSettle();

      final ruter = container.read(appRouterProvider);
      final uri = ruter.routeInformationProvider.value.uri;

      expect(uri.path, ClientRoute.bookService.path);
      expect(
        uri.queryParameters['serviceId'],
        's-fade',
        reason: 'bez `?serviceId=` korisnik bira istu uslugu dvaput',
      );
    });
  });
}
