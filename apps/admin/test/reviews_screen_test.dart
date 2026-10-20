/// Recenzije u Meluri (task 67) — salon sakriva i vraća, ali ne mijenja.
///
/// Da salon tekst ne može promijeniti drži baza (`032_pisanje_recenzija.test.sql`, tabela
/// nema `update` grant). Ovdje: ekran ne nudi ništa osim prekidača, i prekidač šalje tačno
/// suprotno stanje od onog na kartici.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/reviews/reviews_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: 'u1',
  name: 'Emir Bešić',
  email: 'emir@test.invalid',
  role: 'salon_admin',
  salonId: _salonId,
);

final _objavljena = Review(
  id: 'r1',
  salonId: _salonId,
  authorName: 'Adnan K.',
  rating: 5,
  comment: 'Fade kao i uvijek.',
  createdAt: DateTime(2026, 10, 18),
);

final _gola = Review(
  id: 'r2',
  salonId: _salonId,
  authorName: 'Selma H.',
  rating: 4,
  createdAt: DateTime(2026, 10, 15),
);

final _sakrivena = Review(
  id: 'r3',
  salonId: _salonId,
  authorName: 'Klijent',
  rating: 1,
  comment: 'Sakriven tekst.',
  createdAt: DateTime(2026, 10, 10),
  isPublished: false,
);

class _FakeReviews implements StaffReviewRepository {
  _FakeReviews(this.recenzije);

  List<Review> recenzije;
  final pozivi = <(String, bool)>[];

  @override
  Future<List<Review>> forSalon(String salonId) async => recenzije;

  @override
  Future<void> setPublished(String reviewId, {required bool published}) async {
    pozivi.add((reviewId, published));
    recenzije = [
      for (final r in recenzije)
        r.id == reviewId ? r.copyWith(isPublished: published) : r,
    ];
  }
}

Widget _ekran({_FakeReviews? repo}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    staffReviewRepositoryProvider.overrideWithValue(
      repo ?? _FakeReviews([_objavljena, _gola, _sakrivena]),
    ),
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: const AdminReviewsScreen(),
  ),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = _telefon;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

void main() {
  pristupacnostEkrana('Recenzije', _ekran);

  testWidgets('kartica nosi autora, ocjenu, tekst i stanje', (tester) async {
    await _pump(tester, _ekran());

    expect(find.text('Adnan K.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.semanticsLabel == '5 od 5' && w.data == '★★★★★',
      ),
      findsOneWidget,
    );
    expect(find.text('Fade kao i uvijek.'), findsOneWidget);
    // Gola ocjena se vidi u adminu, sa objašnjenjem umjesto praznine.
    expect(find.text('Samo ocjena, bez teksta.'), findsOneWidget);
    expect(find.text('Sakrivena — klijenti je ne vide'), findsOneWidget);
    expect(find.text('Sakrij'), findsNWidgets(2));
    expect(find.text('Vrati'), findsOneWidget);
  });

  testWidgets('nema polja za izmjenu teksta', (tester) async {
    await _pump(tester, _ekran());

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('„Sakrij" šalje false, a kartica postaje sakrivena', (
    tester,
  ) async {
    final repo = _FakeReviews([_objavljena]);
    await _pump(tester, _ekran(repo: repo));

    await tester.tap(find.text('Sakrij'));
    // `pump`, ne `pumpAndSettle`: toast se sam gasi, pa ga settle odvede.
    await tester.pump();
    await tester.pump();

    expect(repo.pozivi, [('r1', false)]);
    expect(find.text('Vrati'), findsOneWidget);
    expect(find.text('Recenzija je sakrivena.'), findsOneWidget);
  });

  testWidgets('„Vrati" šalje true', (tester) async {
    final repo = _FakeReviews([_sakrivena]);
    await _pump(tester, _ekran(repo: repo));

    await tester.tap(find.text('Vrati'));
    await tester.pumpAndSettle();

    expect(repo.pozivi, [('r3', true)]);
    expect(find.text('Sakrij'), findsOneWidget);
  });

  testWidgets('prazno stanje objašnjava odakle recenzije dolaze', (
    tester,
  ) async {
    await _pump(tester, _ekran(repo: _FakeReviews(const [])));

    expect(find.textContaining('označite završenim'), findsOneWidget);
  });
}
