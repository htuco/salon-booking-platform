/// Prijava na dvije širine — prikazi `3j` (desktop) i `3u` (telefon).
///
/// Testira se **oblik i ono što ekran obećava**, ne auth tok: da prijava stvarno radi
/// protiv GoTrue-a dokazuje `supabase/tests/rest_admin_login.ts` iz taska 23, a ovdje se
/// dokazuje da forma ostaje čitljive širine na širokom monitoru i da ekran ne nudi
/// kontrolu iza koje ne stoji ništa.
library;

import 'package:admin/src/features/auth/login_screen.dart';
import 'package:admin/src/core/widgets/admin_wordmark.dart';
import 'package:admin/src/core/theme/theme.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  _FakeStaffRepository({this.greska, this.clan})
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

  @override
  Future<StaffMember?> signIn({
    required String email,
    required String password,
  }) async {
    if (greska != null) throw greska!;
    return clan;
  }

  @override
  Future<void> signOut() async {}
}

Widget _ekran({ApiError? greska, StaffMember? clan}) => ProviderScope(
  overrides: [
    staffRepositoryProvider.overrideWithValue(
      _FakeStaffRepository(greska: greska, clan: clan),
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
      expect(find.text(kImeProizvoda), findsOneWidget);
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
}
