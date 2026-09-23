/// Zajednički harness za ekrane taska 19 — `/services` i `/about`.
///
/// [pumpEkran] podiže **cijelu app-u na zadanoj ruti**, sa svakim podatkom pod kontrolom
/// testa. Cijela app, a ne goli ekran u `MaterialApp`-u: oba ekrana stoje unutar
/// `ClientShell`-a i zavise od teme, lokalizacije i tab bara. Ekran podignut sam ne bi
/// dokazao da lanac radi u stvarnom stablu — a upravo je taj lanac ono što puca.
///
/// Zaseban fajl, a ne kopija helpera iz `home_screen_test.dart`, iz razloga koji je već
/// zapisan u `catalog_harness.dart`: dvije kopije override liste se raziđu pri prvoj
/// izmjeni providera, i to tiho.
library;

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/features/legal/about_app_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Demo salon sa **popunjenim** kontaktom — „O nama" se mjeri po tome šta prikaže, pa
/// prazna polja ovdje ne bi dokazala ništa osim da se sekcija sakriva.
const demoSalon = Salon(
  id: salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  description: 'Barber Studio Vitez već devet godina radi na jednom mjestu.',
  address: 'Trg Slobode 15',
  city: 'Vitez',
  phone: '+387 62 123 456',
  instagramUrl: 'https://instagram.com/barberstudiovitez',
  facebookUrl: 'https://facebook.com/barberstudiovitez',
);

Vertical vertikala({
  String servicePlural = 'Usluge',
  String bookCta = 'Zakaži termin',
  bool prices = true,
  bool socialLinks = true,
}) => Vertical.fromJson({
  'key': 'barber',
  'display_name': 'Barber',
  'terminology': {'servicePlural': servicePlural, 'bookCta': bookCta},
  'feature_flags': {'prices': prices, 'socialLinks': socialLinks},
  'default_theme': 'modern_barber',
});

/// Podiže app na [ruta] i vraća kontejner, da test može čitati i invalidirati providere.
///
/// Ne poziva `pumpAndSettle`: skeleton pulsira dok je vidljiv, pa bi istekao i na
/// ispravnom ekranu. Dva `pump`-a su dovoljna da `FutureProvider` isporuči vrijednost.
Future<ProviderContainer> pumpEkran(
  WidgetTester tester, {
  required String ruta,
  Salon salon = demoSalon,
  Future<Salon> Function()? salonBuilder,
  List<Service> usluge = const [],
  Future<List<Service>> Function()? uslugeBuilder,
  List<WorkingHour> radnoVrijeme = const [],
  List<String> galerija = const [],
  SalonRatingSummary? ocjena,
  List<Review> recenzije = const [],
  Vertical? vertical,
  List<PolicySection> pravila = const [],
  List<PolicySection> privatnost = const [],
  SalonSettings? postavke,
  PackageInfo? packageInfo,
  AuthRepository? authRepository,

  /// Kad je zadana, galerija, ocjena i pravila bacaju ovu grešku (FE-501): greška mora
  /// izgledati drukčije od praznog stanja.
  Object? greskaIzvora,
  bool pumpaj = true,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  // Visok viewport: oba ekrana su duža od telefona, a `find` ne vidi widget koji nije
  // izgrađen. Bez ovoga bi test mjerio skrol, ne sadržaj.
  tester.view
    ..physicalSize = const Size(1200, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(
        const AppEnv(
          salonId: salonId,
          supabaseUrl: '',
          supabaseAnonKey: '',
          apiUrl: '',
        ),
      ),
      currentSalonIdProvider.overrideWithValue(salonId),
      salonProvider.overrideWith(
        (ref) => salonBuilder?.call() ?? Future.value(salon),
      ),
      servicesProvider.overrideWith(
        (ref) => uslugeBuilder?.call() ?? Future.value(usluge),
      ),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => radnoVrijeme),
      salonGalleryProvider.overrideWith(
        (ref) async => greskaIzvora != null ? throw greskaIzvora : galerija,
      ),
      salonRatingProvider.overrideWith(
        (ref) async => greskaIzvora != null ? throw greskaIzvora : ocjena,
      ),
      salonReviewsProvider.overrideWith((ref) async => recenzije),
      verticalProvider.overrideWith((ref) async => vertical ?? vertikala()),
      // Pravni ekrani (task 21) i `policyPlaceholdersProvider` čitaju pravila i postavke.
      // `salonSettingsProvider` bez override-a posegne za `Supabase.instance`, pa stoji
      // ovdje čak i za ekrane koji pravila ne crtaju — provider se gradi lijeno, ali
      // `/about-app` i `/terms` ga traže odmah.
      termsProvider.overrideWith(
        (ref) async => greskaIzvora != null ? throw greskaIzvora : pravila,
      ),
      privacyPolicyProvider.overrideWith((ref) async => privatnost),
      salonSettingsProvider.overrideWith(
        (ref) async =>
            postavke ?? const SalonSettings(id: 's1', salonId: salonId),
      ),
      // `PackageInfo.fromPlatform()` ide na platformski kanal kojeg u testu nema.
      appPackageInfoProvider.overrideWith(
        (ref) async =>
            packageInfo ??
            PackageInfo(
              appName: 'Barber Studio Vitez',
              packageName: 'ba.nasadomena.barberstudiovitez',
              version: '1.0.4',
              buildNumber: '240',
            ),
      ),
      // Tab Termini je pravi ekran i čita je li korisnik prijavljen; bez override-a
      // posegne za `Supabase.instance` kojeg u testu nema.
      isSignedInProvider.overrideWithValue(
        authRepository?.currentSession != null,
      ),
      // Postavke i „Moj račun" (task 17) čitaju sesiju kroz repozitorij, ne kroz
      // `isSignedInProvider`. Override ide na **repozitorij**, ne na izvedene providere:
      // tako `currentAuthSessionProvider` i `authSessionProvider` ostaju pravi kod, pa
      // test mjeri i to da odjava i brisanje stvarno pomjere stream.
      if (authRepository != null)
        authRepositoryProvider.overrideWithValue(authRepository),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );

  if (pumpaj) {
    await tester.pump();
    await tester.pump();
  }

  return container;
}

/// Usluga sa razumnim podrazumijevanim vrijednostima — test imenuje samo ono što mjeri.
Service usluga({
  required String id,
  required String name,
  String category = '',
  double price = 15,
  int durationMinutes = 30,
}) => Service(
  id: id,
  salonId: salonId,
  name: name,
  category: category,
  price: price,
  durationMinutes: durationMinutes,
);

/// Sekcija pravila sa razumnim podrazumijevanim vrijednostima — test imenuje samo ono što
/// mjeri. [salonId] se **ne** postavlja podrazumijevano: `null` znači platformska sekcija,
/// što je razlika koja odlučuje redoslijed kod istog `sortOrder`-a.
PolicySection sekcija({
  required String id,
  required int sortOrder,
  required String title,
  String body = 'Tijelo sekcije.',
  String? salon,
  DateTime? updatedAt,
}) => PolicySection(
  id: id,
  sortOrder: sortOrder,
  title: title,
  body: body,
  salonId: salon,
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 14),
);
