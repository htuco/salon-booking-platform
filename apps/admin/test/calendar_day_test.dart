/// Model dana kalendara — bez widgeta.
///
/// Blok koji je na pogrešnom mjestu na osi izgleda tačno kao blok koji je na pravom, pa je
/// ovo jedino mjesto gdje se ta razlika stvarno vidi.
///
/// **Nigdje u ovom fajlu nema `DateTime.now()`.** Dan je fiksiran na ponedjeljak
/// 18. maj 2026. (ISO `weekday == 1`), a „sada" se svugdje prosljeđuje. Task 17 je našao
/// tri zatečena testa koja su bila zelena samo poslije 09:30 ili samo ponedjeljkom;
/// kalendar je najgore mjesto za tu grešku, jer bi pala tek u ponedjeljak ujutro.
library;

import 'package:admin/src/features/calendar/calendar_day.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Ponedjeljak, 18. maj 2026. Isti dan koji crta canvas `3c`.
final _ponedjeljak = DateTime(2026, 5, 18);

/// Nedjelja, 17. maj 2026. — u seedu neradni dan.
final _nedjelja = DateTime(2026, 5, 17);

Employee _radnik(String id, String ime) =>
    Employee(id: id, salonId: _salonId, name: ime);

Appointment _termin({
  required int od,
  required int doMinuta,
  String id = 'a1',
  String? radnik = 'e1',
  AppointmentStatus status = AppointmentStatus.confirmed,
  DateTime? dan,
}) {
  final datum = dan ?? _ponedjeljak;
  return Appointment(
    id: id,
    salonId: _salonId,
    serviceId: 's1',
    employeeId: radnik,
    customerId: 'c1',
    customerName: 'Klijent',
    date: LocalDate(datum.year, datum.month, datum.day),
    startTime: LocalTime(od ~/ 60, od % 60),
    endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
    status: status,
  );
}

WorkingHour _raspored({
  int dan = 1,
  String? radnik,
  int od = 9 * 60,
  int doMinuta = 17 * 60,
  int? pauzaOd,
  int? pauzaDo,
  bool zatvoreno = false,
}) => WorkingHour(
  id: 'wh-$dan-$radnik',
  salonId: _salonId,
  employeeId: radnik,
  dayOfWeek: dan,
  startTime: LocalTime(od ~/ 60, od % 60),
  endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
  breakStartTime: pauzaOd == null
      ? null
      : LocalTime(pauzaOd ~/ 60, pauzaOd % 60),
  breakEndTime: pauzaDo == null ? null : LocalTime(pauzaDo ~/ 60, pauzaDo % 60),
  isClosed: zatvoreno,
);

BlockedSlot _blokada({
  required int od,
  required int doMinuta,
  String? radnik,
  String? razlog,
  DateTime? dan,
}) {
  final datum = dan ?? _ponedjeljak;
  return BlockedSlot(
    id: 'b-$od-$radnik',
    salonId: _salonId,
    employeeId: radnik,
    date: LocalDate(datum.year, datum.month, datum.day),
    startTime: LocalTime(od ~/ 60, od % 60),
    endTime: LocalTime(doMinuta ~/ 60, doMinuta % 60),
    reason: razlog,
  );
}

KalendarDan _dan({
  DateTime? dan,
  List<Employee> radnici = const [],
  List<Appointment> termini = const [],
  List<WorkingHour> radnoVrijeme = const [],
  List<BlockedSlot> blokade = const [],
}) => izgradiDan(
  dan: dan ?? _ponedjeljak,
  radnici: radnici,
  termini: termini,
  radnoVrijeme: radnoVrijeme,
  blokade: blokade,
);

KolonaRadnika _kolona(KalendarDan dan, String ime) =>
    dan.kolone.firstWhere((k) => k.ime == ime);

void main() {
  group('osa', () {
    test('ide od punog sata prije prvog do punog sata poslije zadnjeg', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored()],
      );

      expect(dan.osa.pocetakMinuta, 9 * 60);
      expect(dan.osa.krajMinuta, 17 * 60);
      expect(dan.osa.sati.first, 9 * 60);
      expect(dan.osa.sati.last, 16 * 60);
    });

    test('termin van radnog vremena razvlači osu umjesto da nestane', () {
      // Ručni unos smije upisati termin izvan smjene. Osa koja staje na radnom vremenu bi
      // ga gurnula van vidnog polja, a jedini trag bi bio da brojka ne odgovara ekranu.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 19 * 60 + 20, doMinuta: 20 * 60)],
        radnoVrijeme: [_raspored()],
      );

      expect(dan.osa.krajMinuta, 20 * 60);
      expect(_kolona(dan, 'Emir').termini, hasLength(1));
    });

    test('zaokružuje na pun sat u oba smjera', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 8 * 60 + 40, doMinuta: 9 * 60 + 20)],
      );

      expect(dan.osa.pocetakMinuta, 8 * 60);
      expect(dan.osa.krajMinuta, 10 * 60);
    });

    test('dan bez ičega dobija podrazumijevani prozor, ne 09–17 iz baze', () {
      // `working_hours` default (`09:00–17:00`) stoji i u redu koji kaže `is_closed`.
      // Čitanje tih vrijednosti kao rasporeda bi zatvorenoj nedjelji nacrtalo radni dan.
      final dan = _dan(
        dan: _nedjelja,
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(dan: 7, zatvoreno: true)],
      );

      expect(dan.osa.pocetakMinuta, kPodrazumijevanPocetak);
      expect(dan.osa.krajMinuta, kPodrazumijevanKraj);
    });

    test('blokada sama razvlači osu, i kad nema nijednog termina', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        blokade: [_blokada(od: 6 * 60, doMinuta: 8 * 60)],
      );

      expect(dan.osa.pocetakMinuta, 6 * 60);
    });

    test('y i visina prate 80 px po satu', () {
      const osa = KalendarOsa(pocetakMinuta: 9 * 60, krajMinuta: 17 * 60);

      expect(osa.yZa(9 * 60), 0);
      expect(osa.yZa(10 * 60), kVisinaSata);
      expect(osa.yZa(9 * 60 + 30), kVisinaSata / 2);
      expect(osa.visinaZa(11 * 60, 12 * 60 + 20), closeTo(106.67, 0.01));
      expect(osa.visina, 8 * kVisinaSata);
    });
  });

  group('kolone', () {
    test(
      'svaki radnik dobija kolonu, i onaj koji danas nema nijedan termin',
      () {
        // Kolona koja se pojavljuje i nestaje zavisno od rasporeda je nečitljiva, a „Emir je
        // danas slobodan" je informacija koju vlasnik traži.
        final dan = _dan(
          radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Vedad')],
          termini: [_termin(od: 10 * 60, doMinuta: 11 * 60)],
          radnoVrijeme: [_raspored()],
        );

        expect(dan.kolone.map((k) => k.ime), ['Emir', 'Vedad']);
        expect(_kolona(dan, 'Vedad').termini, isEmpty);
      },
    );

    test('termin bez radnika ne nestaje nego dobija svoju kolonu', () {
      // `appointments.employee_id` je nullable — salon smije pustiti „bilo ko".
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 10 * 60, doMinuta: 11 * 60, radnik: null)],
        radnoVrijeme: [_raspored()],
      );

      expect(dan.kolone.map((k) => k.ime), ['Emir', kBezRadnikaIme]);
      expect(_kolona(dan, kBezRadnikaIme).termini, hasLength(1));
      expect(_kolona(dan, 'Emir').termini, isEmpty);
    });

    test('termin nepoznatog radnika ide u istu kolonu, ne u nijednu', () {
      // Obrisan radnik ili lista koja se još učitava. Termin koji tiho ispadne iz
      // rasporeda je gori od kolone viška.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 10 * 60, doMinuta: 11 * 60, radnik: 'e9')],
        radnoVrijeme: [_raspored()],
      );

      expect(_kolona(dan, kBezRadnikaIme).termini, hasLength(1));
      expect(dan.brojTermina, 1);
    });

    test('kolona „Bez radnika" postoji samo kad ima šta u njoj', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 10 * 60, doMinuta: 11 * 60)],
        radnoVrijeme: [_raspored()],
      );

      expect(dan.kolone.map((k) => k.ime), ['Emir']);
    });

    test('radnikov raspored nadjačava salonski', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        radnoVrijeme: [
          _raspored(),
          _raspored(radnik: 'e2', od: 12 * 60, doMinuta: 20 * 60),
        ],
      );

      expect(_kolona(dan, 'Emir').podnaslov, startsWith('09:00–17:00'));
      expect(_kolona(dan, 'Amar').podnaslov, startsWith('12:00–20:00'));
    });

    test('podnaslov broji termine kao dan, ne kao slotove', () {
      // Isto pravilo kao na dashboardu: završen termin se ujutro **desio**, otkazan nije.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 9 * 60, doMinuta: 10 * 60, id: 'a1'),
          _termin(
            od: 10 * 60,
            doMinuta: 11 * 60,
            id: 'a2',
            status: AppointmentStatus.completed,
          ),
          _termin(
            od: 11 * 60,
            doMinuta: 12 * 60,
            id: 'a3',
            status: AppointmentStatus.cancelled,
          ),
          _termin(
            od: 12 * 60,
            doMinuta: 13 * 60,
            id: 'a4',
            status: AppointmentStatus.noShow,
          ),
        ],
        radnoVrijeme: [_raspored()],
      );

      expect(_kolona(dan, 'Emir').podnaslov, '09:00–17:00 · 2 termina');
      // Otkazan termin i nedolazak se i dalje **vide** na osi — slot je bio zauzet pa
      // oslobođen, i to je podatak.
      expect(_kolona(dan, 'Emir').termini, hasLength(4));
    });

    test('podnaslov radnika koji ne radi kaže to, a ne prazno vrijeme', () {
      final dan = _dan(
        dan: _nedjelja,
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(dan: 7, zatvoreno: true)],
      );

      expect(_kolona(dan, 'Emir').podnaslov, 'Ne radi');
      expect(_kolona(dan, 'Emir').radi, isFalse);
    });
  });

  group('pauze, neradno i blokade se vide', () {
    test('neradni dan je jedan pojas preko cijele kolone', () {
      final dan = _dan(
        dan: _nedjelja,
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(dan: 7, zatvoreno: true)],
      );

      final pojasevi = _kolona(dan, 'Emir').pozadina.toList();
      expect(pojasevi, hasLength(1));
      expect(pojasevi.single.vrsta, VrstaStavke.neradno);
      expect(pojasevi.single.tekst, 'Ne radi');
      expect(pojasevi.single.odMinuta, dan.osa.pocetakMinuta);
      expect(pojasevi.single.doMinuta, dan.osa.krajMinuta);
    });

    test('salon bez reda za taj dan je isto neradan, ne prazan', () {
      // Red koji ne postoji i red `is_closed` moraju izgledati isto: oba znače „danas se
      // ne radi", a praznina bi značila „slobodno".
      final dan = _dan(radnici: [_radnik('e1', 'Emir')]);

      expect(_kolona(dan, 'Emir').pozadina.single.vrsta, VrstaStavke.neradno);
    });

    test('radnik koji počinje kasnije ima pojas „Ne radi do"', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        radnoVrijeme: [
          _raspored(),
          _raspored(radnik: 'e2', od: 12 * 60, doMinuta: 20 * 60),
        ],
      );

      final amar = _kolona(dan, 'Amar').pozadina.toList();
      expect(amar.single.tekst, 'Ne radi do 12:00');
      expect(amar.single.odMinuta, dan.osa.pocetakMinuta);
      expect(amar.single.doMinuta, 12 * 60);

      // Emir radi do 17, a osa ide do 20 zbog Amara — i njemu se vidi da je gotov.
      final emir = _kolona(dan, 'Emir').pozadina.toList();
      expect(emir.single.tekst, 'Ne radi od 17:00');
    });

    test('pauza iz smjene je svoj pojas', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(pauzaOd: 12 * 60, pauzaDo: 12 * 60 + 40)],
      );

      final pauza = _kolona(
        dan,
        'Emir',
      ).pozadina.firstWhere((s) => s.vrsta == VrstaStavke.pauza);
      expect(pauza.odMinuta, 12 * 60);
      expect(pauza.doMinuta, 12 * 60 + 40);
      expect(pauza.tekst, 'Pauza');
    });

    test('blokada salona stoji u svakoj koloni, radnikova samo u njegovoj', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        radnoVrijeme: [_raspored()],
        blokade: [
          _blokada(od: 10 * 60, doMinuta: 11 * 60, razlog: 'Inventura'),
          _blokada(od: 14 * 60, doMinuta: 15 * 60, radnik: 'e2'),
        ],
      );

      final emir = _kolona(
        dan,
        'Emir',
      ).pozadina.where((s) => s.vrsta == VrstaStavke.blokada).toList();
      final amar = _kolona(
        dan,
        'Amar',
      ).pozadina.where((s) => s.vrsta == VrstaStavke.blokada).toList();

      expect(emir.map((s) => s.tekst), ['Inventura']);
      // Blokada bez razloga mora imati šta pisati — kolona je nullable.
      expect(amar.map((s) => s.tekst), ['Inventura', 'Blokirano']);
    });

    test('blokada ne ulazi u trake termina, nego stoji ispod njih', () {
      // Pauza i termin u isto vrijeme su sudar koji se mora vidjeti kao sudar. Da pauza
      // ulazi u trake, termin bi se pomjerio u stranu i izgledao kao da sudara nema.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 12 * 60, doMinuta: 13 * 60)],
        radnoVrijeme: [_raspored(pauzaOd: 12 * 60, pauzaDo: 12 * 60 + 40)],
      );

      final termin = _kolona(dan, 'Emir').termini.single;
      expect(termin.traka, 0);
      expect(termin.brojTraka, 1);
    });
  });

  group('preklapanje', () {
    test('dva termina u isto vrijeme dobiju dvije trake', () {
      // Moguće bez greške u availability engineu: otkazan termin ostaje u listi, pa novi
      // termin legitimno stoji preko njega. Bez traka bi gornji prekrio donji.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(
            od: 10 * 60,
            doMinuta: 11 * 60,
            id: 'a1',
            status: AppointmentStatus.cancelled,
          ),
          _termin(od: 10 * 60, doMinuta: 11 * 60, id: 'a2'),
        ],
        radnoVrijeme: [_raspored()],
      );

      final termini = _kolona(dan, 'Emir').termini.toList();
      expect(termini.map((s) => s.traka).toSet(), {0, 1});
      expect(termini.every((s) => s.brojTraka == 2), isTrue);
    });

    test('termini koji se ne dodiruju dijele traku 0', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 9 * 60, doMinuta: 10 * 60, id: 'a1'),
          _termin(od: 10 * 60, doMinuta: 11 * 60, id: 'a2'),
        ],
        radnoVrijeme: [_raspored()],
      );

      final termini = _kolona(dan, 'Emir').termini.toList();
      expect(termini.map((s) => s.traka), [0, 0]);
      expect(termini.map((s) => s.brojTraka), [1, 1]);
    });

    test('grupa koja se lančano preklapa ima jednako široke trake', () {
      // 10–12, 11–13, 12–14: prvi i treći se ne dodiruju, ali cijela grupa mora imati isti
      // broj traka, inače su susjedne kolone različite širine.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 10 * 60, doMinuta: 12 * 60, id: 'a1'),
          _termin(od: 11 * 60, doMinuta: 13 * 60, id: 'a2'),
          _termin(od: 12 * 60, doMinuta: 14 * 60, id: 'a3'),
        ],
        radnoVrijeme: [_raspored(doMinuta: 20 * 60)],
      );

      final termini = _kolona(dan, 'Emir').termini.toList();
      expect(termini.every((s) => s.brojTraka == 2), isTrue);
      expect(termini.map((s) => s.traka), [0, 1, 0]);
    });
  });

  group('rubovi dana', () {
    test(
      'kraj koji nije poslije početka znači kraj dana, ne negativan blok',
      () {
        // Postgresov `time` poznaje `24:00:00`, `LocalTime` sate 0–23. Takav red bi dao blok
        // negativne visine — Flutter ga ne iscrta, pa termin nestane sa rasporeda.
        final dan = _dan(
          radnici: [_radnik('e1', 'Emir')],
          termini: [_termin(od: 23 * 60, doMinuta: 0)],
          radnoVrijeme: [_raspored(doMinuta: 23 * 60 + 59)],
        );

        final termin = _kolona(dan, 'Emir').termini.single;
        expect(termin.doMinuta, kMinutaUDanu);
        expect(termin.trajanjeMinuta, 60);
        expect(dan.osa.krajMinuta, kMinutaUDanu);
      },
    );

    test('termin u ponoć ne pomjera osu ispod nule', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 0, doMinuta: 40)],
      );

      expect(dan.osa.pocetakMinuta, 0);
      expect(dan.osa.yZa(0), 0);
    });
  });

  group('linija „sada"', () {
    final dan = _dan(
      radnici: [_radnik('e1', 'Emir')],
      radnoVrijeme: [_raspored()],
    );

    test('stoji na svom mjestu kad je prikazan dan današnji', () {
      expect(dan.yLinijeSada(DateTime(2026, 5, 18, 13)), 4 * kVisinaSata);
    });

    test('ne postoji za drugi dan', () {
      expect(dan.yLinijeSada(DateTime(2026, 5, 19, 13)), isNull);
    });

    test('ne lijepi se za rub ose prije otvaranja i poslije zatvaranja', () {
      // Linija na rubu bi tvrdila da je sad devet, a zapravo je pola osam.
      expect(dan.yLinijeSada(DateTime(2026, 5, 18, 7, 30)), isNull);
      expect(dan.yLinijeSada(DateTime(2026, 5, 18, 19)), isNull);
    });
  });

  group('mobilna lista jednog radnika', () {
    test('slobodne rupe popunjavaju razmake unutar smjene', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 9 * 60, doMinuta: 10 * 60, id: 'a1'),
          _termin(od: 11 * 60, doMinuta: 12 * 60, id: 'a2'),
        ],
        radnoVrijeme: [_raspored(doMinuta: 13 * 60)],
      );

      final redovi = redoviKolone(_kolona(dan, 'Emir'));
      expect(redovi.map((s) => s.vrsta), [
        VrstaStavke.termin,
        VrstaStavke.slobodno,
        VrstaStavke.termin,
        VrstaStavke.slobodno,
      ]);
      expect(redovi[1].odMinuta, 10 * 60);
      expect(redovi[1].doMinuta, 11 * 60);
      expect(redovi.last.doMinuta, 13 * 60);
    });

    test('rupa se odsijeca na kraj smjene, ne na sljedeći termin', () {
      // Termin poslije zatvaranja je moguć (ručni unos ga smije upisati). Rupa do njega bi
      // nudila da se zakaže u vrijeme kad salon ne radi.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [_termin(od: 15 * 60, doMinuta: 16 * 60)],
        radnoVrijeme: [_raspored(od: 9 * 60, doMinuta: 14 * 60)],
      );

      final slobodno = redoviKolone(_kolona(dan, 'Emir'))
          .where((s) => s.vrsta == VrstaStavke.slobodno)
          .toList();

      expect(slobodno, hasLength(1));
      expect(slobodno.single.odMinuta, 9 * 60);
      expect(slobodno.single.doMinuta, 14 * 60);
    });

    test('rupa kraća od praga se ne crta', () {
      // Između dva termina uvijek ostane po koja minuta; „Slobodno 5 min" je šum.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 9 * 60, doMinuta: 10 * 60, id: 'a1'),
          _termin(od: 10 * 60 + 5, doMinuta: 11 * 60, id: 'a2'),
        ],
        radnoVrijeme: [_raspored(doMinuta: 11 * 60)],
      );

      final redovi = redoviKolone(_kolona(dan, 'Emir'));
      expect(redovi.map((s) => s.vrsta), [
        VrstaStavke.termin,
        VrstaStavke.termin,
      ]);
    });

    test('neradni pojas ne ulazi u listu, jer je lista već unutar smjene', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        radnoVrijeme: [
          _raspored(),
          _raspored(radnik: 'e2', od: 12 * 60, doMinuta: 20 * 60),
        ],
      );

      final redovi = redoviKolone(_kolona(dan, 'Amar'));
      expect(redovi.any((s) => s.vrsta == VrstaStavke.neradno), isFalse);
      expect(redovi.single.vrsta, VrstaStavke.slobodno);
      expect(redovi.single.odMinuta, 12 * 60);
    });

    test('pauza i blokada ostaju u listi, jer su ono što drži vrijeme', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(pauzaOd: 12 * 60, pauzaDo: 12 * 60 + 40)],
        blokade: [_blokada(od: 14 * 60, doMinuta: 15 * 60, razlog: 'Servis')],
      );

      final redovi = redoviKolone(_kolona(dan, 'Emir'));
      expect(redovi.where((s) => s.vrsta == VrstaStavke.pauza), hasLength(1));
      expect(
        redovi.where((s) => s.vrsta == VrstaStavke.blokada).single.tekst,
        'Servis',
      );
    });

    test('dan u kojem radnik ne radi nema izmišljeno slobodno vrijeme', () {
      final dan = _dan(
        dan: _nedjelja,
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(dan: 7, zatvoreno: true)],
      );

      final redovi = redoviKolone(_kolona(dan, 'Emir'));
      expect(redovi.any((s) => s.vrsta == VrstaStavke.slobodno), isFalse);
    });

    test('termin unutar drugog ne otvara lažnu rupu iza sebe', () {
      // Kursor koji se pomjeri unazad bi između 11:00 i 12:00 prijavio slobodno, iako taj
      // sat drži duži termin.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir')],
        termini: [
          _termin(od: 10 * 60, doMinuta: 12 * 60, id: 'a1'),
          _termin(od: 10 * 60 + 30, doMinuta: 11 * 60, id: 'a2'),
        ],
        radnoVrijeme: [_raspored(od: 10 * 60, doMinuta: 12 * 60)],
      );

      final redovi = redoviKolone(_kolona(dan, 'Emir'));
      expect(redovi.any((s) => s.vrsta == VrstaStavke.slobodno), isFalse);
    });
  });

  group('mobilna lista svih radnika', () {
    test('miješa radnike po vremenu i svakom redu piše čiji je', () {
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        termini: [
          _termin(od: 11 * 60, doMinuta: 12 * 60, id: 'a1'),
          _termin(od: 10 * 60, doMinuta: 11 * 60, id: 'a2', radnik: 'e2'),
        ],
        radnoVrijeme: [_raspored()],
      );

      final redovi = redoviDana(dan);
      expect(redovi.map((r) => r.radnik), ['Amar', 'Emir']);
      expect(redovi.first.stavka.odMinuta, 10 * 60);
    });

    test('nema izmišljenog slobodnog vremena preko cijelog salona', () {
      // Kad u smjeni radi troje, „slobodno" nije „otvoreno minus zauzeto" — isti razlog
      // zbog kojeg kartica „Slobodno vrijeme" nije ušla u `3b`.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        termini: [_termin(od: 11 * 60, doMinuta: 12 * 60)],
        radnoVrijeme: [_raspored()],
      );

      expect(
        redoviDana(dan).any((r) => r.stavka.vrsta == VrstaStavke.slobodno),
        isFalse,
      );
    });

    test('salonska blokada se ispisuje jednom, i bez imena radnika', () {
      final dan = _dan(
        radnici: [
          _radnik('e1', 'Emir'),
          _radnik('e2', 'Amar'),
          _radnik('e3', 'Vedad'),
        ],
        radnoVrijeme: [_raspored()],
        blokade: [
          _blokada(od: 10 * 60, doMinuta: 11 * 60, razlog: 'Inventura'),
        ],
      );

      final blokade = redoviDana(dan)
          .where((r) => r.stavka.vrsta == VrstaStavke.blokada)
          .toList();
      expect(blokade, hasLength(1));
      expect(blokade.single.radnik, isNull);
    });

    test('dvije radnikove blokade u isto vrijeme ostaju dvije', () {
      // Prepoznavanje po vremenu i tekstu bi ih spojilo u jednu; razlikuju se po tome
      // čije su, ne po tome kako izgledaju.
      final dan = _dan(
        radnici: [_radnik('e1', 'Emir'), _radnik('e2', 'Amar')],
        radnoVrijeme: [_raspored()],
        blokade: [
          _blokada(
            od: 10 * 60,
            doMinuta: 11 * 60,
            radnik: 'e1',
            razlog: 'Obuka',
          ),
          _blokada(
            od: 10 * 60,
            doMinuta: 11 * 60,
            radnik: 'e2',
            razlog: 'Obuka',
          ),
        ],
      );

      final blokade = redoviDana(dan)
          .where((r) => r.stavka.vrsta == VrstaStavke.blokada)
          .toList();
      expect(blokade.map((r) => r.radnik), ['Amar', 'Emir']);
    });

    test('neradni pojasevi ne ulaze u listu', () {
      final dan = _dan(
        dan: _nedjelja,
        radnici: [_radnik('e1', 'Emir')],
        radnoVrijeme: [_raspored(dan: 7, zatvoreno: true)],
      );

      expect(redoviDana(dan), isEmpty);
    });
  });
}
