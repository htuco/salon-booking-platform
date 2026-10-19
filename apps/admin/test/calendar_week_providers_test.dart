/// Provideri sedmice kalendara (task 69) — pravila koja model ne vidi.
///
/// `calendar_week_test.dart` gađa `izgradiSedmicu`; ovdje su pravila iz
/// `calendar_providers.dart`: upit se ključa na ponedjeljak, radnik iz uloge pobjeđuje
/// izbor čipa, i sedmica čeka radnike. Repozitoriji su lažni i broje pozive, jer se
/// „promjena dana ne ide u mrežu" ne vidi u vrijednosti nego samo u broju upita.
library;

import 'dart:async';

import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/calendar/calendar_day.dart';
import 'package:admin/src/features/calendar/calendar_providers.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Ponedjeljak, 18. maj 2026.
final _ponedjeljak = DateTime(2026, 5, 18);

const _radnici = [
  Employee(id: 'e1', salonId: _salonId, name: 'Emir'),
  Employee(id: 'e2', salonId: _salonId, name: 'Vedad'),
];

Appointment _termin(String id, String radnik) => Appointment(
  id: id,
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: 'Klijent',
  date: const LocalDate(2026, 5, 19),
  startTime: const LocalTime(10, 0),
  endTime: const LocalTime(11, 0),
  status: AppointmentStatus.confirmed,
);

final _salon = [
  for (var d = 1; d <= 7; d++)
    WorkingHour(
      id: 'wh-$d',
      salonId: _salonId,
      dayOfWeek: d,
      startTime: const LocalTime(9, 0),
      endTime: const LocalTime(17, 0),
    ),
];

class _LazniTermini implements StaffAppointmentRepository {
  final pozivi = <({DateTime from, DateTime to, String? employeeId})>[];

  @override
  Future<List<Appointment>> forRange({
    required String salonId,
    required DateTime from,
    required DateTime to,
    AppointmentStatus? status,
    String? employeeId,
  }) async {
    pozivi.add((from: from, to: to, employeeId: employeeId));
    return [_termin('emir', 'e1'), _termin('vedad', 'e2')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LazneBlokade implements BlockedSlotRepository {
  final pozivi = <({DateTime from, DateTime to})>[];

  @override
  Future<List<BlockedSlot>> forRange({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    pozivi.add((from: from, to: to));
    return const [];
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

({ProviderContainer container, _LazniTermini termini, _LazneBlokade blokade})
_kontejner({String? radnikIzUloge, Future<List<Employee>>? radnici}) {
  final termini = _LazniTermini();
  final blokade = _LazneBlokade();
  final container = ProviderContainer(
    overrides: [
      adminSalonIdProvider.overrideWithValue(_salonId),
      adminRadnikIdProvider.overrideWithValue(radnikIzUloge),
      staffAppointmentRepositoryProvider.overrideWithValue(termini),
      blockedSlotRepositoryProvider.overrideWithValue(blokade),
      adminEmployeesProvider.overrideWith(
        (ref) => radnici ?? Future.value(_radnici),
      ),
      kalendarRadnoVrijemeProvider.overrideWith((ref) async => _salon),
      kalendarDatumProvider.overrideWith(() => _FiksniDatum(_ponedjeljak)),
    ],
  );
  addTearDown(container.dispose);
  // `autoDispose`: bez slušaoca bi se sedmica oslobodila između dva čitanja, pa bi svaki
  // `read` bio novi upit i brojanje ne bi ništa dokazalo.
  container.listen(kalendarSedmicaProvider, (_, _) {});
  return (container: container, termini: termini, blokade: blokade);
}

void main() {
  group('ključ je ponedjeljak', () {
    test('promjena dana u istoj sedmici ne pravi novi upit', () async {
      final (:container, :termini, :blokade) = _kontejner();
      await container.read(kalendarSedmicaProvider.future);

      final datum = container.read(kalendarDatumProvider.notifier);
      for (var i = 1; i < 7; i++) {
        datum.postavi(DateTime(2026, 5, 18 + i));
        await container.read(kalendarSedmicaProvider.future);
      }

      expect(termini.pozivi, hasLength(1));
      expect(blokade.pozivi, hasLength(1));
      expect(
        (termini.pozivi.single.from, termini.pozivi.single.to),
        (DateTime(2026, 5, 18), DateTime(2026, 5, 24)),
      );
    });

    test('sljedeća sedmica je novi upit, od ponedjeljka do nedjelje', () async {
      final (:container, :termini, :blokade) = _kontejner();
      await container.read(kalendarSedmicaProvider.future);

      container.read(kalendarDatumProvider.notifier).pomjeri(7);
      final sedmica = await container.read(kalendarSedmicaProvider.future);

      expect(termini.pozivi, hasLength(2));
      expect(
        (termini.pozivi.last.from, termini.pozivi.last.to),
        (DateTime(2026, 5, 25), DateTime(2026, 5, 31)),
      );
      expect(blokade.pozivi.last.to, DateTime(2026, 5, 31));
      expect(sedmica.pocetak, DateTime(2026, 5, 25));
    });
  });

  // Ponoć 19. oktobra + 7 × 24 h u Sarajevu padne u nedjelju 25. u 23:00 — ista sedmica,
  // pa bi strelica „Sljedeća sedmica" jednom godišnje ostala na mjestu. U zoni bez
  // ljetnog vremena (CI ide u UTC) test ništa ne dokazuje, pa se tamo preskače umjesto
  // da laže zelenim; na razvojnoj mašini se izvršava.
  final imaLjetno =
      DateTime(2026, 10, 24, 12).timeZoneOffset !=
      DateTime(2026, 10, 26, 12).timeZoneOffset;
  test(
    'strelica za sedmicu preko promjene vremena ide na sljedeći ponedjeljak',
    () {
      final container = ProviderContainer(
        overrides: [
          kalendarDatumProvider.overrideWith(
            () => _FiksniDatum(DateTime(2026, 10, 19)),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(kalendarDatumProvider.notifier).pomjeri(7);
      final ponedjeljak = pocetakSedmice(container.read(kalendarDatumProvider));

      expect(
        (ponedjeljak.year, ponedjeljak.month, ponedjeljak.day),
        (2026, 10, 26),
      );
    },
    skip: imaLjetno ? false : 'lokalna zona nema ljetno računanje vremena',
  );

  group('radnik iz uloge pobjeđuje izbor čipa', () {
    test(
      'izbor kolege ostao od vlasnika ne filtrira radnikovu sedmicu',
      () async {
        final (:container, :termini, blokade: _) = _kontejner(
          radnikIzUloge: 'e1',
        );
        // Vlasnik je na istom uređaju izabrao Vedada, pa se odjavio.
        container.read(izabraniRadnikProvider.notifier).postavi('e2');

        final sedmica = await container.read(kalendarSedmicaProvider.future);

        expect(termini.pozivi.single.employeeId, 'e1');
        final svi = [
          for (final d in sedmica.dani)
            ...d.kolona.termini.map((s) => s.termin!.id),
        ];
        expect(svi, ['emir']);
        expect(sedmica.radnici.map((r) => r.id), ['e1']);
      },
    );

    test('vlasnikov čip filtrira u Dartu, bez novog upita', () async {
      final (:container, :termini, blokade: _) = _kontejner();
      await container.read(kalendarSedmicaProvider.future);

      container.read(izabraniRadnikProvider.notifier).postavi('e2');
      final sedmica = await container.read(kalendarSedmicaProvider.future);

      expect(termini.pozivi, hasLength(1));
      expect(termini.pozivi.single.employeeId, isNull);
      expect(sedmica.brojTermina, 1);
      expect(sedmica.radnici, hasLength(2), reason: 'čipovi ostaju svi');
    });
  });

  test('sedmica čeka radnike — ne crta termine bez boje i imena', () async {
    final radnici = Completer<List<Employee>>();
    final (:container, termini: _, blokade: _) = _kontejner(
      radnici: radnici.future,
    );

    await pumpEventQueue();
    expect(container.read(kalendarSedmicaProvider).isLoading, isTrue);

    radnici.complete(_radnici);
    final sedmica = await container.read(kalendarSedmicaProvider.future);
    expect(sedmica.boje.keys, containsAll(['e1', 'e2']));
  });
}
