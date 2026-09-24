/// Prijava na dvije širine — prikazi `3j` (desktop) i `3u` (telefon).
///
/// Testira se **oblik i ono što ekran obećava**, ne auth tok: da prijava stvarno radi
/// protiv GoTrue-a dokazuje `supabase/tests/rest_admin_login.ts` iz taska 23, a ovdje se
/// dokazuje da forma ostaje čitljive širine na širokom monitoru i da ekran ne nudi
/// kontrolu iza koje ne stoji ništa.
library;

import 'dart:async';

import 'package:admin/src/features/auth/login_screen.dart';
import 'package:admin/src/core/widgets/admin_wordmark.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/pristupacnost.dart';

const Size _desktop = Size(1440, 900);

/// Širi od handoffa. Postoji jer je 1440 mjesto gdje je crtano, a ne najveći ekran na
/// kojem se radi — prvi monitor od 1920 bi razvukao polje za email preko pola stola.
const Size _siroki = Size(1920, 1080);

const Size _telefon = Size(402, 874);

/// Repozitorij koji ne dodiruje mrežu.
///
/// `StaffRepository` prima `SupabaseClient` u konstruktoru, pa ga fake mora proslijediti;
/// klijent se ovdje samo **gradi**, nikad ne zove — obje metode koje ekran koristi su
/// prepisane.
class _FakeStaffRepository extends StaffRepository {
  _FakeStaffRepository({this.greska, this.clan, this.drziUToku})
    : super(
        SupabaseClient(
          'http://localhost:54321',
          'anon-kljuc-za-test',
          // Bez ovoga `GoTrueClient` odmah pokrene periodični tajmer za osvježavanje
          // tokena, pa svaki test padne na „A Timer is still pending".
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final ApiError? greska;
  final StaffMember? clan;

  /// Drži prijavu „u letu" dok test ne pozove [zavrsi].
  ///
  /// Postoji samo zbog indikatora: prijava koja se završi u istom frameu nikad ne nacrta
  /// stanje učitavanja, pa bi test koji ga traži gledao u dugme koje već piše „Prijavi se".
  final Completer<StaffMember?>? drziUToku;

  void zavrsi() => drziUToku?.complete(clan);

  @override
  Future<StaffMember?> signIn({
    required String email,
    required String password,
  }) async {
    if (drziUToku != null) return drziUToku!.future;
    if (greska != null) throw greska!;
    return clan;
  }

  @override
  Future<void> signOut() async {}
}

Widget _ekran({
  ApiError? greska,
  StaffMember? clan,
  _FakeStaffRepository? repo,
}) => ProviderScope(
  overrides: [
    staffRepositoryProvider.overrideWithValue(
      repo ?? _FakeStaffRepository(greska: greska, clan: clan),
    ),
  ],
  child: MaterialApp(theme: buildAdminTheme(), home: const AdminLoginScreen()),
);

Future<void> _naSirini(
  WidgetTester tester,
  Size velicina,
  Widget widget,
) async {
  tester.view.physicalSize = velicina;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Popuni oba polja i pritisni „Prijavi se".
Future<void> _prijavi(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'emir@primjer.test');
  await tester.enterText(find.byType(TextFormField).last, 'tajna');
  await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
  await tester.pumpAndSettle();
}

void main() {
  pristupacnostEkrana('Prijava', _ekran);

  group('desktop `3j`', () {
    testWidgets('forma stoji u koloni od 560 px, tamna ploha uzima ostatak', (
      tester,
    ) async {
      await _naSirini(tester, _desktop, _ekran());

      final forma = tester.getSize(find.byType(Form));
      expect(forma.width, 560 - 2 * 72, reason: 'kolona 560 minus padding 72');

      // Ploha pored nje popunjava sve što je ostalo — na 1440 to je 880.
      final ploha = tester.getSize(find.byKey(kAdminLoginPlohaKey));
      expect(ploha.width, _desktop.width - 560);
    });

    testWidgets('na 1920 forma ostaje ista, raste samo ploha', (tester) async {
      // Ovo je razlog zašto ekran ima dvije kolone, a ne jednu centriranu: da širi
      // monitor doda prostora **slici**, a ne dužini retka u polju za email.
      await _naSirini(tester, _siroki, _ekran());

      expect(tester.getSize(find.byType(Form)).width, 560 - 2 * 72);
      expect(
        tester.getSize(find.byKey(kAdminLoginPlohaKey)).width,
        _siroki.width - 560,
      );
    });

    testWidgets('nosi logotip i primarnu radnju', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      // **Jednom**, ne dvaput: logotip je u bijeloj koloni, a tamna ploha nosi rečenicu o
      // pristupu. Prvi prolaz ga je crtao na oba mjesta i to se vidjelo tek na snimku.
      expect(find.text(kImeProizvoda.toUpperCase()), findsOneWidget);
      expect(
        find.text('Pristup imaju samo vlasnik i majstori lokacije.'),
        findsOneWidget,
      );
      expect(find.text('Prijava'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Prijavi se'), findsOneWidget);
    });
  });

  group('telefon `3u`', () {
    testWidgets('tamno zaglavlje je visoko 280 px i stoji iznad forme', (
      tester,
    ) async {
      await _naSirini(tester, _telefon, _ekran());

      final zaglavlje = find.byKey(kAdminLoginPlohaKey);
      expect(tester.getSize(zaglavlje).height, 280);
      expect(tester.getSize(zaglavlje).width, _telefon.width);
      expect(
        tester.getTopLeft(zaglavlje).dy,
        lessThan(tester.getTopLeft(find.byType(Form)).dy),
      );
    });

    testWidgets('primarna radnja ide preko cijele širine', (tester) async {
      // Canvas je crta kao punu traku (`height:54px` preko gutter-a). Prvi prolaz je
      // koloni ostavio `center`, pa je dugme dobilo širinu svog teksta.
      await _naSirini(tester, _telefon, _ekran());

      final sirina = tester
          .getSize(find.widgetWithText(FilledButton, 'Prijavi se'))
          .width;
      expect(sirina, _telefon.width - 2 * 20);
    });

    testWidgets('„Prijavi se" stoji ispod skrola, ne u njemu', (tester) async {
      // Canvas ga crta u traci sa `border-top`, izvan skrolabilnog dijela: sa otvorenom
      // tastaturom forma skroluje, a primarna radnja ostaje na ekranu.
      await _naSirini(tester, _telefon, _ekran());

      final dugme = find.widgetWithText(FilledButton, 'Prijavi se');
      expect(dugme, findsOneWidget);
      expect(
        find.ancestor(of: dugme, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      expect(
        tester.getTopLeft(dugme).dy,
        greaterThan(tester.getTopLeft(find.byType(Form)).dy),
      );
    });
  });

  group('ekran ne nudi ono čega nema', () {
    testWidgets('bez „Face ID", koda na telefon i zaboravljene lozinke', (
      tester,
    ) async {
      // Canvas crta sve troje. Prvi dvoje `SPEC.md` izričito isključuje („prijava ostaje
      // email+password"), a reset lozinke je tok sa svojom rutom koje još nema. Test pada
      // ako ih neko prepiše iz handoffa doslovno.
      await _naSirini(tester, _telefon, _ekran());

      expect(find.text('Face ID'), findsNothing);
      expect(find.text('Prijava kodom na telefon'), findsNothing);
      expect(find.text('Zaboravljena?'), findsNothing);
      // Kvačica koja ne mijenja ništa: `supabase_flutter` sesiju čuva uvijek.
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('ne tvrdi da nalog pokriva više lokacija', (tester) async {
      // Aplikacija danas daje tačno jedan salon iz membershipa; `3a` je izvan sprinta.
      await _naSirini(tester, _desktop, _ekran());

      expect(find.textContaining('sve vaše lokacije'), findsNothing);
      expect(find.text('Upravljanje terminima vašeg salona.'), findsOneWidget);
    });
  });

  group('greške', () {
    testWidgets('pogrešna lozinka dobije svoju rečenicu', (tester) async {
      await _naSirini(
        tester,
        _desktop,
        _ekran(greska: const AuthRejectedError('nevalidni podaci')),
      );
      await _prijavi(tester);

      expect(find.text('Pogrešan email ili lozinka.'), findsOneWidget);
    });

    testWidgets('nalog bez salona nije ista greška kao pogrešna lozinka', (
      tester,
    ) async {
      // Task 23: ko ima token a nema red u `public.users` prijavi se i ne vidi nijedan
      // red — na ekranu izgleda kao prazna baza, a zapravo je nalog pogrešno postavljen.
      await _naSirini(tester, _desktop, _ekran());
      await _prijavi(tester);

      expect(
        find.textContaining('nije vezan ni za jedan salon'),
        findsOneWidget,
      );
    });

    testWidgets('radnik prolazi prijavu, ne dobija „nije vezan"', (
      tester,
    ) async {
      // Task 47 — ovo je našao browser, ne test: guard je puštao radnika, a ekran prijave
      // ga je sam odjavljivao jer je pitao `isSalonAdmin`.
      await _naSirini(
        tester,
        _desktop,
        _ekran(
          clan: const StaffMember(
            id: '22222222-0000-4000-8000-000000000002',
            name: 'Emir',
            email: 'emir@primjer.test',
            role: 'employee',
            salonId: '550e8400-e29b-41d4-a716-446655440000',
            employeeId: 'e1',
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'emir@primjer.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'tajna');
      await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
      // Uspjeh drži indikator dok router ne odvede dalje, pa `pumpAndSettle` ne staje.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('nije vezan'), findsNothing);
    });

    testWidgets('prazna polja se ne šalju na server', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
      await tester.pumpAndSettle();

      expect(find.text('Unesite email.'), findsOneWidget);
      expect(find.text('Unesite lozinku.'), findsOneWidget);
    });
  });

  testWidgets('„Prikaži" otkriva lozinku, pa je vraća', (tester) async {
    await _naSirini(tester, _telefon, _ekran());

    TextField polje() => tester.widget<TextField>(find.byType(TextField).last);
    expect(polje().obscureText, isTrue);

    await tester.tap(find.text('Prikaži'));
    await tester.pumpAndSettle();
    expect(polje().obscureText, isFalse);

    await tester.tap(find.text('Sakrij'));
    await tester.pumpAndSettle();
    expect(polje().obscureText, isTrue);
  });

  group('prag fotografije (FE-405)', () {
    // **Prijava ima svoj prag, 1000, a ne 840 kao ostatak admina.** Ostali ekrani se
    // prelamaju na `AdminBreakpoint.desktop` jer tamo prag bira ljusku; ovdje ljuske nema,
    // pa prag bira hoće li pored forme od 560 px stajati i tamna ploha.
    //
    // Brojevi su namjerno doslovni, ne `kPragFotografije`: test koji poredi konstantu sa
    // samom sobom prolazi i kad se prag pomjeri na 840.
    testWidgets('na 1024 px ploha stoji pored forme', (tester) async {
      await _naSirini(tester, const Size(1024, 800), _ekran());

      expect(find.byKey(kAdminLoginPlohaKey), findsOneWidget);
    });

    testWidgets('na 960 px ploha nije pored forme nego iznad nje', (
      tester,
    ) async {
      // Iznad starog praga (840), ispod novog (1000) — tačno pojas u kojem se promjena
      // vidi. Da je ostao prag ljuske, ovdje bi se crtao desktop raspored i tamnoj plohi
      // bi ostalo ~400 px pored forme od 560.
      //
      // **Ploha ne nestaje**, i to je bila moja prva pogrešna pretpostavka u ovom testu:
      // `3u` je crta kao zaglavlje od 280 px iznad forme. Mijenja se **gdje stoji**, ne
      // postoji li — pa se to i mjeri.
      await _naSirini(tester, const Size(960, 800), _ekran());

      final ploha = find.byKey(kAdminLoginPlohaKey);
      expect(ploha, findsOneWidget);
      expect(
        tester.getSize(ploha).width,
        960,
        reason: 'puna širina, ne kolona',
      );
      expect(tester.getSize(ploha).height, 280);
      expect(
        tester.getTopLeft(ploha).dy,
        lessThan(tester.getTopLeft(find.byType(Form)).dy),
        reason: 'zaglavlje iznad forme, ne kolona pored nje',
      );
    });

    testWidgets('„Prijavi se" postoji tačno jednom na svakoj širini', (
      tester,
    ) async {
      // **Ovo je našao browser, ne suita.** Raspored je prešao na prag 1000, ali je
      // `_forma` i dalje pitala `AdminShell.jeDesktop` (840) hoće li nacrtati dugme u
      // koloni. U pojasu 840–1000 su se palila oba puta i dugme se crtalo **dvaput** —
      // jednom u formi, jednom u traci ispod skrola.
      //
      // Nijedan postojeći test to nije hvatao jer su širine (1440, 1920, 402) preskakale
      // taj pojas. Zato se ovdje mjere sve četiri, uključujući 960.
      for (final sirina in [402.0, 960.0, 1024.0, 1440.0]) {
        await _naSirini(tester, Size(sirina, 900), _ekran());

        expect(
          find.widgetWithText(FilledButton, 'Prijavi se'),
          findsOneWidget,
          reason: 'na ${sirina.toInt()} px dugme nije tačno jednom',
        );
      }
    });

    testWidgets('na 1440 px ploha dobije ostatak širine', (tester) async {
      await _naSirini(tester, _desktop, _ekran());

      final ploha = tester.getSize(find.byKey(kAdminLoginPlohaKey));
      expect(ploha.width, 1440 - 560);
    });
  });

  group('indikator prijave (FE-405)', () {
    testWidgets('nije Material spinner', (tester) async {
      // DoD: „indikator u toku prijave nije Material spinner". Prije FE-405 je ovdje
      // stajao `CircularProgressIndicator` sa **bijelom** bojom, što je uz koralno dugme
      // i pogrešan kontrast (bijela na koralu pada AA).
      final repo = _FakeStaffRepository(drziUToku: Completer<StaffMember?>());
      await _naSirini(tester, _desktop, _ekran(repo: repo));

      await tester.enterText(
        find.byType(TextFormField).first,
        'emir@primjer.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'tajna');
      await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
      await tester.pump();

      // Prijava je sada „u letu": dugme mora nositi indikator, i to **ne** Material luk.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Prijavi se'), findsNothing);

      // Pusti prijavu da se završi, inače test ostavi `Completer` koji visi.
      repo.zavrsi();
      await tester.pumpAndSettle();
    });
  });
}
