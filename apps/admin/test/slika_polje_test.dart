/// Polje za sliku (task 49): upload mijenja vrijednost tek kad uspije, neuspjeh ostavlja
/// staru sliku i kaže zašto, „Ukloni" vraća prazno stanje.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/slika_polje.dart';
import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LaziMedia implements MediaRepository {
  _LaziMedia(this.odgovor);
  Future<String> Function() odgovor;
  final pozivi = <(String, MediaKind, String)>[];

  @override
  Future<String> upload({
    required String salonId,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
  }) {
    pozivi.add((salonId, kind, contentType));
    return odgovor();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _salon = '550e8400-e29b-41d4-a716-446655440000';
const _stari = 'https://example.invalid/stara.jpg';

Future<List<String?>> _podigni(
  WidgetTester tester,
  _LaziMedia media, {
  String? url = _stari,
  IzabranaSlika? izbor,
}) async {
  final promjene = <String?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminSalonIdProvider.overrideWithValue(_salon),
        mediaRepositoryProvider.overrideWithValue(media),
        izborSlikeProvider.overrideWithValue(
          () async =>
              izbor ??
              IzabranaSlika(
                bytes: Uint8List.fromList([1, 2, 3]),
                contentType: 'image/jpeg',
              ),
        ),
      ],
      child: MaterialApp(
        theme: buildAdminTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SlikaPolje(
              url: url,
              kind: MediaKind.radnici,
              onChanged: (novi) => setState(() {
                promjene.add(novi);
                url = novi;
              }),
            ),
          ),
        ),
      ),
    ),
  );
  return promjene;
}

void main() {
  testWidgets('uspio upload šalje u salon i vrstu, pa daje javni URL', (
    tester,
  ) async {
    final media = _LaziMedia(() async => 'https://example.invalid/nova.jpg');
    final promjene = await _podigni(tester, media);

    await tester.tap(find.byKey(const Key('slika-izaberi')));
    await tester.pump();

    expect(media.pozivi.single, (_salon, MediaKind.radnici, 'image/jpeg'));
    expect(promjene, ['https://example.invalid/nova.jpg']);
  });

  testWidgets('dok traje slanje dugme kaže „Šaljem…" i ne prima drugi tap', (
    tester,
  ) async {
    final zavrsi = Completer<String>();
    final media = _LaziMedia(() => zavrsi.future);
    await _podigni(tester, media);

    await tester.tap(find.byKey(const Key('slika-izaberi')));
    await tester.pump();
    expect(find.text('Šaljem…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('slika-izaberi')));
    await tester.pump();
    expect(media.pozivi, hasLength(1));

    zavrsi.complete('https://example.invalid/nova.jpg');
    await tester.pump();
    expect(find.text('Šaljem…'), findsNothing);
  });

  testWidgets('neuspio upload ne mijenja sliku i kaže zašto', (tester) async {
    final media = _LaziMedia(
      () => Future.error(
        mapError(
          const StorageException(
            'maximum allowed size exceeded',
            statusCode: '413',
          ),
        ),
      ),
    );
    final promjene = await _podigni(tester, media);

    await tester.tap(find.byKey(const Key('slika-izaberi')));
    await tester.pump();

    expect(promjene, isEmpty, reason: 'stara slika ostaje u obrascu');
    expect(find.text('Slika je veća od 5 MB.'), findsOneWidget);
    expect(find.byKey(const Key('slika-ukloni')), findsOneWidget);
  });

  testWidgets('„Ukloni" vraća prazno stanje, bez slomljene slike', (
    tester,
  ) async {
    final media = _LaziMedia(() async => 'x');
    final promjene = await _podigni(tester, media);

    await tester.tap(find.byKey(const Key('slika-ukloni')));
    await tester.pump();

    expect(promjene, [null]);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Izaberi sliku'), findsOneWidget);
    expect(find.byKey(const Key('slika-ukloni')), findsNothing);
  });

  testWidgets('bez slike nema „Ukloni" ni mrežne slike', (tester) async {
    await _podigni(tester, _LaziMedia(() async => 'x'), url: null);

    expect(find.text('Izaberi sliku'), findsOneWidget);
    expect(find.byKey(const Key('slika-ukloni')), findsNothing);
    expect(find.byType(Image), findsNothing);
  });
}
