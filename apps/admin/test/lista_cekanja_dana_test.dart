/// „Lista čekanja: N" u kalendaru (task 68) — samo vlasniku, i jedan upit po sedmici.
///
/// Lažni repozitorij vraća broj i radniku, pa bi oznaka kod radnika iskočila čim bi
/// provider zaboravio ulogu: test ne zavisi od toga da baza radniku kaže `42501`.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:admin/src/features/calendar/calendar_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Srijeda, 20. maj 2026; sedmica počinje u ponedjeljak 18.
final _srijeda = DateTime(2026, 5, 20);

class _LaznaLista implements WaitlistRepository {
  final pozivi = <({LocalDate from, LocalDate to})>[];

  @override
  Future<Map<LocalDate, int>> demand({
    required String salonId,
    required LocalDate from,
    required LocalDate to,
  }) async {
    pozivi.add((from: from, to: to));
    return {const LocalDate(2026, 5, 20): 3};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FiksniDatum extends KalendarDatumNotifier {
  _FiksniDatum(this._pocetni);

  final DateTime _pocetni;

  @override
  DateTime build() => _pocetni;
}

List<Override> _overrides(_LaznaLista lista, {String? radnik}) => [
  adminSalonIdProvider.overrideWithValue(_salonId),
  adminRadnikIdProvider.overrideWithValue(radnik),
  waitlistRepositoryProvider.overrideWithValue(lista),
  kalendarDatumProvider.overrideWith(() => _FiksniDatum(_srijeda)),
];

Future<void> _pump(WidgetTester tester, _LaznaLista lista, {String? radnik}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(lista, radnik: radnik),
        child: MaterialApp(
          theme: buildAdminTheme(),
          home: Scaffold(body: ListaCekanjaDana(dan: _srijeda)),
        ),
      ),
    );

void main() {
  testWidgets('vlasnik vidi broj za dan', (tester) async {
    final lista = _LaznaLista();
    await _pump(tester, lista);
    await tester.pump();

    expect(find.text('Lista čekanja: 3'), findsOneWidget);
    expect(lista.pozivi, hasLength(1));
  });

  testWidgets('radnik ne vidi ništa i ne pita bazu', (tester) async {
    final lista = _LaznaLista();
    await _pump(tester, lista, radnik: 'e1');
    await tester.pump();

    expect(find.textContaining('Lista čekanja'), findsNothing);
    expect(lista.pozivi, isEmpty);
  });

  test(
    'klik na dan iste sedmice ne šalje novi upit, sljedeća sedmica šalje',
    () async {
      final lista = _LaznaLista();
      final container = ProviderContainer(overrides: _overrides(lista));
      addTearDown(container.dispose);
      // `autoDispose`: bez slušaoca bi svako čitanje bilo novi upit.
      container.listen(kalendarListaCekanjaProvider, (_, _) {});
      await container.read(kalendarListaCekanjaProvider.future);

      final datum = container.read(kalendarDatumProvider.notifier);
      for (final dan in [18, 19, 21, 22, 23, 24]) {
        datum.postavi(DateTime(2026, 5, dan));
        await container.read(kalendarListaCekanjaProvider.future);
      }
      expect(lista.pozivi, hasLength(1));
      expect(
        (lista.pozivi.single.from, lista.pozivi.single.to),
        (const LocalDate(2026, 5, 18), const LocalDate(2026, 5, 24)),
      );

      datum.postavi(DateTime(2026, 5, 25));
      await container.read(kalendarListaCekanjaProvider.future);
      expect(lista.pozivi, hasLength(2));
      expect(lista.pozivi.last.from, const LocalDate(2026, 5, 25));
    },
  );
}
