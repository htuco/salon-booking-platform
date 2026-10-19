import 'package:client/main.dart';
import 'package:client/src/core/auth_config_provider.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/core/router/app_router.dart';
import 'package:client/src/features/auth/complete_profile_screen.dart';
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
import 'support/fake_client_profile_repository.dart';

/// Login na kraju booking flowa. Mock je samo mrežna granica; ekran, kontroler, router
/// i booking state su pravi.
void main() {
  group('email i lozinka', () {
    testWidgets('prijava vraća korisnika u sačuvani booking flow', (
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

      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      // Jedan tap: korak 4 vodi pravo na email formu. Ranije se otvarao isti izbor
      // providera („Čuvamo vam" + ista dugmad) i trebalo je tapnuti dvaput.
      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      expect(find.text('Čuvamo vam'), findsNothing);
      expect(find.text('Nastavi sa emailom'), findsNothing);
      await _otvoriPrijavu(tester, vecNaFormi: true);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(auth.brojPrijava, 1);
      expect(auth.zadnjiEmail, 'gost@primjer.ba');
      expect(find.byType(DetailsStepScreen), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.textContaining('Šišanje'), findsWidgets);
      expect(find.textContaining('Amar'), findsWidgets);
      expect(find.text('Pošalji zahtjev'), findsOneWidget);
      // Tačno jedan izlazak: login je skinut, korak 4 nije (dvostruki `pop` bi skinuo i
      // njega, a dvostruki `go` je ranije gradio korak ponovo).
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(DetailsStepScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('email počinje registracijom, a prijava je sekundarna', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      // Task 66: novi korisnik ne prolazi kroz prijavu da bi došao do registracije.
      expect(find.text('Kreirajte račun'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-name')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-phone')), findsOneWidget);
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
      // Lozinka se kuca jednom, sa „prikaži lozinku".
      expect(find.byKey(const ValueKey('login-password-repeat')), findsNothing);
      expect(find.byTooltip('Prikaži lozinku'), findsOneWidget);
      expect(find.text('Već imate račun? Prijavite se'), findsOneWidget);

      container.dispose();
    });

    testWidgets(
      'registracija šalje ime, telefon i pristanak i vraća u booking flow',
      (tester) async {
        final auth = FakeAuthRepository();
        addTearDown(auth.dispose);
        final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

        await tester.tap(find.text('Nastavi sa emailom'));
        await tester.pumpAndSettle();
        await _popuniRegistraciju(tester);
        await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
        await tester.pump();
        await tester.tap(find.text('Kreiraj račun'));
        await tester.pumpAndSettle();

        expect(auth.brojRegistracija, 1);
        expect(auth.zadnjiEmail, 'novi@primjer.ba');
        // Pozivni +387 je podrazumijevani, a vodeća nula lokalnog zapisa otpada.
        expect(auth.zadnjaRegistracija, (
          fullName: 'Ana Anić',
          phone: '+387 61 123 456',
          acceptedTerms: true,
        ));
        expect(find.byType(DetailsStepScreen), findsOneWidget);

        container.dispose();
      },
    );

    testWidgets('bez checkboxa uslova registracija se ne šalje', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await _popuniRegistraciju(tester);

      // Prazan po defaultu (ADR-0029), i bez njega dugme nema akciju.
      final checkbox = tester.widget<Checkbox>(
        find.byKey(const ValueKey('terms-checkbox')),
      );
      expect(checkbox.value, isFalse);
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(auth.brojRegistracija, 0);
      container.dispose();
    });

    testWidgets('izabrani pozivni ide uz broj, a slova ne ulaze u polje', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await _popuniRegistraciju(tester);
      await tester.enterText(
        find.byKey(const ValueKey('signup-phone')),
        '0151 abc 2345678',
      );
      // Formatter pušta samo cifre i znakove grupisanja.
      expect(find.text('0151  2345678'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('phone-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+49  Njemačka').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(auth.zadnjaRegistracija?.phone, '+49 151 2345678');
      container.dispose();
    });

    testWidgets('linkovi uz checkbox otvaraju oba dokumenta', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Uslove korištenja'));
      await tester.pump();
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.terms.path,
      );
      container.read(appRouterProvider).pop();
      await tester.pump();
      await tester.tap(find.text('Politiku privatnosti'));
      await tester.pump();
      expect(
        container.read(appRouterProvider).state.uri.path,
        ClientRoute.privacy.path,
      );

      container.dispose();
    });

    // Bug sa hostovanog projekta: *Confirm email* je uključen, `signUp` vraća korisnika bez
    // sesije. Ekran je tada govorio „ovaj način prijave nije dostupan" — i to na samoj
    // email formi, pa korisnik nije imao kud.
    testWidgets('registracija bez sesije kaže da račun čeka potvrdu emaila', (
      tester,
    ) async {
      final auth = FakeAuthRepository(
        registracijaGreska: const EmailNotConfirmedError('Confirm email'),
      );
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await _popuniRegistraciju(tester);
      await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(find.textContaining('čeka potvrdu emaila'), findsOneWidget);
      expect(find.textContaining('nije dostupan'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('postojeći email i slaba lozinka imaju svoje poruke', (
      tester,
    ) async {
      for (final (greska, poruka) in [
        (
          const AccountExistsError('user_already_exists') as ApiError,
          'Račun sa ovim emailom već postoji. Prijavite se.',
        ),
        (
          const WeakPasswordError('weak_password'),
          'Lozinka je preslaba. Koristite najmanje 8 znakova, slovo i cifru.',
        ),
      ]) {
        final auth = FakeAuthRepository(registracijaGreska: greska);
        final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

        await tester.tap(find.text('Nastavi sa emailom'));
        await tester.pumpAndSettle();
        await _popuniRegistraciju(tester);
        await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
        await tester.pump();
        await tester.tap(find.text('Kreiraj račun'));
        await tester.pumpAndSettle();

        expect(find.text(poruka), findsOneWidget);
        // Do taska 66 su obje izlazile kao „ovaj način prijave nije dostupan".
        expect(find.textContaining('nije dostupan'), findsNothing);

        container.dispose();
        auth.dispose();
      }
    });

    testWidgets('neispravna polja registracije ne zovu Supabase', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('signup-name')), '  ');
      await tester.enterText(
        find.byKey(const ValueKey('signup-phone')),
        '061 abc',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'kratka',
      );
      await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Kreiraj račun'));
      await tester.pumpAndSettle();

      expect(auth.brojRegistracija, 0);
      expect(find.text('Unesite ime i prezime.'), findsOneWidget);
      expect(
        find.text('Unesite broj bez pozivnog, npr. 61 123 456.'),
        findsOneWidget,
      );
      expect(find.text('Unesite ispravnu email adresu.'), findsOneWidget);
      expect(find.textContaining('najmanje 8 znakova'), findsOneWidget);

      container.dispose();
    });

    // Task 66: lozinka napravljena prije pravila, ili po pravilu koje se promijeni, mora
    // moći ući — prijava pita server, ne pravilo registracije.
    testWidgets('prijava ne provjerava pravila registracije', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'stari@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'kratka',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(auth.brojPrijava, 1);
      expect(find.textContaining('najmanje 8 znakova'), findsNothing);
      container.dispose();
    });

    testWidgets(
      'prijava bez lozinke i sa neispravnim emailom ne zove Supabase',
      (tester) async {
        final auth = FakeAuthRepository();
        addTearDown(auth.dispose);
        final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

        await _otvoriPrijavu(tester);
        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'gost@',
        );
        await tester.tap(find.text('Prijavi se'));
        await tester.pumpAndSettle();

        expect(auth.brojPrijava, 0);
        expect(find.text('Unesite ispravnu email adresu.'), findsOneWidget);
        expect(find.text('Unesite lozinku.'), findsOneWidget);
        container.dispose();
      },
    );

    testWidgets('pogrešni podaci daju generičku trajnu poruku', (tester) async {
      final auth = FakeAuthRepository(
        prijavaGreska: const AuthRejectedError('invalid_credentials'),
      );
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Pogresna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(find.text('Pogrešan email ili lozinka.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      container.dispose();
    });

    testWidgets(
      'telefon ima razlog, a nema SMS-a, demo napomene ni recovery-ja',
      (tester) async {
        final auth = FakeAuthRepository();
        addTearDown(auth.dispose);
        final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

        await tester.tap(find.text('Nastavi sa emailom'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Salon vas zove samo ako se termin mijenja. Ne šaljemo SMS.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('ne šalje potvrdu'), findsNothing);
        expect(find.textContaining('ne šaljemo email potvrdu'), findsNothing);
        expect(find.textContaining('Zaboravili'), findsNothing);
        container.dispose();
      },
    );
  });

  group('dopuni profil', () {
    testWidgets(
      'prijava bez telefona i pristanka vodi na Dopuni profil, pa nazad u flow',
      (tester) async {
        final auth = FakeAuthRepository();
        addTearDown(auth.dispose);
        final profil = FakeClientProfileRepository(
          trenutni: const ClientProfileStatus(
            hasName: true,
            hasPhone: false,
            termsCurrent: false,
          ),
        );
        final container = await _pump(
          tester,
          auth: auth,
          profil: profil,
          ruta: ClientRoute.bookDetails.path,
          pocetniFlow: (n) => n
            ..chooseService(_usluga.id)
            ..chooseEmployee(_radnik.id)
            ..chooseSlot(date: _danas, startTime: const LocalTime(9, 0)),
        );

        await tester.tap(find.text('Nastavi sa emailom'));
        await tester.pumpAndSettle();
        await _otvoriPrijavu(tester, vecNaFormi: true);
        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'google@primjer.ba',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'Sigurna123',
        );
        await tester.tap(find.text('Prijavi se'));
        await tester.pumpAndSettle();

        expect(find.byType(CompleteProfileScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        // Ime nalog već ima (Apple HIG: ne tražiti ga ponovo).
        expect(find.byKey(const ValueKey('profile-name')), findsNothing);
        expect(find.byKey(const ValueKey('profile-phone')), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('profile-phone')),
          '061 222 333',
        );
        await tester.tap(find.text('Nastavi'));
        await tester.pumpAndSettle();
        // Bez checkboxa se ništa ne šalje.
        expect(profil.zadnjeDopunjavanje, isNull);

        await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
        await tester.pump();
        await tester.tap(find.text('Nastavi'));
        await tester.pumpAndSettle();

        expect(profil.zadnjeDopunjavanje, (
          acceptTerms: true,
          phone: '+387 61 222 333',
          name: null,
        ));
        // Izbor iz flowa je preživio i prijavu i profil.
        expect(find.byType(DetailsStepScreen), findsOneWidget);
        expect(find.text('09:00'), findsOneWidget);

        container.dispose();
      },
    );

    testWidgets('nova verzija uslova traži samo checkbox, ne telefon', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final profil = FakeClientProfileRepository(
        trenutni: const ClientProfileStatus(
          hasName: true,
          hasPhone: true,
          termsCurrent: false,
        ),
      );
      final container = await _pump(
        tester,
        auth: auth,
        profil: profil,
        ruta: _loginIzFlowa,
      );

      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'stari@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Uslovi korištenja su se promijenili. Pregledajte ih i prihvatite da nastavite.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profile-phone')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Nastavi'));
      await tester.pumpAndSettle();

      // `null` telefon: baza zadržava postojeći.
      expect(profil.zadnjeDopunjavanje, (
        acceptTerms: true,
        phone: null,
        name: null,
      ));
      container.dispose();
    });

    testWidgets('greška pri čitanju statusa ne zaustavlja prijavu', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(
        tester,
        auth: auth,
        profil: FakeClientProfileRepository(
          statusGreska: const NetworkError('nema mreže'),
        ),
        ruta: _loginIzFlowa,
      );

      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'gost@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      expect(find.byType(CompleteProfileScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      container.dispose();
    });

    testWidgets('odjava sa Dopuni profil vraća korisnika neprijavljenog', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(
        tester,
        auth: auth,
        profil: FakeClientProfileRepository(
          trenutni: const ClientProfileStatus(
            hasName: false,
            hasPhone: false,
            termsCurrent: false,
          ),
        ),
        ruta: _loginIzFlowa,
      );

      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'apple@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();

      // Apple bez imena: ime se tada traži.
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      await tester.tap(find.text('Odjavi se'));
      await tester.pumpAndSettle();

      expect(auth.brojOdjava, 1);
      expect(find.byType(CompleteProfileScreen), findsNothing);
      container.dispose();
    });

    // Prije je „nazad" na Androidu vraćao na korak 4, a korisnik je ostajao prijavljen bez
    // profila — „izlaz bez spremanja je odjava" je važilo samo za dugme (pregled #136).
    Future<ProviderContainer> doDopuniProfil(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      final container = await _pump(
        tester,
        auth: auth,
        profil: FakeClientProfileRepository(
          trenutni: const ClientProfileStatus(
            hasName: true,
            hasPhone: false,
            termsCurrent: false,
          ),
        ),
        ruta: _loginIzFlowa,
      );
      await _otvoriPrijavu(tester);
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'google@primjer.ba',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Sigurna123',
      );
      await tester.tap(find.text('Prijavi se'));
      await tester.pumpAndSettle();
      expect(find.byType(CompleteProfileScreen), findsOneWidget);
      return container;
    }

    testWidgets('sistemski „nazad" sa Dopuni profil je odjava', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await doDopuniProfil(tester, auth);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(auth.brojOdjava, 1);
      expect(find.byType(CompleteProfileScreen), findsNothing);
      container.dispose();
    });

    testWidgets('spremljen profil izlazi bez odjave', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await doDopuniProfil(tester, auth);

      await tester.enterText(
        find.byKey(const ValueKey('profile-phone')),
        '61 234 567',
      );
      await tester.tap(find.byKey(const ValueKey('terms-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Nastavi'));
      await tester.pumpAndSettle();

      expect(auth.brojOdjava, 0);
      expect(find.byType(CompleteProfileScreen), findsNothing);
      container.dispose();
    });
  });

  group('navigacija i provideri', () {
    testWidgets('nazad sa emaila vodi na providere pa u booking', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      await tester.tap(find.text('Nastavi sa emailom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsStepScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('konfigurirana lista ima Apple, Google i Email', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(tester, auth: auth, ruta: _loginIzFlowa);

      expect(find.text('Nastavi sa Apple'), findsOneWidget);
      expect(find.text('Nastavi sa Google'), findsOneWidget);
      expect(find.text('Nastavi sa emailom'), findsOneWidget);
      container.dispose();
    });

    testWidgets('strani from se ignoriše i vodi na početnu', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = await _pump(
        tester,
        auth: auth,
        ruta: '${ClientRoute.login.path}?from=https://tudje.example',
      );

      expect(find.text('Čuvamo vam'), findsNothing);
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      container.dispose();
    });
  });
}

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _danas = LocalDate(2026, 9, 14);

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

Future<void> _popuniRegistraciju(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('signup-name')), 'Ana Anić');
  await tester.enterText(
    find.byKey(const ValueKey('signup-phone')),
    '061 123 456',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-email')),
    'novi@primjer.ba',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'Sigurna123',
  );
}

/// Email forma počinje registracijom; prijava je drugi tap.
Future<void> _otvoriPrijavu(
  WidgetTester tester, {
  bool vecNaFormi = false,
}) async {
  if (!vecNaFormi) {
    await tester.tap(find.text('Nastavi sa emailom'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Već imate račun? Prijavite se'));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required String ruta,
  FakeClientProfileRepository? profil,
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
      clientProfileRepositoryProvider.overrideWithValue(
        profil ?? FakeClientProfileRepository(),
      ),
      visibleAuthProvidersProvider.overrideWithValue(const [
        AuthProvider.apple,
        AuthProvider.google,
        AuthProvider.email,
      ]),
      bookingCustomerIdProvider.overrideWith((ref) async => null),
      bookingTodayProvider.overrideWithValue(_danas),
    ],
  );

  final pretplata = container.listen(bookingFlowProvider, (_, _) {});
  pocetniFlow?.call(container.read(bookingFlowProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SalonClientApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  pretplata.close();
  return container;
}
