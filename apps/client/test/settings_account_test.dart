import 'package:client/src/features/account/account_rows.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/screen_harness.dart';

/// Postavke (`/settings`, handoff 5k) i „Moj račun" (`/account`). Task 17.
///
/// Mjeri ono što se ne vidi iz koda: da ulaz do brisanja stvarno postoji, da potvrda ne
/// briše dok korisnik ne pritisne potvrdu, i da neuspjeh **ne** odjavljuje.
/// „Postavke" stoji na ekranu **i** kao labela ćelije trake, pa goli `find.text` nadje dva.
/// Naslov je onaj unutar liste — traka je ispod nje, izvan `ListView`-a.
final naslovPostavki = find.descendant(
  of: find.byType(ListView),
  matching: find.text('Postavke'),
);

void main() {
  const sesija = AuthSession(
    userId: 'auth-user-1',
    providers: {'email'},
    email: 'emir@example.test',
  );

  group('Postavke — ulaz do brisanja', () {
    testWidgets('prijavljen korisnik vidi račun, odjavu i brisanje', (
      tester,
    ) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);

      expect(naslovPostavki, findsOneWidget);
      expect(find.text('emir@example.test'), findsOneWidget);
      expect(find.text('Moj račun'), findsOneWidget);
      expect(find.text('Odjavi se'), findsOneWidget);
      expect(find.text('Izbriši račun'), findsOneWidget);
    });

    // Ovo je asercija zbog koje je 5k ušao u task 17. Bez reda „Moj račun" je `/account`
    // nedostupan iz aplikacije, a nedostupan ekran za brisanje pada na Apple reviewu.
    testWidgets('red „Moj račun" vodi na /account', (tester) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);

      await tester.tap(find.text('Moj račun'));
      await tester.pumpAndSettle();

      // Naslov ekrana u `AppBar`-u; na Postavkama je „Moj račun" bio red u listi.
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('emir@example.test'), findsOneWidget);
    });

    testWidgets('odjavljen korisnik ne vidi ni račun ni brisanje', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);

      expect(naslovPostavki, findsOneWidget);
      expect(find.text('Prijavi se'), findsOneWidget);
      // Redovi koji ne mogu ništa uraditi ne smiju stajati — izgledaju kao pokvarena app.
      expect(find.text('Moj račun'), findsNothing);
      expect(find.text('Odjavi se'), findsNothing);
      expect(find.text('Izbriši račun'), findsNothing);
    });

    // Jezik je zasad jedan, pa taj red ne vodi nigdje i ne smije glumiti da vodi.
    testWidgets('red jezika nema chevron, ostali imaju', (tester) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);

      final jezik = tester.widget<AccountRow>(
        find.widgetWithText(AccountRow, 'Jezik · Bosanski'),
      );
      expect(jezik.onTap, isNull);

      final obavijesti = tester.widget<AccountRow>(
        find.widgetWithText(AccountRow, 'Obavijesti'),
      );
      expect(obavijesti.onTap, isNotNull);
    });
  });

  group('Brisanje naloga', () {
    testWidgets('dijalog objašnjava šta ostaje, ne samo „jeste li sigurni"', (
      tester,
    ) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);
      await tester.tap(find.text('Izbriši račun'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Izbrisati račun?'), findsOneWidget);
      // DoD traži da potvrda imenuje posljedicu. Asercija ide na **zadržavanje zapisa**,
      // jer je to polovina koju je najlakše ispustiti, a bez koje korisnik ne zna šta
      // stvarno bira.
      expect(find.textContaining('Salon zadržava zapis'), findsOneWidget);
      expect(find.text('Zadrži račun'), findsOneWidget);
    });

    testWidgets('odustajanje ne briše ništa', (tester) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);
      await tester.tap(find.text('Izbriši račun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zadrži račun'));
      await tester.pumpAndSettle();

      expect(repo.brojBrisanja, 0);
      expect(repo.currentSession, isNotNull);
    });

    testWidgets('potvrda briše, odjavljuje i vraća na Početnu', (tester) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);
      await tester.tap(find.text('Izbriši račun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Izbriši račun').last);
      await tester.pumpAndSettle();

      expect(repo.brojBrisanja, 1);
      // „Bez zaostalog tokena" iz DoD-a: sesija je stvarno nestala, ne samo ekran.
      expect(repo.currentSession, isNull);
      expect(find.text('Vaš račun je izbrisan.'), findsOneWidget);
    });

    // Najvažniji negativan slučaj. Odjava nakon neuspjelog brisanja bi korisniku oduzela
    // jedini token kojim može pokušati ponovo — nalog bi ostao neobrisan zauvijek.
    testWidgets('neuspjelo brisanje ostavlja korisnika prijavljenim', (
      tester,
    ) async {
      final repo = FakeAuthRepository(
        pocetnaSesija: sesija,
        brisanjeGreska: const NetworkError('Nema veze sa serverom'),
      );
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/settings', authRepository: repo);
      await tester.tap(find.text('Izbriši račun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Izbriši račun').last);
      await tester.pumpAndSettle();

      expect(repo.brojBrisanja, 1);
      expect(repo.currentSession, isNotNull);
      expect(find.text('Nema veze sa serverom'), findsOneWidget);
      // I dalje na Postavkama, sa nepromijenjenim stanjem — korisnik može pokušati ponovo.
      expect(naslovPostavki, findsOneWidget);
    });

    testWidgets('brisanje radi i sa ekrana „Moj račun"', (tester) async {
      final repo = FakeAuthRepository(pocetnaSesija: sesija);
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/account', authRepository: repo);
      await tester.tap(find.text('Izbriši račun'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Izbriši račun').last);
      await tester.pumpAndSettle();

      expect(repo.brojBrisanja, 1);
      expect(repo.currentSession, isNull);
    });
  });

  group('Moj račun', () {
    testWidgets('nalog bez maila ne pokazuje prazan red', (tester) async {
      final repo = FakeAuthRepository(
        pocetnaSesija: const AuthSession(
          userId: 'auth-user-2',
          providers: {'apple'},
        ),
      );
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/account', authRepository: repo);

      // Apple private relay ne daje mail. Prazan red bi izgledao kao podatak koji se nije
      // učitao, a ovo je trajno stanje takvog naloga.
      expect(find.text('Bez email adrese'), findsOneWidget);
    });

    testWidgets('deep link bez sesije ne ruši ekran', (tester) async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await pumpEkran(tester, ruta: '/account', authRepository: repo);

      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Izbriši račun'), findsNothing);
    });
  });
}
