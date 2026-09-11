import 'dart:async';

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
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

    testWidgets('CTA je vidljiv i dok salon stiže — ne iskače naknadno', (
      tester,
    ) async {
      // Dugme koje se pojavi tek nakon ucitavanja pomjeri sadrzaj pod prstom koji vec
      // ide ka njemu. Zato je vidljivo od prvog framea, samo onemoguceno.
      await tester.pumpWidget(_app(salon: Completer<Salon>().future));
      await tester.pump();

      expect(find.byType(AppButton), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
    });

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
      'salon bez usluga sakriva sekciju, ne prikazuje prazan naslov',
      (tester) async {
        await tester.pumpWidget(_app(services: const []));
        await tester.pump();
        await tester.pump();

        expect(find.text('Barber Studio Vitez'), findsOneWidget);
        expect(
          find.text(VerticalTerms.fallback.servicePlural),
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
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
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
      expect(find.text('40 min'), findsOneWidget);
      expect(find.text('20 KM'), findsOneWidget);
    });

    testWidgets('vertikala bez cijena ne prikazuje cjenovnik', (tester) async {
      // Stomatolog ne objavljuje cijenu pregleda na pocetnoj (`VerticalFeatures.prices`).
      await tester.pumpWidget(
        _app(
          vertical: _vertical(prices: false),
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
    });

    testWidgets('salon bez logotipa dobije inicijale, ne prazan krug', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.pump();

      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('radno vrijeme ima svih sedam dana', (tester) async {
      await tester.pumpWidget(
        _app(
          hours: [
            for (var d = 1; d <= 7; d++)
              WorkingHour(
                id: 'wh-$d',
                salonId: _salonId,
                dayOfWeek: d,
                startTime: const LocalTime(9, 0),
                endTime: const LocalTime(17, 0),
                isClosed: d == 7,
              ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      // Sekcija radnog vremena je ispod pregiba, a `CustomScrollView` gradi samo ono sto
      // je vidljivo — bez skrola je test ne bi nasao ni kad je ispravna.
      await tester.scrollUntilVisible(
        find.text('Ponedjeljak'),
        200,
        scrollable: _vertikalniSkrol,
      );

      expect(find.text('Ponedjeljak'), findsOneWidget);
      expect(find.text('Nedjelja'), findsOneWidget);
      expect(find.text('Zatvoreno'), findsOneWidget);
      expect(find.text('09:00 – 17:00'), findsNWidgets(6));
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

      expect(find.text('Tretmani'), findsOneWidget);
      // CTA je sticky, pa je vidljiv bez skrola; sekcija tima je ispod pregiba.
      expect(find.text('Zakaži pregled'), findsOneWidget);
      expect(find.text('Zakaži termin'), findsNothing);

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

/// Vertikalni skrol ekrana. Mora se imenovati jer je na ekranu i horizontalni
/// (`TeamRow`), pa `scrollUntilVisible` bez ovoga ne zna koji da pomjeri.
final _vertikalniSkrol = find.byType(Scrollable).first;

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

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
/// Cijela app, a ne samo `HomeScreen`: ekran zavisi od teme i lokalizacije koje
/// `MaterialApp` postavlja, a `HomeScreen` u golom `MaterialApp`-u ne bi dokazao da lanac
/// radi u stvarnom stablu.
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
  Vertical? vertical,
}) => ProviderScope(
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
      (ref) => servicesBuilder?.call() ?? Future.value(services),
    ),
    employeesProvider.overrideWith((ref) async => employees),
    workingHoursProvider.overrideWith((ref) async => hours),
    verticalProvider.overrideWith((ref) async => vertical ?? _vertical()),
  ],
  child: const SalonClientApp(),
);
