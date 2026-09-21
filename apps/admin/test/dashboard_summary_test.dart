/// Brojke sa „Danas" — bez widgeta.
///
/// Metrika koja pogrešno broji izgleda na ekranu tačno kao metrika koja broji ispravno;
/// jedino mjesto gdje se ta razlika vidi je test nad čistom funkcijom.
library;

import 'package:admin/src/features/dashboard/dashboard_summary.dart';
import 'package:admin/src/core/format/tekst.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

Appointment _termin({
  required AppointmentStatus status,
  String usluga = 's1',
  String? radnik,
  int sat = 10,
  int trajanje = 40,
  double? cijena,
}) => Appointment(
  id: 'a-$status-$sat-$radnik',
  salonId: _salonId,
  serviceId: usluga,
  servicePrice: cijena,
  employeeId: radnik,
  customerId: 'c1',
  customerName: 'Klijent',
  date: LocalDate(2026, 9, 14),
  startTime: LocalTime(sat, 0),
  endTime: LocalTime(sat + (trajanje ~/ 60), trajanje % 60),
  status: status,
);

const _cijene = {'s1': 20.0, 's2': 15.0};

void main() {
  group('sažetak dana', () {
    test('broji samo termine koji drže slot', () {
      final sazetak = DashboardSazetak.izracunaj([
        _termin(status: AppointmentStatus.completed),
        _termin(status: AppointmentStatus.confirmed, sat: 11),
        _termin(status: AppointmentStatus.pending, sat: 12),
        _termin(status: AppointmentStatus.cancelled, sat: 13),
        _termin(status: AppointmentStatus.noShow, sat: 14),
      ], _cijene);

      // Otkazan termin i nedolazak **nisu** termini dana: slot je prošao prazan.
      expect(sazetak.ukupno, 3);
      expect(sazetak.zavrseno, 1);
      expect(sazetak.predstoji, 2);
      expect(sazetak.otkazano, 2);
    });

    test(
      'promet do sada je samo završeno, prognoza je i ono što predstoji',
      () {
        final sazetak = DashboardSazetak.izracunaj([
          _termin(status: AppointmentStatus.completed),
          _termin(status: AppointmentStatus.confirmed, usluga: 's2', sat: 11),
          // Otkazan termin ne ulazi ni u prognozu — slot je slobodan.
          _termin(status: AppointmentStatus.cancelled, sat: 12),
        ], _cijene);

        expect(sazetak.prometDoSada, 20);
        expect(sazetak.prometPrognoza, 35);
      },
    );

    test('usluga koje nema u cjenovniku ne briše termin iz rasporeda', () {
      // Salon smije obrisati uslugu koja je već rezervisana. Termin tada ostaje, ali se ne
      // može naplatiti po cjenovniku — brojanje i promet se zato razilaze namjerno.
      final sazetak = DashboardSazetak.izracunaj([
        _termin(status: AppointmentStatus.completed, usluga: 'obrisana'),
      ], _cijene);

      expect(sazetak.ukupno, 1);
      expect(sazetak.zavrseno, 1);
      expect(sazetak.prometDoSada, 0);
    });

    test('snapshot cijena ima prednost nad izmijenjenim cjenovnikom', () {
      final sazetak = DashboardSazetak.izracunaj(
        [_termin(status: AppointmentStatus.completed, cijena: 20)],
        const {'s1': 35.0},
      );

      expect(sazetak.prometDoSada, 20);
      expect(sazetak.prometPrognoza, 20);
    });
  });

  group('zauzetost majstora', () {
    test('sabira minute i sortira najzauzetijeg prvog', () {
      final zauzetost = zauzetostPoRadniku(
        [
          _termin(
            status: AppointmentStatus.confirmed,
            radnik: 'e1',
            trajanje: 40,
          ),
          _termin(
            status: AppointmentStatus.completed,
            radnik: 'e1',
            sat: 11,
            trajanje: 20,
          ),
          _termin(
            status: AppointmentStatus.confirmed,
            radnik: 'e2',
            sat: 12,
            trajanje: 45,
          ),
        ],
        {'e1': 'Emir', 'e2': 'Vedad'},
      );

      expect(zauzetost.map((z) => z.ime), ['Emir', 'Vedad']);
      expect(zauzetost.first.termina, 2);
      expect(zauzetost.first.minuta, 60);
      expect(zauzetost.last.minuta, 45);
    });

    test('završen termin se i dalje broji radniku', () {
      // `status.blocksSlot` je `false` za završen termin — slot više ne drži. Ali posao je
      // obavljen, i majstor koji je danas odradio šest termina ne smije izgledati prazno
      // samo zato što su svi gotovi.
      final zauzetost = zauzetostPoRadniku(
        [
          _termin(
            status: AppointmentStatus.completed,
            radnik: 'e1',
            trajanje: 40,
          ),
        ],
        {'e1': 'Emir'},
      );

      expect(zauzetost.single.termina, 1);
      expect(zauzetost.single.minuta, 40);
    });

    test('otkazan termin ne opterećuje radnika', () {
      final zauzetost = zauzetostPoRadniku(
        [_termin(status: AppointmentStatus.cancelled, radnik: 'e1')],
        {'e1': 'Emir'},
      );

      expect(zauzetost, isEmpty);
    });

    test('termin bez radnika se ne pripisuje nikome', () {
      // `employee_id` je nullable: klijent je izabrao „bilo ko". Takav red se vidi u
      // rasporedu, a ne u zauzetosti — pripisati ga prvom radniku bi bila izmišljotina.
      final zauzetost = zauzetostPoRadniku(
        [_termin(status: AppointmentStatus.confirmed)],
        {'e1': 'Emir'},
      );

      expect(zauzetost, isEmpty);
    });

    test('radnik kojeg nema u katalogu ne ruši listu', () {
      final zauzetost = zauzetostPoRadniku([
        _termin(status: AppointmentStatus.confirmed, radnik: 'nepoznat'),
      ], const {});

      expect(zauzetost.single.ime, 'Radnik');
    });
  });

  group('formatiranje', () {
    test('trajanje se piše kako ga canvas piše', () {
      expect(trajanjeKratko(160), '2h 40m');
      expect(trajanjeKratko(45), '45m');
      expect(trajanjeKratko(120), '2h');
      expect(trajanjeKratko(0), '0m');
    });

    test('iznos nosi decimale samo kad ih stvarno ima', () {
      expect(iznosKm(265), '265 KM');
      expect(iznosKm(12.5), '12.50 KM');
      // Zaokruživanje bi u izvještaju o prometu bilo tiha greška.
      expect(iznosKm(12.5), isNot('13 KM'));
    });
  });
}
