import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('LocalTime', () {
    test('parsira oba oblika koja PostgREST vraća', () {
      expect(LocalTime.parse('09:00:00'), const LocalTime(9, 0));
      expect(LocalTime.parse('09:00'), const LocalTime(9, 0));
      expect(LocalTime.parse('14:30:00'), const LocalTime(14, 30));
    });

    test('format vraća oblik koji baza očekuje nazad', () {
      expect(const LocalTime(9, 0).format(), '09:00');
      expect(const LocalTime(14, 30).format(), '14:30');
      expect(const LocalTime(0, 5).format(), '00:05');
    });

    test('poređenje ide po minutama od ponoći', () {
      expect(const LocalTime(9, 0) < const LocalTime(9, 30), isTrue);
      expect(const LocalTime(17, 0) > const LocalTime(9, 0), isTrue);
      expect(const LocalTime(9, 0) <= const LocalTime(9, 0), isTrue);
      expect(const LocalTime(12, 0).minutesFromMidnight, 720);
    });

    test('jednakost je po vrijednosti, ne po instanci', () {
      expect(const LocalTime(9, 0), LocalTime.parse('09:00:00'));
      expect(
        {const LocalTime(9, 0), LocalTime.parse('09:00')}.length,
        1,
        reason: 'isti sat i minuta moraju dati isti hashCode',
      );
    });

    test('odbija neispravan ulaz umjesto da tiho da pogrešno vrijeme', () {
      expect(() => LocalTime.parse('9'), throwsFormatException);
      expect(() => LocalTime.parse('25:00'), throwsFormatException);
      expect(() => LocalTime.parse('09:70'), throwsFormatException);
      expect(() => LocalTime.parse('ab:cd'), throwsFormatException);
    });

    test('radno vrijeme se ne pomjera sa zonom uređaja', () {
      // Ovo je cijeli razlog postojanja tipa. `DateTime.parse('2026-09-14 09:00:00')`
      // daje ponoć+9h po zoni uređaja, pa `.toUtc().hour` u Sarajevu (UTC+2) daje 7.
      // LocalTime nema zonu i zato nema šta da pomjeri.
      final wall = LocalTime.parse('09:00:00');

      expect(wall.hour, 9);
      expect(wall.format(), '09:00');
      // Nema API-ja koji bi ovo pretvorio u trenutak bez eksplicitne zone — namjerno.
      expect(wall, isNot(isA<DateTime>()));
    });
  });

  group('LocalDate', () {
    test('parsira yyyy-MM-dd', () {
      expect(LocalDate.parse('2026-09-14'), const LocalDate(2026, 9, 14));
      expect(LocalDate.parse('2026-01-01').format(), '2026-01-01');
    });

    test('weekday je ISO 1–7, isti ključ kao working_hours.day_of_week', () {
      // 14.09.2026. je ponedjeljak.
      expect(const LocalDate(2026, 9, 14).weekday, 1);
      // 20.09.2026. je nedjelja — dan koji je u seedu zatvoren.
      expect(const LocalDate(2026, 9, 20).weekday, 7);
    });

    test('poređenje ide po godini, pa mjesecu, pa danu', () {
      expect(
        const LocalDate(2026, 9, 14).compareTo(const LocalDate(2026, 9, 15)),
        lessThan(0),
      );
      expect(
        const LocalDate(2027, 1, 1).compareTo(const LocalDate(2026, 12, 31)),
        greaterThan(0),
      );
    });

    test('odbija neispravan ulaz', () {
      expect(() => LocalDate.parse('2026-09'), throwsFormatException);
      expect(() => LocalDate.parse('2026-13-01'), throwsFormatException);
      expect(() => LocalDate.parse('xxxx-01-01'), throwsFormatException);
    });
  });
}
