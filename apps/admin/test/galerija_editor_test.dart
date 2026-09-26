/// Editor galerije (task 50): dodaj, obriši, promijeni redoslijed — i konflikt dva taba.
///
/// Lažni repozitorij drži niz u memoriji i ponaša se kao `set_salon_gallery`: upisuje samo
/// kad je `expected` jednak zatečenom, inače baca [ConflictError]. Tako test mjeri ono što
/// ekran šalje kao `p_expected`, a ne samo da je nešto pozvao.
library;

import 'dart:typed_data';

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/slika_polje.dart';
import 'package:admin/src/features/settings/galerija_editor.dart';
import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salon = '550e8400-e29b-41d4-a716-446655440000';

bool _isti(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

/// Jedan upis kao dvije liste — record sa listama se poredi po identitetu, ne sadržaju.
void _upis(
  (List<String>, List<String>) upis,
  List<String> exp,
  List<String> urls, {
  String? reason,
}) {
  expect(
    upis.$1,
    exp,
    reason: reason ?? 'p_expected je ono što je ekran prikazao',
  );
  expect(upis.$2, urls, reason: reason);
}

class _LaziSaloni implements SalonRepository {
  _LaziSaloni(List<String> pocetna) : galerija = [...pocetna];

  List<String> galerija;
  final upisi = <(List<String>, List<String>)>[];
  Object? greska;

  @override
  Future<List<String>> galleryUrls(String salonId) async => [...galerija];

  @override
  Future<List<String>> setGallery({
    required String salonId,
    required List<String> expected,
    required List<String> urls,
  }) async {
    upisi.add((expected, urls));
    if (greska case final g?) throw g;
    if (!_isti(expected, galerija)) {
      throw const ConflictError('Galerija je u međuvremenu promijenjena');
    }
    galerija = [...urls];
    return urls;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LaziMedia implements MediaRepository {
  Object? greska;
  final vrste = <MediaKind>[];
  var _n = 0;

  @override
  Future<String> upload({
    required String salonId,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    vrste.add(kind);
    if (greska case final g?) throw g;
    return 'https://example.invalid/$_salon/galerija/nova-${++_n}.jpg';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _podigni(
  WidgetTester tester,
  _LaziSaloni saloni, {
  _LaziMedia? media,
  Size velicina = const Size(1440, 900),
  double skala = 1,
}) async {
  tester.view.physicalSize = velicina;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminSalonIdProvider.overrideWithValue(_salon),
        salonRepositoryProvider.overrideWithValue(saloni),
        mediaRepositoryProvider.overrideWithValue(media ?? _LaziMedia()),
        izborSlikeProvider.overrideWithValue(
          () async => IzabranaSlika(
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
            contentType: 'image/jpeg',
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildAdminTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(skala)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: GalerijaEditor(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Isti poredak kao na ekranu — po semantičkoj oznaci „Fotografija N od M".
List<String> _prikazano(WidgetTester tester) => [
  for (final e in tester.widgetList<Image>(find.byType(Image)))
    (e.image as NetworkImage).url,
];

void main() {
  testWidgets('prazna galerija je uredno prazno stanje, ne sive kutije', (
    tester,
  ) async {
    await _podigni(tester, _LaziSaloni(const []));

    expect(find.byKey(const Key('galerija-prazna')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('0 / $maksGalerija'), findsOneWidget);
  });

  testWidgets('dodaj šalje u folder galerije i upisuje novu na početak', (
    tester,
  ) async {
    final saloni = _LaziSaloni(const ['a', 'b']);
    final media = _LaziMedia();
    await _podigni(tester, saloni, media: media);

    await tester.tap(find.byKey(const Key('galerija-dodaj')));
    await tester.pumpAndSettle();

    expect(media.vrste, [MediaKind.galerija]);
    final (expected, urls) = saloni.upisi.single;
    expect(expected, [
      'a',
      'b',
    ], reason: 'p_expected je ono što je ekran prikazao');
    expect(urls.first, endsWith('/galerija/nova-1.jpg'));
    expect(urls.skip(1), ['a', 'b']);
    expect(_prikazano(tester), hasLength(3));
    expect(find.byKey(const Key('galerija-poruka')), findsNothing);
  });

  testWidgets('neuspio upload ne dira galeriju i kaže zašto', (tester) async {
    final saloni = _LaziSaloni(const ['a']);
    final media = _LaziMedia()..greska = const NetworkError('nema mreže');
    await _podigni(tester, saloni, media: media);

    await tester.tap(find.byKey(const Key('galerija-dodaj')));
    await tester.pumpAndSettle();

    expect(saloni.upisi, isEmpty);
    expect(saloni.galerija, ['a']);
    expect(find.byKey(const Key('galerija-poruka')), findsOneWidget);
  });

  testWidgets('strelice mijenjaju redoslijed, krajnje su ugašene', (
    tester,
  ) async {
    final saloni = _LaziSaloni(const ['a', 'b', 'c']);
    await _podigni(tester, saloni);

    IconButton dugme(String k) => tester.widget<IconButton>(find.byKey(Key(k)));
    expect(dugme('galerija-naprijed-1').onPressed, isNull);
    expect(dugme('galerija-nazad-3').onPressed, isNull);

    await tester.tap(find.byKey(const Key('galerija-nazad-1')));
    await tester.pumpAndSettle();
    _upis(saloni.upisi.last, ['a', 'b', 'c'], ['b', 'a', 'c']);

    await tester.tap(find.byKey(const Key('galerija-naprijed-3')));
    await tester.pumpAndSettle();
    _upis(
      saloni.upisi.last,
      ['b', 'a', 'c'],
      ['b', 'c', 'a'],
      reason: 'drugi upis kreće od osvježenog niza, ne od prvobitnog',
    );
    expect(_prikazano(tester), ['b', 'c', 'a']);
  });

  testWidgets('brisanje traži potvrdu; odustajanje ne upisuje ništa', (
    tester,
  ) async {
    final saloni = _LaziSaloni(const ['a', 'b']);
    await _podigni(tester, saloni);

    await tester.tap(find.byKey(const Key('galerija-obrisi-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();
    expect(saloni.upisi, isEmpty);

    await tester.tap(find.byKey(const Key('galerija-obrisi-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('galerija-obrisi-potvrda')));
    await tester.pumpAndSettle();
    _upis(saloni.upisi.single, ['a', 'b'], ['b']);
    expect(_prikazano(tester), ['b']);
  });

  testWidgets('konflikt drugog taba: ništa se ne pregazi, prikaže se stvarno '
      'stanje', (tester) async {
    final saloni = _LaziSaloni(const ['a', 'b']);
    await _podigni(tester, saloni);

    // Drugi tab je u međuvremenu dodao sliku; ovaj ekran i dalje prikazuje [a, b].
    saloni.galerija = ['x', 'a', 'b'];

    await tester.tap(find.byKey(const Key('galerija-obrisi-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('galerija-obrisi-potvrda')));
    await tester.pumpAndSettle();

    expect(saloni.galerija, ['x', 'a', 'b'], reason: 'tuđa izmjena je ostala');
    expect(_prikazano(tester), ['x', 'a', 'b']);
    expect(
      find.textContaining('promijenjena na drugom mjestu'),
      findsOneWidget,
    );
  });

  testWidgets('puna galerija gasi „Dodaj"', (tester) async {
    await _podigni(
      tester,
      _LaziSaloni([for (var i = 0; i < maksGalerija; i++) 'u$i']),
    );

    final dodaj = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('galerija-dodaj')),
    );
    expect(dodaj.onPressed, isNull);
    expect(find.textContaining('Galerija je puna'), findsOneWidget);
  });

  testWidgets('telefon 402 sa uvećanim fontom ne preliva', (tester) async {
    await _podigni(
      tester,
      _LaziSaloni(const ['a', 'b', 'c', 'd']),
      velicina: const Size(402, 874),
      skala: 1.6,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('galerija-dodaj')), findsOneWidget);
  });
}
