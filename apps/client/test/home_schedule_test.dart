import 'package:client/src/core/formatters.dart';
import 'package:client/src/features/home/salon_schedule.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jedini dio home ekrana koji ima stvarna pravila: živi status "Otvoreno do 20:00" i
/// formatiranje cijene i trajanja.
///
/// Testira se bez `pumpWidget`-a, jer je logika namjerno van widgeta — izračun u `build`
/// metodi bi tražio podizanje cijele app-e za provjeru da srijeda u 08:00 znači
/// "zatvoreno, otvara u 09:00".
void main() {
  group('SalonSchedule.statusAt', () {
    test('unutar radnog vremena — otvoreno do kraja smjene', () {
      final schedule = SalonSchedule.fromHours([
        _sat(dan: DateTime.wednesday, od: '09:00', do_: '17:00'),
      ]);

      final status = schedule.statusAt(_srijeda(12, 30));

      expect(status, isA<SalonOpen>());
      expect((status as SalonOpen).until.format(), '17:00');
    });

    test('prije otvaranja — zatvoreno, ali danas jos otvara', () {
      final schedule = SalonSchedule.fromHours([
        _sat(dan: DateTime.wednesday, od: '09:00', do_: '17:00'),
      ]);

      final status = schedule.statusAt(_srijeda(7, 45));

      expect(status, isA<SalonOpensLater>());
      expect((status as SalonOpensLater).at.format(), '09:00');
    });

    test('poslije zatvaranja — danas zatvoreno, ne "otvara u 09:00"', () {
      // Regresija na ocitu gresku: kad se status racuna samo poredjenjem sa pocetkom
      // smjene, salon u 22:00 pokazuje "otvara u 09:00" kao da je jos jutro.
      final schedule = SalonSchedule.fromHours([
        _sat(dan: DateTime.wednesday, od: '09:00', do_: '17:00'),
      ]);

      expect(schedule.statusAt(_srijeda(22, 0)), isA<SalonClosedToday>());
    });

    test('tacno u minuti zatvaranja salon je vec zatvoren', () {
      final schedule = SalonSchedule.fromHours([
        _sat(dan: DateTime.wednesday, od: '09:00', do_: '17:00'),
      ]);

      expect(schedule.statusAt(_srijeda(17, 0)), isA<SalonClosedToday>());
    });

    test('dan oznacen kao zatvoren nije otvoren ni unutar sati', () {
      final schedule = SalonSchedule.fromHours([
        _sat(
          dan: DateTime.wednesday,
          od: '09:00',
          do_: '17:00',
          zatvoren: true,
        ),
      ]);

      expect(schedule.statusAt(_srijeda(12, 0)), isA<SalonClosedToday>());
    });

    test('red po radniku ne odredjuje kad je salon otvoren', () {
      // Radnik moze imati slobodan dan dok salon radi, i obrnuto. Kad bi se redovi po
      // radniku racunali, status salona bi zavisio od rasporeda jednog zaposlenika.
      final schedule = SalonSchedule.fromHours([
        _sat(
          dan: DateTime.wednesday,
          od: '09:00',
          do_: '17:00',
          employeeId: 'emp-1',
        ),
      ]);

      expect(schedule.isEmpty, isTrue);
      expect(schedule.statusAt(_srijeda(12, 0)), isA<SalonClosedToday>());
    });
  });

  group('SalonSchedule.week', () {
    test('uvijek sedam dana, i kad baza nema red za svaki', () {
      // Lista koja preskoci utorak izgleda kao greska u app-i, a ne kao neunesen podatak.
      final schedule = SalonSchedule.fromHours([
        _sat(dan: DateTime.monday, od: '09:00', do_: '17:00'),
      ]);

      expect(schedule.week.length, 7);
      expect(schedule.week.first.weekday, DateTime.monday);
      expect(schedule.week.first.isClosed, isFalse);
      expect(schedule.week[1].isClosed, isTrue, reason: 'utorak nema red');
      expect(schedule.week.last.weekday, DateTime.sunday);
    });
  });

  group('formatPrice', () {
    test('cijeli broj bez decimala', () => expect(formatPrice(15), '15 KM'));
    test('decimala se zadrzava', () => expect(formatPrice(12.5), '12.50 KM'));
  });

  group('formatDuration', () {
    test('ispod sata u minutama', () => expect(formatDuration(45), '45 min'));
    test('puni sat bez minuta', () => expect(formatDuration(60), '1 h'));
    test('sat i minute', () => expect(formatDuration(150), '2 h 30 min'));
  });
}

DateTime _srijeda(int sat, int minuta) => DateTime(2026, 9, 9, sat, minuta);

WorkingHour _sat({
  required int dan,
  required String od,
  required String do_,
  bool zatvoren = false,
  String? employeeId,
}) => WorkingHour(
  id: 'wh-$dan',
  salonId: 'salon-1',
  employeeId: employeeId,
  dayOfWeek: dan,
  startTime: LocalTime.parse(od),
  endTime: LocalTime.parse(do_),
  isClosed: zatvoren,
);
