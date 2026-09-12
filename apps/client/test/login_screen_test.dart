import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/auth_config_provider.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/auth/login_screen.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:client/src/features/booking/booking_identity.dart';
import 'package:client/src/features/booking/details_step_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

/// Login na kraju booking flowa — task 13.
///
/// **Ovdje se mjeri zamka koju task imenuje**, ne samo da ekran postoji:
/// `bookingFlowProvider` je `autoDispose`, pa je pitanje da li izbor preživi odlazak na
/// `/auth/login` i povratak. Odgovor se ne pretpostavlja — flow se prođe kroz stvarni
/// router, sa stvarnim ekranima, i kartica „Čuvamo vam" se čita nakon povratka.
///
/// Mock je samo `AuthRepository` (mreže nema) i `BookingRepository` (baze nema). Ekrani,
/// router, kontroler i provideri su pravi.
void main() {
  group('email OTP', () {
    testWidgets('unos maila → šest cifara → povratak u flow, izbor netaknut', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(
        tester,
        auth: auth,
        ruta: ClientRoute.bookDetails.path,
        pocetniFlow: (n) => n
          ..chooseService(_usluga.id)
          ..chooseEmployee(_radnik.id)
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      // Korak 4 je ekran prijave: kartica sa izborom, pa dugmad. Bez polja za telefon.
      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      // Prijava je i dalje **dio koraka 4** — kartica ide s njom, po handoffu 5f.
      expect(find.text('Čuvamo vam'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'gost@primjer.ba');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      expect(auth.brojZahtjevaZaKod, 1);
      expect(auth.zadnjiEmail, 'gost@primjer.ba');
      expect(find.textContaining('gost@primjer.ba'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Potvrdi'));
      await tester.pumpAndSettle();

      // **Ovo je stvarni predmet testa.** Povratak je na korak 4, a izbor iz prva tri
      // koraka je preživio `autoDispose` — da nije, kartica bi imala „—" umjesto datuma
      // i nijedno ime usluge.
      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.textContaining('Šišanje'), findsWidgets);
      expect(find.textContaining('Amar'), findsWidgets);

      // Prijavljen korisnik više ne vidi dugmad prijave nego dugme koje šalje zahtjev.
      expect(find.text('Nastavi sa emailom'), findsNothing);
      expect(find.text('Pošalji zahtjev'), findsOneWidget);

      container.dispose();
    });

    testWidgets('nema polja za telefon nigdje u prijavi', (tester) async {
      // `docs/06 §3.1` — push zamjenjuje i poziv i SMS. Regresija koja bi se inače
      // primijetila tek na store submissionu, kao novi zahtjev za privatnost.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      final polje = tester.widget<TextField>(find.byType(TextField));
      expect(polje.keyboardType, TextInputType.emailAddress);
      expect(find.textContaining('telefon', findRichText: true), findsNothing);
      expect(find.textContaining('Telefon'), findsNothing);

      container.dispose();
    });

    testWidgets('„Pošalji kod ponovo" stvarno šalje drugi put', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gost@primjer.ba');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pošalji kod ponovo'));
      await tester.pumpAndSettle();

      expect(auth.brojZahtjevaZaKod, 2);
      // Potvrda je blok na ekranu, ne `SnackBar`: korisnik u tom trenutku gleda u mail.
      expect(find.text('Novi kod je poslan.'), findsOneWidget);

      container.dispose();
    });
  });

  group('greška je stanje ekrana', () {
    testWidgets('pogrešan kod ostaje na ekranu i savjetuje novi kod', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        prijavaGreska: const AuthRejectedError(
          'Token has expired or is invalid',
        ),
      );
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gost@primjer.ba');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Potvrdi'));
      await tester.pumpAndSettle();

      // Ostaje na prijavi, sa porukom koja kaže **šta uraditi**, ne „nešto je pošlo
      // naopako". Poruka ne nestaje sama — nije `SnackBar`.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Kod nije tačan ili je istekao. Pošaljite novi.'),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('rate limit dobija poruku o čekanju, ne o grešci', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        otpGreska: const RateLimitError('over_email_send_rate_limit'),
      );
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gost@primjer.ba');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      expect(
        find.text('Previše pokušaja. Sačekajte minut pa pokušajte ponovo.'),
        findsOneWidget,
      );

      container.dispose();
    });

    testWidgets('neispravan mail se zaustavi prije poziva ka Supabaseu', (
      tester,
    ) async {
      // Rate limit je po adresi i po IP-u; trošiti ga na „gost@" znači da korisnik koji
      // ispravi grešku u kucanju dobije odbijenicu na drugom, tačnom pokušaju.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gost@');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      expect(auth.brojZahtjevaZaKod, 0);
      expect(find.text('Unesite ispravnu email adresu.'), findsOneWidget);

      container.dispose();
    });

    testWidgets('Apple prijava kaže da nije dostupna i nudi email', (
      tester,
    ) async {
      // Nativni paketi nisu u `pubspec.yaml`, a client ID-evi iz taska 12 nisu upisani.
      // Dugme zato mora reći šta **radi**, ne prikazati generičku grešku.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa Apple'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ovaj način prijave još nije dostupan. Prijavite se emailom.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('odustajanje', () {
    testWidgets('nazad sa koda vodi na email, pa na izbor, pa na korak 4', (
      tester,
    ) async {
      // Jedan „nazad" ne smije izbaciti korisnika iz cijele prijave — mail sa kodom je
      // već stigao i ponovni ulazak bi značio novi kod i potrošen rate limit.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(
        tester,
        auth: auth,
        ruta: ClientRoute.bookDetails.path,
        pocetniFlow: (n) => n
          ..chooseService(_usluga.id)
          ..chooseEmployee(_radnik.id)
          ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
      );

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gost@primjer.ba');
      await tester.tap(find.text('Pošalji kod'));
      await tester.pumpAndSettle();

      expect(find.text('Unesite kod'), findsOneWidget);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.text('Vaš email'), findsOneWidget);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.text('Nastavi sa emailom'), findsOneWidget);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();

      // Natrag na korak 4, sa izborom koji je čekao cijelo vrijeme.
      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      container.dispose();
    });
  });

  group('provideri dolaze iz konfiguracije', () {
    // `docs/06 §6.2`: koji se provideri nude je podatak, ne grana u widgetu. Da li filter
    // po platformi radi (Apple na iOS-u, ne na Androidu) dokazuje task 12 u
    // `auth_config_test.dart`; ovdje se dokazuje da ekran tu listu poštuje doslovno.
    //
    // Dva testa, ne petlja sa dva `_pump`-a: drugi container u istom tijelu testa ostavi
    // tajmer koji `flutter_test` prijavi kao "A Timer is still pending".
    testWidgets('lista sa Appleom ga i prikazuje, i to prvog', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      expect(find.text('Nastavi sa Apple'), findsOneWidget);
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      // Facebook je isključen po defaultu (`docs/06 §7.4`).
      expect(find.text('Nastavi sa Facebookom'), findsNothing);

      container.dispose();
    });

    testWidgets('lista bez Applea ga nigdje ne pokaže', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(
        tester,
        auth: auth,
        ruta: _loginIzFlowa,
        provideri: const [AuthProvider.google, AuthProvider.email],
      );

      expect(find.text('Nastavi sa Apple'), findsNothing);
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      expect(find.text('Nastavi sa emailom'), findsOneWidget);

      container.dispose();
    });
  });

  group('sigurnost povratka', () {
    testWidgets('strani `?from=` se ignoriše i vodi na početnu', (
      tester,
    ) async {
      // Na webu je `?from=` vrijednost iz adresne trake. Neprovjerena bi pretvorila našu
      // prijavu u preusmjerenje na tuđi sajt — klasičan open redirect.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      final container = await _pump(
        tester,
        auth: auth,
        ruta: '${ClientRoute.login.path}?from=https://tudje.example',
      );

      final ekran = tester.widget<LoginScreen>(find.byType(LoginScreen));
      expect(ekran.from, 'https://tudje.example');
      // Kartica termina se ne crta — ekran nije prepoznao rutu kao dio flowa.
      expect(find.text('Čuvamo vam'), findsNothing);

      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);

      container.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Podaci i podizanje app-e
// ---------------------------------------------------------------------------

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _danas = LocalDate(2026, 9, 14);

/// `/auth/login` onako kako ga otvara korak 4.
final _loginIzFlowa = Uri(
  path: ClientRoute.login.path,
  queryParameters: {'from': ClientRoute.bookDetails.path},
).toString();

const _env = AppEnv(
  salonId: _salonId,
  supabaseUrl: '',
  supabaseAnonKey: '',
  apiUrl: '',
);

const _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
);

const _usluga = Service(
  id: '10000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Šišanje',
  price: 15,
  durationMinutes: 30,
);

const _radnik = Employee(
  id: '20000000-0000-4000-8000-000000000001',
  salonId: _salonId,
  name: 'Amar',
  role: 'Barber',
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required String ruta,
  List<AuthProvider> provideri = const [
    AuthProvider.apple,
    AuthProvider.google,
    AuthProvider.email,
  ],
  void Function(BookingFlowNotifier notifier)? pocetniFlow,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  tester.view
    ..physicalSize = const Size(1200, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(_env),
      currentSalonIdProvider.overrideWithValue(_salonId),
      salonProvider.overrideWith((ref) async => _salon),
      servicesProvider.overrideWith((ref) async => const [_usluga]),
      employeesProvider.overrideWith((ref) async => const [_radnik]),
      employeeServiceLinksProvider.overrideWith(
        (ref) async => const <EmployeeService>[],
      ),
      workingHoursProvider.overrideWith((ref) async => const <WorkingHour>[]),
      verticalProvider.overrideWith((ref) async => Vertical.fallback),
      authRepositoryProvider.overrideWithValue(auth),
      // Lista se zadaje **već filtrirana**, kao što je ekran i čita. Da li filter po
      // platformi radi je pitanje `AuthConfig.forPlatform` i dokazano je u tasku 12
      // (`auth_config_test.dart`); ovdje bi njegovo ponovno dokazivanje tražilo
      // `debugDefaultTargetPlatformOverride`, koji `flutter_test` odbija kad se ne
      // vrati prije kraja tijela testa.
      visibleAuthProvidersProvider.overrideWithValue(provideri),
      // `customers` red pravi tek task 14; dotad je odgovor `null` i u pravoj app-i.
      bookingCustomerIdProvider.overrideWithValue(null),
      bookingTodayProvider.overrideWithValue(_danas),
    ],
  );

  // Pretplata postoji **samo dok se flow puni**, i zatvara se čim app preuzme slušanje.
  //
  // Ovo nije sitnica u podešavanju testa nego uslov da test mjeri ono što tvrdi.
  // `bookingFlowProvider` je `autoDispose`; pretplata koja traje cijeli test drži izbor
  // živim bez obzira na to da li ga ekran drži, pa bi test prolazio i nad app-om koja
  // izbor gubi. Tako je prvo izdanje ovog testa i prolazilo, a prolaz kroz browser je
  // pokazao prazan korak 4 nakon prijave.
  final pretplata = container.listen(bookingFlowProvider, (_, _) {});

  if (pocetniFlow != null) {
    pocetniFlow(container.read(bookingFlowProvider.notifier));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  // App je sada jedini slušalac. Od ove tačke izbor preživljava samo ako ga ekrani
  // stvarno drže.
  pretplata.close();
  await tester.pump();

  return container;
}
