/// Katalog se osvježava na realtime signal, bez hladnog starta — task 32.
///
/// Do taska 32 je `SalonClientApp` na `availabilityChangesProvider` invalidirao **samo**
/// `availableSlotsProvider`. To se nije vidjelo jer se cjenovnik nije mogao mijenjati u
/// radu: `servicesProvider` nema `autoDispose`, pa je katalog živio koliko i proces.
/// Čim je salon dobio ekran za izmjenu cijena, ista rupa znači da klijent staru cijenu
/// vidi dok ne ubije aplikaciju iz recent appsa — nađeno na Android emulatoru, protiv
/// hostovanog projekta, a ne testom.
///
/// Test drži obje strane: da se provider **ponovo pročita** i da se nova vrijednost
/// **vidi na ekranu**. Sam brojač bi prošao i da ekran prikazuje keš.
library;

import 'dart:async';

import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// **Supabase vrijednosti su obavezne.** Bez njih je `hasSupabase` `false`, cijeli
/// realtime blok se preskoči, i test bi prolazio i sa uklonjenom popravkom.
const _env = AppEnv(
  salonId: _salonId,
  supabaseUrl: 'https://primjer.invalid',
  supabaseAnonKey: 'anon-kljuc',
  apiUrl: '',
);

Service _usluga(double cijena) => Service(
  id: 's1',
  salonId: _salonId,
  name: 'Brada',
  price: cijena,
  durationMinutes: 20,
);

Salon get _salon => Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

void main() {
  late StreamController<int> signal;
  late List<double> cjenovnik;
  late int citanja;
  late int citanjaPostavki;

  setUp(() {
    signal = StreamController<int>.broadcast();
    // Prvo čitanje vraća 10 KM, svako sljedeće 15 — kao da je salon u međuvremenu
    // podigao cijenu kroz admin ekran.
    cjenovnik = [10, 15];
    citanja = 0;
    citanjaPostavki = 0;
  });

  tearDown(() => signal.close());

  Widget app() => ProviderScope(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      employeesProvider.overrideWith((ref) async => const <Employee>[]),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      servicesProvider.overrideWith((ref) async {
        final cijena = cjenovnik[citanja.clamp(0, cjenovnik.length - 1)];
        citanja++;
        return [_usluga(cijena)];
      }),
      salonSettingsProvider.overrideWith((ref) async {
        citanjaPostavki++;
        return const SalonSettings(id: 'st1', salonId: _salonId);
      }),
      // Realtime i push se ne dižu: test ne dira ni mrežu ni Firebase.
      availabilityChangesProvider.overrideWith((ref, salonId) => signal.stream),
      currentAuthSessionProvider.overrideWithValue(null),
      pushInitializationProvider.overrideWith((ref) async {}),
      pushReceivedProvider.overrideWith(
        (ref) => const Stream<PushMessage>.empty(),
      ),
      pushOpenedProvider.overrideWith((ref) => const Stream<String>.empty()),
    ],
    child: const SalonClientApp(),
  );

  testWidgets('signal o promjeni cjenovnika osvježi katalog bez restarta', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    // `pump`, ne `pumpAndSettle`: skeleton puls je beskonačna animacija.
    await tester.pump();
    await tester.pump();

    expect(citanja, 1, reason: 'katalog se pročita jednom na startu');
    expect(find.text('10 KM'), findsWidgets);
    expect(find.text('15 KM'), findsNothing);

    signal.add(1);
    await tester.pump();
    await tester.pump();

    expect(
      citanja,
      greaterThan(1),
      reason: 'signal mora ponovo pročitati katalog, ne samo slotove',
    );
    expect(
      find.text('15 KM'),
      findsWidgets,
      reason: 'nova cijena mora doći do ekrana, ne samo do providera',
    );
    expect(find.text('10 KM'), findsNothing);
    expect(tester.takeException(), isNull);
    // Zatvori Riverpod pretplatu prije cekanja StreamController.close u tearDown.
    // Inace close ceka fake-async event koji se poslije zadnjeg pump-a ne isporuci.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('signal o promjeni postavki osvježi i booking pravila', (
    tester,
  ) async {
    // **Task 36 je ovo učinio dostižnim.** Trigger u `availability_realtime.sql` rotira
    // reviziju i na `salon_settings`, ali do `/settings` ekrana te postavke niko nije mogao
    // promijeniti u radu — pa se rupa nije vidjela. `salonSettingsProvider` nema
    // `autoDispose`, pa bi bez invalidacije klijent do hladnog starta nudio otkazivanje po
    // **starom** roku, dok bi `cancel_appointment` provodio novi i vratio `PT403`.
    // **Postavke se čitaju lijeno** (`auth_config_provider`, ekran termina), ne na Početnoj.
    // Zato ih test prvo mora pročitati sam — inače bi mjerio da provider bez slušaoca ne radi
    // ništa, što je tačno i beskorisno. Ovo oponaša korisnika koji je već otvorio svoj termin.
    final scope = app() as ProviderScope;
    await tester.pumpWidget(scope);
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SalonClientApp)),
    );
    // Pretplata koja živi kroz cijeli test — bez nje `invalidate` nema koga da probudi.
    final pretplata = container.listen(salonSettingsProvider, (_, _) {});
    addTearDown(pretplata.close);
    await tester.pump();

    final prije = citanjaPostavki;
    expect(prije, greaterThan(0), reason: 'postavke su pročitane bar jednom');

    signal.add(1);
    await tester.pump();
    await tester.pump();

    expect(
      citanjaPostavki,
      greaterThan(prije),
      reason:
          'signal mora ponovo pročitati `salon_settings` — rok otkazivanja se '
          'mijenja iz admina i vrijedi odmah',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
