import 'dart:async';

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/about/about_sections.dart';
import 'package:client/src/features/home/widgets/gallery_grid.dart';
import 'package:client/src/features/home/widgets/rating_summary.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Home ekran je prvi pravi ekran i šablon za ostale, pa ono što se ovdje dokaže postaje
/// pravilo: podaci iz providera, terminologija iz vertikale, tri stanja prije sretnog
/// slučaja.
///
/// Od taska 18 raspored prati `prototype/ui/` `01-pocetna.png` — hero, CTA, Cjenovnik,
/// Majstori, Galerija, Recenzije — i ekran stoji **unutar `ClientShell`-a**, pa je tab bar
/// dio svakog stabla koje ovi testovi podignu. To je razlog zašto se naslov sekcije
/// ("Cjenovnik") razlikuje od labele ćelije ("Usluge"): da su isti, nijedan `findsOneWidget`
/// na tom tekstu ne bi značio ništa.
///
/// Nigdje `pumpAndSettle`: skeleton pulsira dok je vidljiv, pa bi istekao i na ispravnom
/// ekranu. Umjesto toga dva `pump`-a (dovoljno da `FutureProvider` isporuči vrijednost) i,
/// gdje se mjere boje ili se čeka Material prelaz, još jedan `pump` preko trajanja.
void main() {
  group('stanja', () {
    testWidgets('dok salon stiže, ekran je skeleton — ne spinner, ne prazno', (
      tester,
    ) async {
      await tester.pumpWidget(_app(salon: Completer<Salon>().future));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsWidgets);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'docs/02 §14 trazi skeleton, ne spinner preko praznog ekrana',
      );
    });

    testWidgets('skeleton drži mjesto CTA-a, pa sadržaj ne poskoči', (
      tester,
    ) async {
      // Do taska 18 je CTA bio zalijepljen za dno i vidljiv od prvog framea. Sada je u
      // sadrzaju, gdje ga handoff i ima, pa istu ulogu nosi skeleton: dugme koje se
      // pojavi tek nakon ucitavanja pomjeri sve ispod prsta koji vec ide ka njemu.
      await tester.pumpWidget(_app(salon: Completer<Salon>().future));
      await tester.pump();

      final visine = tester
          .widgetList<SkeletonLoader>(find.byType(SkeletonLoader))
          .map((s) => s.height)
          .toList();
      expect(
        visine,
        contains(AppSize.ctaHeight),
        reason: 'kostur mora rezervisati tacnu visinu CTA dugmeta',
      );
    });

    testWidgets(
      'CTA stoji na istom mjestu u kosturu i kad salon stigne (FE-301)',
      (tester) async {
        // Visina nije dovoljna — bitan je **vrh**. Kostur je crtao hero od 320 i razmak
        // ispod njega, a pravi hero je 420 bez razmaka: CTA je skakao 78 px nadolje
        // tačno kad prst ide ka njemu.
        final salon = Completer<Salon>();
        await tester.pumpWidget(_app(salon: salon.future));
        await tester.pump();

        final kostur = find.byWidgetPredicate(
          (w) => w is SkeletonLoader && w.height == AppSize.ctaHeight,
        );
        final vrhKostura = tester.getTopLeft(kostur.first).dy;

        salon.complete(_salon);
        await tester.pump();
        await tester.pump();

        final vrhDugmeta = tester.getTopLeft(find.byType(AppButton).first).dy;
        expect(vrhDugmeta, vrhKostura);
      },
    );

    testWidgets('greška daje poruku i retry, ne prazan ekran', (tester) async {
      await tester.pumpWidget(
        // Greska se pravi **unutar** override-a, ne kao gotov `Future.error` u argumentu:
        // `Future.error` napravljen ranije nema slusaoca u trenutku nastanka, pa ga zona
        // testa prijavi kao neuhvacen izuzetak prije nego sto provider stigne da ga primi.
        _app(
          salonBuilder: () => Future.error(const NetworkError('nema mreže')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry ponovo pokrece upit', (tester) async {
      var pozivi = 0;
      await tester.pumpWidget(
        _app(
          salonBuilder: () {
            pozivi++;
            return pozivi == 1
                ? Future<Salon>.error(const NetworkError('nema mreže'))
                : Future.value(_salon);
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyState), findsOneWidget);

      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pump();
      await tester.pump();

      expect(pozivi, 2, reason: 'retry mora zaista ponoviti upit');
      expect(find.text('Barber Studio Vitez'), findsOneWidget);
    });

    testWidgets(
      'salon bez usluga sakriva cjenovnik, ne prikazuje prazan naslov',
      (tester) async {
        await tester.pumpWidget(_app(services: const []));
        await tester.pump();
        await tester.pump();

        expect(find.text('Barber Studio Vitez'), findsOneWidget);
        expect(
          find.text('Cjenovnik'),
          findsNothing,
          reason: 'docs/02 §3: sekcija bez sadrzaja se sakriva',
        );
      },
    );

    testWidgets('salon bez radnika sakriva sekciju tima', (tester) async {
      await tester.pumpWidget(_app(employees: const []));
      await tester.pump();
      await tester.pump();

      expect(find.text(VerticalTerms.fallback.staffPlural), findsNothing);
    });

    testWidgets('greska na uslugama ne obara ekran — CTA ostaje', (
      tester,
    ) async {
      // Lista usluga koja ne stigne ne smije oboriti ekran cija je glavna svrha dugme
      // "Zakazi": booking flow i dalje radi bez pregleda kataloga.
      await tester.pumpWidget(
        _app(
          servicesBuilder: () => Future.error(const NetworkError('nema mreže')),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Barber Studio Vitez'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton).first).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('raspored po handoffu', () {
    testWidgets('hero nosi ime salona, pa živi status, pa CTA', (tester) async {
      // **Salon zatvoren svaki dan**, a ne otvoren 09–20: status se racuna iz
      // `DateTime.now()`, pa bi test sa radnim vremenom prolazio ili padao zavisno od
      // toga u koliko sati se pokrene. Ista zamka je jednom vec upala u suitu (task 16,
      // `7d1b44a`). Zatvoren salon daje isti tekst u svakom trenutku.
      await tester.pumpWidget(
        _app(
          hours: [
            for (var d = 1; d <= 7; d++)
              WorkingHour(
                id: 'wh-$d',
                salonId: _salonId,
                dayOfWeek: d,
                startTime: const LocalTime(9, 0),
                endTime: const LocalTime(20, 0),
                isClosed: true,
              ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final ime = tester.getRect(find.text('Barber Studio Vitez'));
      final status = tester.getRect(find.text('Danas zatvoreno'));
      final cta = tester.getRect(find.text('Zakaži termin'));

      expect(status.top, greaterThan(ime.top));
      expect(
        cta.top,
        greaterThan(status.top),
        reason: '`01-pocetna.png`: naslov, pa status, pa dugme',
      );
    });

    testWidgets('hero drzi status prilijepljen uz CTA, bez prazne trake', (
      tester,
    ) async {
      // **Ovo je regresioni test, ne ukras.** Naslov i status su nekad stajali na
      // `visinaSlike * 0.55` — na fiksnom procentu visine fotografije — dok im je sadrzaj
      // fiksne visine. Svako povecanje heroja je zato pola piksela slalo iznad teksta a pola
      // u praznu traku ispod njega: na 320 je bila ~12 px, na 420 je narasla na ~57 i vidjela
      // se golim okom kao rupa izmedju statusa i dugmeta.
      //
      // Test mjeri **razmak**, ne redoslijed — redoslijed je prolazio i sa rupom. Pada ako se
      // sadrzaj heroja ikad vrati na racunanje iz procenta visine.
      await tester.pumpWidget(
        _app(
          hours: [
            for (var d = 1; d <= 7; d++)
              WorkingHour(
                id: 'wh-$d',
                salonId: _salonId,
                dayOfWeek: d,
                startTime: const LocalTime(9, 0),
                endTime: const LocalTime(20, 0),
                isClosed: true,
              ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final status = tester.getRect(find.text('Danas zatvoreno'));
      final cta = tester.getRect(find.text('Zakaži termin'));
      final razmak = cta.top - status.bottom;

      // Prag stoji **izmedju dvije izmjerene vrijednosti**, ne na okruglom broju: sa
      // prilijepljenim dnom razmak je 49.5 px, sa starim racunanjem iz procenta 73.5 px.
      // Provjereno vracanjem greske, ne procjenom. Brojevi su veci nego na ekranu jer testni
      // font crta svaki znak kao kvadrat velicine fonta — bitna je razlika, ne apsolutna
      // vrijednost.
      expect(
        razmak,
        lessThan(60),
        reason:
            'izmedju statusa i CTA stoji $razmak px (ocekivano ~49.5) — sadrzaj heroja se '
            'opet racuna iz procenta visine umjesto da bude prilijepljen za dno',
      );
    });

    testWidgets('cjenovnik pokazuje tri usluge i put do ostalih', (
      tester,
    ) async {
      await tester.pumpWidget(_app(services: _osamUsluga));
      await tester.pump();
      await tester.pump();

      expect(find.text('Usluga 1'), findsOneWidget);
      expect(find.text('Usluga 3'), findsOneWidget);
      expect(
        find.text('Usluga 4'),
        findsNothing,
        reason: 'Pocetna je izlog, ne katalog — cetvrta usluga je iza dugmeta',
      );
      expect(find.text('Prikaži svih 8 usluga'), findsOneWidget);
    });

    testWidgets('tri usluge ili manje ne dobijaju dugme "Prikaži svih"', (
      tester,
    ) async {
      await tester.pumpWidget(_app(services: _osamUsluga.take(3).toList()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Prikaži svih'), findsNothing);
    });

    testWidgets('"Prikaži svih" vodi na /services', (tester) async {
      final container = _container();
      await tester.pumpWidget(_appOd(container));
      await tester.pump();
      await tester.pump();

      // `ensureVisible`, a ne `scrollUntilVisible`: ovaj drugi staje čim finder **nađe**
      // widget, a `CustomScrollView` gradi i komad izvan vidljivog dijela (`cacheExtent`).
      // Dugme je tako postojalo na y≈853 u viewportu visine 600, tap nije pogodio ništa,
      // i test je tvrdio da ruta ne radi.
      await tester.ensureVisible(find.text('Prikaži svih 8 usluga'));
      await tester.pump();
      await tester.tap(find.text('Prikaži svih 8 usluga'));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.services.path,
      );
    });

    testWidgets('galerija se ne prikazuje kad salon nema nijednu sliku', (
      tester,
    ) async {
      // Oba demo salona su danas tacno takva — `gallery_urls` im je prazan. Prazna
      // mreza bi tvrdila da slike postoje pa se nisu ucitale.
      await tester.pumpWidget(_app(gallery: const []));
      await tester.pump();
      await tester.pump();

      expect(find.text('Galerija'), findsNothing);
      expect(find.byType(GalleryGrid), findsNothing);
    });

    testWidgets('galerija se prikazuje čim slika ima', (tester) async {
      await tester.pumpWidget(
        _app(gallery: const ['https://primjer.test/1.jpg']),
      );
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Galerija'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.byType(GalleryGrid), findsOneWidget);
    });

    testWidgets('recenzije se ne prikazuju dok ocjene nema', (tester) async {
      // Sema nema tabelu `reviews` — pravi je task 20. Do tada je ovo trajno stanje.
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump();

      expect(find.text('Recenzije'), findsNothing);
      expect(find.byType(RatingSummary), findsNothing);
    });

    testWidgets('recenzije izađu čim ocjena postoji — bez dirania ekrana', (
      tester,
    ) async {
      // Ovo je jedini test koji dokazuje da task 20 mijenja **provider**, ne Pocetnu.
      await tester.pumpWidget(
        _app(
          rating: const SalonRatingSummary(
            salonId: _salonId,
            average: 4.8,
            total: 142,
            count5: 118,
            count4: 18,
            count3: 4,
            count2: 1,
            count1: 1,
          ),
          reviews: [
            Review(
              id: 'r1',
              salonId: _salonId,
              authorName: 'Nedim H.',
              rating: 5,
              comment: 'Fade je uvijek isti, tačno kako tražim.',
              createdAt: _datumRecenzije,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Recenzije'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.text('4,8'), findsOneWidget, reason: 'zarez, ne tacka');
      expect(find.text('142 ocjene'), findsOneWidget);
      expect(find.textContaining('Fade je uvijek isti'), findsOneWidget);
    });

    testWidgets('„O nama" je na Početnoj — priča, radno vrijeme i kontakt', (
      tester,
    ) async {
      // Ovo je regresija koju je task 18 uveo i koju 19 zatvara: radno vrijeme i kontakt
      // su tada skinuti sa Pocetne na ekran 5b koji nije postojao, pa ih aplikacija nije
      // imala **nigdje**. Vracaju se inline, ne za jedan tap dalje.
      await tester.pumpWidget(
        _app(
          hours: [
            WorkingHour(
              id: 'wh-1',
              salonId: _salonId,
              dayOfWeek: 1,
              startTime: const LocalTime(9, 0),
              endTime: const LocalTime(17, 0),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Radno vrijeme'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.text('Ko smo mi?'), findsOneWidget);
      expect(find.text('Ponedjeljak'), findsOneWidget);
      expect(find.text('09:00 – 17:00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Kontakt'),
        200,
        scrollable: _vertikalniSkrol,
      );
      expect(find.text('Trg Slobode 15, Vitez'), findsOneWidget);
      expect(find.text('+387 62 123 456'), findsOneWidget);
    });

    testWidgets('„O nama" na Početnoj nema foto par — Galerija ga već crta', (
      tester,
    ) async {
      // Par uzima prve dvije slike iz iste `gallery_urls` liste koju Galerija odmah
      // iznad crta u mrezi. Na ovom ekranu bi to bile iste dvije fotografije dvaput.
      await tester.pumpWidget(
        _app(
          gallery: const [
            'https://primjer.test/1.jpg',
            'https://primjer.test/2.jpg',
            'https://primjer.test/3.jpg',
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Ko smo mi?'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.byType(AboutPhotoPair), findsNothing);
    });
  });

  group('sadržaj', () {
    testWidgets('usluga nosi ime, formatirano trajanje i cijenu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          services: const [
            Service(
              id: 's1',
              salonId: _salonId,
              name: 'Fade šišanje',
              price: 20,
              durationMinutes: 40,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Fade šišanje'), findsOneWidget);
      expect(find.text('40 minuta'), findsOneWidget);
      expect(find.text('20 KM'), findsOneWidget);
    });

    testWidgets('vertikala bez cijena ne prikazuje cjenovnik', (tester) async {
      // Stomatolog ne objavljuje cijenu pregleda na pocetnoj (`VerticalFeatures.prices`).
      // Sekcija tada nije cjenovnik, pa se ni ne zove tako — naslov pada na `servicePlural`.
      await tester.pumpWidget(
        _app(
          vertical: _vertical(prices: false, servicePlural: 'Tretmani'),
          services: const [
            Service(
              id: 's1',
              salonId: _salonId,
              name: 'Pregled',
              price: 50,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Pregled'), findsOneWidget);
      expect(find.text('50 KM'), findsNothing);
      expect(find.text('Cjenovnik'), findsNothing);
      // Jednom kao naslov sekcije, jednom kao labela celije u traci.
      expect(find.text('Tretmani'), findsNWidgets(2));
    });

    testWidgets('radnik nosi titulu i staž spojene u jedan red', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          employees: const [
            Employee(
              id: 'e1',
              salonId: _salonId,
              name: 'Emir',
              role: 'Barber',
              experienceYears: 9,
            ),
            // Radnik bez staza je **predvidjeno stanje** (task 22) — red mora izgledati
            // uredno, bez visece tacke.
            Employee(
              id: 'e2',
              salonId: _salonId,
              name: 'Lejla',
              role: 'Barber',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Emir'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.text('Barber · 9 godina'), findsOneWidget);
      expect(find.text('Barber'), findsOneWidget);
    });
  });

  group('terminologija po vertikali', () {
    testWidgets('naslovi sekcija i CTA dolaze iz vertical.terms', (
      tester,
    ) async {
      // Ista klasa ekrana, drugi tekst — bez ijednog `if`-a po vertikali. Da su naslovi
      // literali, ovaj test bi trazio drugi widget, ne drugi config.
      await tester.pumpWidget(
        _app(
          vertical: _vertical(
            servicePlural: 'Tretmani',
            staffPlural: 'Naši doktori',
            bookCta: 'Zakaži pregled',
          ),
          services: const [
            Service(
              id: 's1',
              salonId: _salonId,
              name: 'Pregled',
              price: 50,
              durationMinutes: 30,
            ),
          ],
          employees: const [
            Employee(id: 'e1', salonId: _salonId, name: 'Dr. Amir'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Zakaži pregled'), findsOneWidget);
      expect(find.text('Zakaži termin'), findsNothing);
      // Celija trake uzima isti `servicePlural`; naslov sekcije je "Cjenovnik".
      expect(find.text('Tretmani'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Naši doktori'),
        200,
        scrollable: _vertikalniSkrol,
      );
      expect(find.text('Naši doktori'), findsOneWidget);
    });

    testWidgets('vertikala bez tima sakriva sekciju i kad radnici postoje', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          vertical: _vertical(team: false),
          employees: const [
            Employee(id: 'e1', salonId: _salonId, name: 'Emir'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Emir'), findsNothing);
    });
  });
}

/// Vertikalni skrol ekrana.
final _vertikalniSkrol = find.byType(Scrollable).first;

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Fiksan datum, jer Početna citat ne datira — `timeAgo` se mjeri na `/reviews`.
final _datumRecenzije = DateTime.utc(2026, 9, 11);

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  // Opis, adresa i telefon su popunjeni od taska 19: sekcije „O nama" su sada na ovom
  // ekranu, pa prazan salon vise ne bi dokazao nista osim da se sekcija sakriva.
  description: 'Barber Studio Vitez vec devet godina radi na jednom mjestu.',
  address: 'Trg Slobode 15',
  city: 'Vitez',
  phone: '+387 62 123 456',
);

final _osamUsluga = [
  for (var i = 1; i <= 8; i++)
    Service(
      id: 's$i',
      salonId: _salonId,
      name: 'Usluga $i',
      price: 15,
      durationMinutes: 30,
    ),
];

Vertical _vertical({
  String servicePlural = 'Usluge',
  String staffPlural = 'Naš tim',
  String bookCta = 'Zakaži termin',
  bool prices = true,
  bool team = true,
}) => Vertical.fromJson({
  'key': 'barber',
  'display_name': 'Barber',
  'terminology': {
    'servicePlural': servicePlural,
    'staffPlural': staffPlural,
    'bookCta': bookCta,
  },
  'feature_flags': {'prices': prices, 'team': team},
  'default_theme': 'modern_barber',
});

/// Podiže cijelu app-u na `/`, sa svakim podatkom pod kontrolom testa.
///
/// Cijela app, a ne samo `HomeScreen`: ekran zavisi od teme, lokalizacije i — od taska 18
/// — od `ClientShell`-a koji nosi tab bar. `HomeScreen` u golom `MaterialApp`-u ne bi
/// dokazao da lanac radi u stvarnom stablu.
Widget _app({
  Future<Salon>? salon,
  Future<Salon> Function()? salonBuilder,
  List<Service> services = const [
    Service(
      id: 's1',
      salonId: _salonId,
      name: 'Muško šišanje',
      price: 15,
      durationMinutes: 30,
    ),
  ],
  Future<List<Service>> Function()? servicesBuilder,
  List<Employee> employees = const [
    Employee(id: 'e1', salonId: _salonId, name: 'Emir', role: 'Barber'),
  ],
  List<WorkingHour> hours = const [],
  List<String> gallery = const [],
  SalonRatingSummary? rating,
  List<Review> reviews = const [],
  Vertical? vertical,
}) => _appOd(
  _container(
    salon: salon,
    salonBuilder: salonBuilder,
    services: services,
    servicesBuilder: servicesBuilder,
    employees: employees,
    hours: hours,
    gallery: gallery,
    rating: rating,
    reviews: reviews,
    vertical: vertical,
  ),
);

Widget _appOd(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const SalonClientApp(),
);

ProviderContainer _container({
  Future<Salon>? salon,
  Future<Salon> Function()? salonBuilder,
  List<Service>? services,
  Future<List<Service>> Function()? servicesBuilder,
  List<Employee> employees = const [
    Employee(id: 'e1', salonId: _salonId, name: 'Emir', role: 'Barber'),
  ],
  List<WorkingHour> hours = const [],
  List<String> gallery = const [],
  SalonRatingSummary? rating,
  List<Review> reviews = const [],
  Vertical? vertical,
}) {
  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(
        const AppEnv(
          salonId: _salonId,
          supabaseUrl: '',
          supabaseAnonKey: '',
          apiUrl: '',
        ),
      ),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith(
        (ref) => salonBuilder?.call() ?? salon ?? Future.value(_salon),
      ),
      servicesProvider.overrideWith(
        (ref) =>
            servicesBuilder?.call() ?? Future.value(services ?? _osamUsluga),
      ),
      employeesProvider.overrideWith((ref) async => employees),
      workingHoursProvider.overrideWith((ref) async => hours),
      salonGalleryProvider.overrideWith((ref) async => gallery),
      salonRatingProvider.overrideWith((ref) async => rating),
      salonReviewsProvider.overrideWith((ref) async => reviews),
      verticalProvider.overrideWith((ref) async => vertical ?? _vertical()),
      // Tab Termini je pravi ekran i cita da li je korisnik prijavljen; bez override-a
      // posegne za `Supabase.instance` kojeg u testu nema.
      isSignedInProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
