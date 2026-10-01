/// Čiste funkcije Danas ekrana (`danas.dart`) — bez widgeta.
///
/// Sat je fiksan (13:12, kao u handoffu `6a`); funkcija koja čita `DateTime.now()` bi
/// prolazila samo u određeno doba dana.
library;

import 'package:admin/src/features/dashboard/danas.dart';
import 'package:admin/src/features/dashboard/dashboard_summary.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

final _sada = DateTime(2026, 5, 18, 13, 12);
final _danas = LocalDate(2026, 5, 18);

Appointment _t(
  String ime,
  int od,
  int odMin,
  int doSat,
  int doMin, {
  AppointmentStatus status = AppointmentStatus.confirmed,
  String? radnik = 'e1',
  LocalDate? dan,
  DateTime? poslan,
  String usluga = 's1',
}) => Appointment(
  id: ime,
  salonId: 's',
  serviceId: usluga,
  employeeId: radnik,
  customerId: 'c-$ime',
  customerName: ime,
  date: dan ?? _danas,
  startTime: LocalTime(od, odMin),
  endTime: LocalTime(doSat, doMin),
  status: status,
  createdAt: poslan,
);

void main() {
  group('zahtjevi', () {
    test('po vremenu termina, danas prije sutra — ne po čekanju', () {
      final sutraRano = _t(
        'Nermin',
        9,
        30,
        9,
        50,
        status: AppointmentStatus.pending,
        dan: LocalDate(2026, 5, 19),
        poslan: _sada.subtract(const Duration(hours: 2)),
      );
      final danasKasno = _t(
        'Ismar',
        18,
        0,
        18,
        30,
        status: AppointmentStatus.pending,
        poslan: _sada.subtract(const Duration(minutes: 5)),
      );
      final danasRano = _t(
        'Nedim',
        15,
        0,
        15,
        40,
        status: AppointmentStatus.pending,
      );

      expect(
        zahtjeviPoTerminu([sutraRano, danasKasno, danasRano]).map((t) => t.id),
        ['Nedim', 'Ismar', 'Nermin'],
      );
    });

    test('dan zahtjeva: danas, sutra, ime dana, pa datum', () {
      expect(danZahtjeva(_danas, _sada), 'danas');
      expect(danZahtjeva(LocalDate(2026, 5, 19), _sada), 'sutra');
      expect(danZahtjeva(LocalDate(2026, 5, 20), _sada), 'srijeda');
      expect(danZahtjeva(LocalDate(2026, 5, 29), _sada), '29.05.');
    });

    test('čekanje se piše u minutama, satima i danima', () {
      expect(trajanjeCekanja(const Duration(minutes: 26)), '26 min');
      expect(trajanjeCekanja(const Duration(minutes: 100)), '1 h 40 min');
      expect(trajanjeCekanja(const Duration(hours: 3)), '3 h');
      expect(trajanjeCekanja(const Duration(days: 2, hours: 1)), '2 dana');
      expect(cekaKoliko(null, _sada), isNull);
    });
  });

  group('Sljedeći, U toku i „je li došao?"', () {
    final dan = [
      _t('Edin', 11, 20, 11, 50),
      _t('Tarik', 12, 40, 13, 20),
      _t('Nedim', 13, 20, 13, 40, status: AppointmentStatus.pending),
      _t('Haris', 13, 30, 14, 0),
      _t('Kemal', 11, 0, 11, 40, status: AppointmentStatus.completed),
    ];

    test('Sljedeći je prvi potvrđen koji tek počinje — zahtjev to nije', () {
      expect(sljedeciTermin(dan, _sada)?.id, 'Haris');
      expect(zaKoliko(sljedeciTermin(dan, _sada)!, _sada), 'za 18 min');
    });

    test('U toku je potvrđen termin kroz koji prolazi sat', () {
      expect(uTokuSada(dan, _sada).map((t) => t.id), ['Tarik']);
    });

    test('bez oznake: potvrđen, a vrijeme mu je prošlo', () {
      expect(bezOznake(dan, _sada).map((t) => t.id), ['Edin']);
    });
  });

  group('stavke dana', () {
    test('linija „Sad" stoji između prošlog i budućeg', () {
      final stavke = stavkeDana(
        termini: [_t('A', 11, 0, 11, 40), _t('B', 14, 0, 14, 30)],
        sada: _sada,
      );
      expect(stavke.map((s) => s.runtimeType), [
        TerminStavka,
        SadStavka,
        TerminStavka,
      ]);
    });

    test('bez linije kad su svi termini prošli', () {
      final stavke = stavkeDana(termini: [_t('A', 9, 0, 9, 30)], sada: _sada);
      expect(stavke.whereType<SadStavka>(), isEmpty);
    });

    test('radnikova smjena daje rupe i pauzu, samo od sada nadalje', () {
      const smjena = SmjenaDana(
        radnikId: 'e1',
        od: 10 * 60,
        doMinute: 19 * 60,
        pauzaOd: 14 * 60,
        pauzaDo: 14 * 60 + 30,
      );
      final stavke = stavkeDana(
        termini: [_t('Tarik', 12, 40, 13, 20), _t('Faruk', 14, 30, 15, 15)],
        sada: _sada,
        smjena: smjena,
      );

      final slobodno = stavke.whereType<SlobodnoStavka>().toList();
      // 13:20–14:00 prije pauze, pa od 15:15 do kraja smjene. Rupa prije 13:12 se ne crta.
      expect(slobodno.map((s) => (hhmm(s.od), hhmm(s.doMinute))), [
        ('13:20', '14:00'),
        ('15:15', '19:00'),
      ]);
      expect(stavke.whereType<PauzaStavka>().single.minuta, 30);
    });

    test('rupa kraća od 15 min nije „slobodno"', () {
      const smjena = SmjenaDana(radnikId: 'e1', od: 13 * 60, doMinute: 15 * 60);
      final stavke = stavkeDana(
        termini: [_t('A', 13, 20, 14, 0), _t('B', 14, 10, 15, 0)],
        sada: _sada,
        smjena: smjena,
      );
      expect(stavke.whereType<SlobodnoStavka>(), isEmpty);
    });
  });

  group('brojke', () {
    test('naplaćeno, prognoza i dio koji čeka potvrdu', () {
      final b = BrojkeDana.izracunaj(
        [
          _t('A', 9, 0, 9, 40, status: AppointmentStatus.completed),
          _t('B', 10, 0, 10, 40),
          _t('C', 11, 0, 11, 40, status: AppointmentStatus.pending),
          _t('D', 12, 0, 12, 40, status: AppointmentStatus.noShow),
          _t('E', 12, 0, 12, 40, status: AppointmentStatus.cancelled),
        ],
        {'s1': 20},
      );
      expect(b.naplaceno, 20);
      expect(b.prognoza, 60);
      expect(b.naCekanjuIznos, 20);
      expect(b.termina, 3);
      expect(b.nijeDoslo, 1);
      expect(b.otkazano, 1);
    });

    test('tekst sa brojem prati padež', () {
      expect(josRanijih(1), 'Još 1 raniji termin');
      expect(josRanijih(3), 'Još 3 ranija termina');
      expect(josRanijih(12), 'Još 12 ranijih termina');
      expect(zahtjevaTekst(2), '2 zahtjeva');
      expect(zahtjevaTekst(21), '21 zahtjev');
      expect(zavrsenihTekst(3), '3 završena termina');
    });
  });

  group('sljedeći radni dan', () {
    List<WorkingHour> raspored({required Set<int> zatvoreno}) => [
      for (var d = 1; d <= 7; d++)
        WorkingHour(
          id: 'wh-$d',
          salonId: 's',
          dayOfWeek: d,
          startTime: const LocalTime(9, 0),
          endTime: const LocalTime(20, 0),
          isClosed: zatvoreno.contains(d),
        ),
    ];

    test('nedjelja zatvorena — sljedeći je ponedjeljak', () {
      final nedjelja = DateTime(2026, 5, 17);
      final s = sljedeciRadniDan(raspored(zatvoreno: {7}), nedjelja);
      expect(s?.dan, DateTime(2026, 5, 18));
      expect(s?.otvara, const LocalTime(9, 0));
      expect(salonRadi(raspored(zatvoreno: {7}), nedjelja), isFalse);
    });

    test('salon koji ne radi nijedan dan nema sljedeći radni dan', () {
      expect(
        sljedeciRadniDan(raspored(zatvoreno: {1, 2, 3, 4, 5, 6, 7}), _sada),
        isNull,
      );
    });
  });

  group('provjera zahtjeva', () {
    test('slobodan, sa susjedima istog radnika', () {
      final zahtjev = _t(
        'Nedim',
        15,
        0,
        15,
        40,
        status: AppointmentStatus.pending,
      );
      final p = provjeriZahtjev(zahtjev, [
        zahtjev,
        _t('Jasmin', 13, 0, 13, 30),
        _t('Almir', 17, 0, 17, 30, status: AppointmentStatus.pending),
        _t('Drugi radnik', 15, 0, 15, 30, radnik: 'e2'),
      ], _sada);
      expect(p, isA<SlobodanTermin>());
      p as SlobodanTermin;
      expect(p.prije?.id, 'Jasmin');
      expect(p.poslije?.id, 'Almir');
    });

    test('pada preko potvrđenog termina', () {
      final zahtjev = _t(
        'Nedim',
        15,
        0,
        15,
        40,
        status: AppointmentStatus.pending,
      );
      final p = provjeriZahtjev(zahtjev, [_t('Haris', 15, 20, 16, 0)], _sada);
      expect(p, isA<ZauzetTermin>());
      expect((p as ZauzetTermin).sa?.id, 'Haris');
    });

    test('pada u pauzu iz smjene', () {
      final zahtjev = _t(
        'Nedim',
        14,
        0,
        14,
        30,
        status: AppointmentStatus.pending,
      );
      final p = provjeriZahtjev(
        zahtjev,
        const [],
        _sada,
        smjena: const SmjenaDana(
          radnikId: 'e1',
          od: 600,
          doMinute: 1140,
          pauzaOd: 14 * 60,
          pauzaDo: 14 * 60 + 30,
        ),
      );
      expect(p, isA<ZauzetTermin>());
      expect((p as ZauzetTermin).pauza, isTrue);
    });

    test('za drugi dan i za „bilo ko" nema provjere', () {
      expect(
        provjeriZahtjev(
          _t('X', 10, 0, 10, 30, dan: LocalDate(2026, 5, 19)),
          const [],
          _sada,
        ),
        isNull,
      );
      expect(
        provjeriZahtjev(_t('Y', 15, 0, 15, 30, radnik: null), const [], _sada),
        isNull,
      );
    });
  });
}
