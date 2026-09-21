import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

const _salon = 's1';

WorkingHour _red(
  int dan, {
  String? employeeId,
  bool isClosed = false,
  LocalTime? pauzaOd,
  LocalTime? pauzaDo,
}) => WorkingHour(
  id: 'w$dan${employeeId ?? ''}',
  salonId: _salon,
  employeeId: employeeId,
  dayOfWeek: dan,
  startTime: const LocalTime(9, 0),
  endTime: const LocalTime(17, 0),
  breakStartTime: pauzaOd,
  breakEndTime: pauzaDo,
  isClosed: isClosed,
);

void main() {
  group('weekFromWorkingHours', () {
    test('prazna tabela daje sedam zatvorenih dana, ne praznu listu', () {
      // Ovo je isto pravilo koje primjenjuje `get_available_slots`: red kojeg nema znaci
      // zatvoreno. Kad bi ekran popunio otvorene dane, pokazivao bi raspored koji baza ne
      // vidi — i vlasnik bi nudio termine u danima za koje misli da su zatvoreni.
      final sedmica = weekFromWorkingHours(const []);

      expect(sedmica, hasLength(7));
      expect(sedmica.every((d) => d.isClosed), isTrue);
      expect(sedmica.map((d) => d.dayOfWeek), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ], reason: 'dani izlaze po ISO redoslijedu bez obzira na ulaz');
    });

    test('nepotpun raspored popunjava samo dane kojih nema', () {
      final sedmica = weekFromWorkingHours([_red(1), _red(3)]);

      expect(sedmica[0].isClosed, isFalse);
      expect(sedmica[1].isClosed, isTrue, reason: 'utorak nema red');
      expect(sedmica[2].isClosed, isFalse);
      expect(sedmica[6].isClosed, isTrue);
    });

    test('uzima salonske redove, ne radnikove', () {
      // Oba sloja stizu iz istog upita (`forSalon` vraca i jedne i druge). Ekran salona
      // koji bi pokupio radnikov red prikazao bi tudji raspored kao svoj.
      final sedmica = weekFromWorkingHours([
        _red(1),
        _red(1, employeeId: 'e1', isClosed: true),
      ]);

      expect(sedmica[0].isClosed, isFalse);
    });

    test('sa `employeeId` uzima radnikove redove', () {
      final sedmica = weekFromWorkingHours([
        _red(1),
        _red(1, employeeId: 'e1', isClosed: true),
      ], employeeId: 'e1');

      expect(sedmica[0].isClosed, isTrue);
    });

    test('pauza prezivi put kroz ulaz', () {
      final sedmica = weekFromWorkingHours([
        _red(
          1,
          pauzaOd: const LocalTime(13, 0),
          pauzaDo: const LocalTime(14, 0),
        ),
      ]);

      expect(sedmica[0].hasBreak, isTrue);
      expect(sedmica[0].breakStartTime, const LocalTime(13, 0));
    });
  });

  group('WorkingHoursInput', () {
    test('`clearBreak` uklanja pauzu, `null` je ne dira', () {
      // `copyWith(breakStartTime: null)` znaci „ne mijenjaj", pa bez `clearBreak` ne bi
      // postojao nacin da se pauza ukloni — polje bi se moglo samo mijenjati, nikad
      // brisati, i „Ukloni pauzu" na ekranu ne bi radilo nista.
      final sa = WorkingHoursInput(
        dayOfWeek: 1,
        startTime: const LocalTime(9, 0),
        endTime: const LocalTime(17, 0),
        breakStartTime: const LocalTime(13, 0),
        breakEndTime: const LocalTime(14, 0),
      );

      expect(sa.copyWith(breakStartTime: null).hasBreak, isTrue);
      expect(sa.copyWith(clearBreak: true).hasBreak, isFalse);
    });

    test('`toRpc` šalje `HH:mm` i `null` za pauzu koje nema', () {
      final dan = WorkingHoursInput.closed(7).toRpc();

      expect(dan['day_of_week'], 7);
      expect(dan['is_closed'], isTrue);
      expect(dan['start_time'], '09:00');
      expect(dan['break_start_time'], isNull);
    });

    test(
      'jednakost gleda sadržaj — ekran po njoj zna je li nešto izmijenjeno',
      () {
        final a = WorkingHoursInput.closed(1);
        final b = WorkingHoursInput.closed(1);

        expect(a, b);
        expect(a == a.copyWith(isClosed: false), isFalse);
      },
    );
  });
}
