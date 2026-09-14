import 'package:client/src/core/router/app_router.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// `/terms`, `/privacy`, `/about-app` i `/notifications` — task 21.
///
/// `SPEC.md` 5j, 5n i 5o; screenshotovi `10-obavijesti.png`, `14-o-aplikaciji.png` i
/// `15-pravila-koristenja.png`.
void main() {
  /// Sekcije barbera kako ih seed slaže: platformske 10/40/50, salonske 20/30/60.
  List<PolicySection> pravilaBarbera() => [
    sekcija(id: 'a1', sortOrder: 10, title: 'Zakazivanje'),
    sekcija(
      id: 's1',
      sortOrder: 20,
      title: 'Otkazivanje',
      body:
          'Termin možete otkazati najkasnije {minCancelHours} h prije '
          'početka. Poslije toga otkazivanje ide telefonom, na {phone}.',
      salon: salonId,
    ),
    sekcija(id: 's2', sortOrder: 30, title: 'Kašnjenje', salon: salonId),
    sekcija(id: 'a2', sortOrder: 40, title: 'Cijene'),
    sekcija(id: 'a3', sortOrder: 50, title: 'Vaši podaci'),
    sekcija(id: 's3', sortOrder: 60, title: 'Kontakt', salon: salonId),
  ];

  group('/terms — numeracija i sekcije', () {
    testWidgets('sekcije se numerišu 01..NN redom kojim stignu', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.terms.path,
        pravila: pravilaBarbera(),
      );

      expect(find.text('Pravila korištenja'), findsOneWidget);
      for (final broj in ['01', '02', '03', '04', '05', '06']) {
        expect(find.text(broj), findsOneWidget, reason: 'fali broj $broj');
      }
      expect(find.text('07'), findsNothing);
    });

    // Broj nije podatak iz baze nego pozicija u spojenoj listi. Salon koji doda sekciju
    // iznad pomjeri sve ispod — upisan broj bi tu odlutao od prikazanog.
    testWidgets('kraći dokument je numerisan 01..03, ne 01..06', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.terms.path,
        pravila: [
          sekcija(id: 'a1', sortOrder: 10, title: 'Zakazivanje'),
          sekcija(id: 'a2', sortOrder: 40, title: 'Cijene'),
          sekcija(id: 'a3', sortOrder: 50, title: 'Vaši podaci'),
        ],
      );

      expect(find.text('03'), findsOneWidget);
      expect(find.text('04'), findsNothing);
      // Salon bez ijedne svoje sekcije je uredno stanje, ne prazan ekran.
      expect(find.text('Zakazivanje'), findsOneWidget);
    });

    testWidgets(
      'paragrafi se razdvajaju, prazan red ne pravi prazan red teksta',
      (tester) async {
        await pumpEkran(
          tester,
          ruta: ClientRoute.terms.path,
          pravila: [
            sekcija(
              id: 'a1',
              sortOrder: 10,
              title: 'Zakazivanje',
              body: 'Prvi paragraf.\n\nDrugi paragraf.',
            ),
          ],
        );

        expect(find.text('Prvi paragraf.'), findsOneWidget);
        expect(find.text('Drugi paragraf.'), findsOneWidget);
      },
    );

    testWidgets('prazan dokument daje prazno stanje, ne pad', (tester) async {
      await pumpEkran(tester, ruta: ClientRoute.terms.path, pravila: const []);

      expect(find.text('Pravila korištenja'), findsOneWidget);
      expect(
        find.text(
          'Tekst trenutno nije dostupan. Pokušajte ponovo za koji trenutak.',
        ),
        findsOneWidget,
      );
    });
  });

  group('/terms — placeholderi', () {
    // Ovo je asercija koja čuva ADR-0009: `cancel_appointment` provodi 3 h za barbera i
    // 6 h za beauty, a handoff piše 2. Upisana cifra bi bila tvrdnja koju baza demantuje.
    testWidgets('rok otkazivanja dolazi iz salon_settings, ne iz teksta', (
      tester,
    ) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.terms.path,
        pravila: pravilaBarbera(),
        postavke: const SalonSettings(
          id: 's1',
          salonId: salonId,
          minCancelHours: 6,
        ),
      );

      expect(
        find.textContaining('najkasnije 6 h prije početka'),
        findsOneWidget,
      );
      expect(find.textContaining('{minCancelHours}'), findsNothing);
    });

    testWidgets('telefon dolazi iz salons, ne iz handoffa', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.terms.path,
        pravila: pravilaBarbera(),
      );

      // `demoSalon.phone` je `+387 62 123 456`; handoff nosi `030 711 220`, seed
      // `030 711 000` — tri broja za isti podatak, pa tekst mora uzeti onaj iz baze.
      expect(find.textContaining('+387 62 123 456'), findsOneWidget);
    });

    testWidgets('placeholder bez vrijednosti ostaje vidljiv', (tester) async {
      // Salon bez telefona: tiho brisanje bi dalo „otkazivanje ide telefonom, na ."
      await pumpEkran(
        tester,
        ruta: ClientRoute.terms.path,
        salon: const Salon(
          id: salonId,
          name: 'Beauty Studio Travnik',
          slug: 'beautystudiotravnik',
          city: 'Travnik',
        ),
        pravila: pravilaBarbera(),
      );

      expect(find.textContaining('{phone}'), findsOneWidget);
    });
  });

  group('/privacy', () {
    testWidgets('crta svoj dokument, ne pravila', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.privacy.path,
        pravila: pravilaBarbera(),
        privatnost: [
          sekcija(id: 'p1', sortOrder: 10, title: 'Ko obrađuje podatke'),
          sekcija(id: 'p2', sortOrder: 20, title: 'Šta prikupljamo'),
        ],
      );

      expect(find.text('Politika privatnosti'), findsOneWidget);
      expect(find.text('Ko obrađuje podatke'), findsOneWidget);
      expect(find.text('Zakazivanje'), findsNothing);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsNothing);
    });
  });

  group('/about-app', () {
    testWidgets('verzija dolazi iz package_info, ne iz konstante', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      expect(find.text('Verzija 1.0.4 (240)'), findsOneWidget);
    });

    testWidgets('monogram je tekst izveden iz imena salona', (tester) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      // `SPEC.md` §Assets: „the »BV« monogram in 5n is a text placeholder" — dakle ne
      // traži asset po tenantu.
      expect(find.text('BV'), findsOneWidget);
    });

    testWidgets('„Kako radi" ne obećava podsjetnik kojeg nema', (tester) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      expect(find.text('Kako radi'), findsOneWidget);
      expect(find.text('Pošaljete zahtjev'), findsOneWidget);
      expect(find.text('Salon potvrdi'), findsOneWidget);
      // Handoff ovdje crta „Dobijete podsjetnik", ali `send-reminders` i `send-push` su
      // danas samo README (task 25). Ekran u storeu ne smije obećati push kojeg nema.
      expect(find.text('Dobijete podsjetnik'), findsNothing);
      expect(find.text('Vidite status'), findsOneWidget);
    });

    testWidgets('„Ocijenite aplikaciju" stoji vidljiv ali neaktivan', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      final red = tester.widget<LinkRow>(
        find.widgetWithText(LinkRow, 'Ocijenite aplikaciju'),
      );
      expect(red.disabled, isTrue);
      expect(red.onTap, isNull);
      expect(
        find.text('Aktivira se kad aplikacija bude objavljena.'),
        findsOneWidget,
      );
    });

    testWidgets('„Prijavite problem" se ne crta dok adresa nije postavljena', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      // Red koji otvori mail bez primaoca je gori od reda kojeg nema.
      expect(find.text('Prijavite problem'), findsNothing);
    });

    testWidgets('pravni redovi vode na svoje ekrane', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.aboutApp.path,
        pravila: pravilaBarbera(),
      );

      await tester.tap(find.text('Pravila korištenja'));
      await tester.pumpAndSettle();
      expect(find.text('Zakazivanje'), findsOneWidget);
      // Back header nosi ime roditelja: ovamo se došlo sa „O aplikaciji".
      expect(find.text('O aplikaciji'), findsOneWidget);
    });

    testWidgets('kontakt redovi dolaze iz salons, prazni se ne crtaju', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ClientRoute.aboutApp.path);

      expect(find.text('Telefon salona'), findsOneWidget);
      expect(find.text('+387 62 123 456'), findsOneWidget);
      expect(find.text('Adresa'), findsOneWidget);
      // URL se pretvara u handle: puni URL se prelomi u dva reda i razbije ritam kartice.
      expect(find.text('@barberstudiovitez'), findsOneWidget);
    });

    testWidgets('salon bez kontakta ne dobija praznu karticu', (tester) async {
      await pumpEkran(
        tester,
        ruta: ClientRoute.aboutApp.path,
        salon: const Salon(
          id: salonId,
          name: 'Beauty Studio Travnik',
          slug: 'beautystudiotravnik',
          city: 'Travnik',
        ),
      );

      expect(find.text('Telefon salona'), findsNothing);
      expect(find.text('Adresa'), findsNothing);
      // Ekran i dalje stoji — kartica se sakrije, ne ostane prazan okvir.
      expect(find.text('Kako radi'), findsOneWidget);
    });
  });

  group('/notifications', () {
    // Ekran ide sad i prazan: ćelija trake postoji od taska 18 i do sada je vodila na
    // razvojni placeholder, što je gore od iskrenog praznog ekrana.
    testWidgets('prazno stanje kaže šta se očekuje i nudi izlaz', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ClientRoute.notifications.path);

      expect(find.text('Obavijesti'), findsWidgets);
      expect(
        find.textContaining('prvo kad salon potvrdi ili odbije vaš zahtjev'),
        findsOneWidget,
      );
      expect(find.text('Moji termini'), findsWidgets);
    });
  });
}
