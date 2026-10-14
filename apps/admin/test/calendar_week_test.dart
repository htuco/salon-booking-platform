/// Model sedmice kalendara (task 69) — bez widgeta.
///
/// Isto pravilo kao `calendar_day_test.dart`: **nigdje nema `DateTime.now()`**. Sedmica je
/// fiksirana na 18.–24. maj 2026., a „sada" se prosljeđuje.
library;

import 'package:admin/src/features/calendar/calendar_day.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Ponedjeljak, 18. maj 2026.
final _ponedjeljak = DateTime(2026, 5, 18);

Appointment _termin({
  required DateTime dan,
  required int od,
  required int doMinuta,
  String id = 'a1',
  String? radnik = 'e1',
  AppointmentStatus status = AppointmentStatus.confirmed,
}) => Appointment(
  id: id,
  salonId: _salonId,
  serviceId: 's1',
  employeeId: radnik,
  customerId: 'c1',
  customerName: 'Klijent',
  date: LocalDate(dan.year, dan.month, dan.day),
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
  status: status,
);

WorkingHour _raspored({
  required int dan,
  String? radnik,
  int od = 9 * 60,
  int doMinuta = 17 * 60,
  bool zatvoreno = false,
}) => WorkingHour(
  id: 'wh-$dan-$radnik',
  salonId: _salonId,
  employeeId: radnik,
  dayOfWeek: dan,
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
  isClosed: zatvoreno,
);

BlockedSlot _blokada({
  required DateTime dan,
  required int od,
  required int doMinuta,
  String id = 'b1',
  String? radnik,
}) => BlockedSlot(
  id: id,
  salonId: _salonId,
  employeeId: radnik,
  date: LocalDate(dan.year, dan.month, dan.day),
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
);

/// Salon radi pon–sub 09–17, nedjelja zatvorena.
final _salon = [
  for (var d = 1; d <= 6; d++) _raspored(dan: d),
  _raspored(dan: 7, zatvoreno: true),
];

DateTime _dan(int pomak) =>
    DateTime(_ponedjeljak.year, _ponedjeljak.month, _ponedjeljak.day + pomak);

void main() {
  group('pocetakSedmice', () {
    test('svaki dan sedmice vodi na isti ponedjeljak', () {
      for (var i = 0; i < 7; i++) {
        expect(pocetakSedmice(_dan(i)), _ponedjeljak, reason: 'dan +$i');
      }
    });

    test('nedjelja pripada sedmici koja je počela prije nje, ne sljedećoj', () {
      expect(pocetakSedmice(DateTime(2026, 5, 24)), _ponedjeljak);
      expect(pocetakSedmice(DateTime(2026, 5, 25)), DateTime(2026, 5, 25));
    });

    test('promjena ljetnog vremena ne pomjera ponedjeljak', () {
      // Zadnja nedjelja oktobra 2026. je 25.; sedmica počinje 19. oktobra u ponoć.
      final p = pocetakSedmice(DateTime(2026, 10, 25));
      expect((p.year, p.month, p.day, p.hour), (2026, 10, 19, 0));
    });

    test('sedmica preko kraja mjeseca', () {
      // Nedjelja 31. maj → ponedjeljak 25. maj; utorak 2. jun → ponedjeljak 1. jun.
      expect(pocetakSedmice(DateTime(2026, 5, 31)), DateTime(2026, 5, 25));
      expect(pocetakSedmice(DateTime(2026, 6, 2)), DateTime(2026, 6, 1));
    });
  });

  group('izgradiSedmicu', () {
    test('sedam dana, ponedjeljak prvi, iz bilo kojeg dana sedmice', () {
      final sedmica = izgradiSedmicu(
        dan: _dan(3),
        termini: const [],
        radnoVrijeme: _salon,
        blokade: const [],
      );

      expect(sedmica.dani, hasLength(7));
      expect(sedmica.pocetak, _ponedjeljak);
      expect(sedmica.kraj, DateTime(2026, 5, 24));
    });

    test('termin ide u kolonu svog datuma, svi radnici u istoj koloni', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: [
          _termin(dan: _dan(0), od: 10 * 60, doMinuta: 11 * 60, id: 'pon-e1'),
          _termin(
            dan: _dan(0),
            od: 10 * 60,
            doMinuta: 11 * 60,
            id: 'pon-e2',
            radnik: 'e2',
          ),
          _termin(dan: _dan(2), od: 12 * 60, doMinuta: 13 * 60, id: 'sri'),
        ],
        radnoVrijeme: _salon,
        blokade: const [],
      );

      final pon = sedmica.dani[0].kolona.termini.map((s) => s.termin!.id);
      expect(pon, unorderedEquals(['pon-e1', 'pon-e2']));
      expect(sedmica.dani[2].kolona.termini.single.termin!.id, 'sri');
      expect(sedmica.brojTermina, 3);
    });

    test(
      'dva radnika u isto vrijeme dobiju dvije trake, ne jedan preko drugog',
      () {
        final sedmica = izgradiSedmicu(
          dan: _ponedjeljak,
          termini: [
            _termin(dan: _dan(0), od: 10 * 60, doMinuta: 11 * 60, id: 'a'),
            _termin(
              dan: _dan(0),
              od: 10 * 60 + 30,
              doMinuta: 11 * 60 + 30,
              id: 'b',
              radnik: 'e2',
            ),
          ],
          radnoVrijeme: _salon,
          blokade: const [],
        );

        final trake = sedmica.dani[0].kolona.termini.toList();
        expect(trake.map((s) => s.brojTraka), [2, 2]);
        expect(trake.map((s) => s.traka).toSet(), {0, 1});
      },
    );

    test('termin izvan sedmice se ne crta nigdje', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: [
          _termin(dan: DateTime(2026, 5, 25), od: 600, doMinuta: 660),
          _termin(dan: DateTime(2026, 5, 17), od: 600, doMinuta: 660, id: 'a2'),
        ],
        radnoVrijeme: _salon,
        blokade: const [],
      );

      expect(sedmica.brojTermina, 0);
    });

    test(
      'jedna osa za sve dane: od najranijeg početka do najkasnijeg kraja',
      () {
        final sedmica = izgradiSedmicu(
          dan: _ponedjeljak,
          termini: [
            // Subota u 18:00 je van radnog vremena — osa ga mora obuhvatiti.
            _termin(dan: _dan(5), od: 18 * 60, doMinuta: 18 * 60 + 30),
          ],
          radnoVrijeme: [
            _raspored(dan: 1, od: 8 * 60),
            for (var d = 2; d <= 6; d++) _raspored(dan: d),
            _raspored(dan: 7, zatvoreno: true),
          ],
          blokade: const [],
        );

        expect(sedmica.osa.pocetakMinuta, 8 * 60);
        expect(sedmica.osa.krajMinuta, 19 * 60);
      },
    );

    test('neradni dan je cijela kolona „Ne radi"', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: const [],
        radnoVrijeme: _salon,
        blokade: const [],
      );

      final nedjelja = sedmica.dani[6];
      expect(nedjelja.radi, isFalse);
      expect(nedjelja.podnaslov, 'Ne radi');
      final pojas = nedjelja.kolona.pozadina.single;
      expect(pojas.vrsta, VrstaStavke.neradno);
      expect(
        (pojas.odMinuta, pojas.doMinuta),
        (sedmica.osa.pocetakMinuta, sedmica.osa.krajMinuta),
      );
    });

    test('dan bez reda u working_hours je neradan, ne prazan radni', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: const [],
        radnoVrijeme: [_raspored(dan: 1)],
        blokade: const [],
      );

      expect(sedmica.dani.map((d) => d.radi), [
        true,
        false,
        false,
        false,
        false,
        false,
        false,
      ]);
    });

    test('salonska blokada ulazi u kolonu svog dana', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: const [],
        radnoVrijeme: _salon,
        blokade: [_blokada(dan: _dan(2), od: 12 * 60, doMinuta: 13 * 60)],
      );

      final blokade = [
        for (final d in sedmica.dani)
          d.kolona.pozadina.where((s) => s.vrsta == VrstaStavke.blokada).length,
      ];
      expect(blokade, [0, 0, 1, 0, 0, 0, 0]);
    });

    test('radnikova blokada sa „Svi" se ne crta — salon nije zatvoren', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: const [],
        radnoVrijeme: _salon,
        blokade: [
          _blokada(dan: _dan(1), od: 12 * 60, doMinuta: 13 * 60, radnik: 'e1'),
        ],
      );

      expect(
        sedmica.dani[1].kolona.pozadina.where(
          (s) => s.vrsta == VrstaStavke.blokada,
        ),
        isEmpty,
      );
    });
  });

  group('filter po radniku', () {
    final termini = [
      _termin(dan: _dan(0), od: 600, doMinuta: 660, id: 'emir'),
      _termin(dan: _dan(0), od: 600, doMinuta: 660, id: 'vedad', radnik: 'e2'),
      _termin(dan: _dan(1), od: 600, doMinuta: 660, id: 'bez', radnik: null),
    ];

    test('filtriran radnik vidi samo svoje termine, u svim danima', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: termini,
        radnoVrijeme: _salon,
        blokade: const [],
        radnikId: 'e1',
      );

      final svi = [
        for (final d in sedmica.dani)
          ...d.kolona.termini.map((s) => s.termin!.id),
      ];
      expect(svi, ['emir']);
    });

    test('„Svi" ne gubi termin bez radnika', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: termini,
        radnoVrijeme: _salon,
        blokade: const [],
      );

      expect(sedmica.brojTermina, 3);
    });

    test('filtriran radnik dobija svoju smjenu i svoju blokadu', () {
      final sedmica = izgradiSedmicu(
        dan: _ponedjeljak,
        termini: const [],
        radnoVrijeme: [
          ..._salon,
          // Emir u utorak ne radi, iako salon radi.
          _raspored(dan: 2, radnik: 'e1', zatvoreno: true),
        ],
        blokade: [
          _blokada(dan: _dan(3), od: 12 * 60, doMinuta: 13 * 60, radnik: 'e1'),
          _blokada(
            dan: _dan(3),
            od: 14 * 60,
            doMinuta: 15 * 60,
            id: 'b2',
            radnik: 'e2',
          ),
        ],
        radnikId: 'e1',
      );

      expect(sedmica.dani[1].radi, isFalse);
      expect(sedmica.dani[0].radi, isTrue);
      final cetvrtak = sedmica.dani[3].kolona.pozadina
          .where((s) => s.vrsta == VrstaStavke.blokada)
          .map((s) => s.id);
      expect(cetvrtak, ['b1']);
    });
  });

  group('linija „sada"', () {
    final sedmica = izgradiSedmicu(
      dan: _ponedjeljak,
      termini: const [],
      radnoVrijeme: _salon,
      blokade: const [],
    );

    test('stoji samo u današnjoj koloni', () {
      final sada = DateTime(2026, 5, 20, 13);
      expect(sedmica.indeksDana(sada), 2);
      expect(sedmica.yLinijeSada(sada), sedmica.osa.yZa(13 * 60));
    });

    test('druga sedmica nema liniju', () {
      final sada = DateTime(2026, 5, 26, 13);
      expect(sedmica.indeksDana(sada), isNull);
      expect(sedmica.yLinijeSada(sada), isNull);
    });

    test('prije otvaranja nema liniju', () {
      expect(sedmica.yLinijeSada(DateTime(2026, 5, 20, 7)), isNull);
    });
  });

  test('telefon: lista po danima bez neradnih pojaseva', () {
    final sedmica = izgradiSedmicu(
      dan: _ponedjeljak,
      termini: [
        _termin(dan: _dan(0), od: 11 * 60, doMinuta: 12 * 60, id: 'kasniji'),
        _termin(dan: _dan(0), od: 9 * 60, doMinuta: 10 * 60, id: 'raniji'),
      ],
      radnoVrijeme: _salon,
      blokade: const [],
    );

    final redovi = redoviSedmice(sedmica);
    expect(redovi, hasLength(7));
    expect(redovi.first.$2.map((s) => s.termin!.id), ['raniji', 'kasniji']);
    expect(
      redovi.last.$2,
      isEmpty,
      reason: 'nedjelja: „Ne radi" nije red liste',
    );
  });
}
