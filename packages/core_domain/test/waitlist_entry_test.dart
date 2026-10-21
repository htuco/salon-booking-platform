import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Upis na listu čekanja sa rasponom (task 91): red iz `my_waitlist` i pitanje „pokriva li dan".
void main() {
  Map<String, dynamic> red({
    Object? od = '2026-10-21',
    Object? doDana = '2026-10-30',
  }) => {
    'id': 'w1',
    'service_id': 's1',
    'service_name': 'Fade',
    'employee_id': 'e1',
    'employee_name': 'Emir',
    'date_from': od,
    'date_to': doDana,
  };

  test('red nosi raspon kao zidne dane salona', () {
    final upis = WaitlistEntry.fromJson(red());

    expect(upis.dateFrom, const LocalDate(2026, 10, 21));
    expect(upis.dateTo, const LocalDate(2026, 10, 30));
    expect(upis.employeeName, 'Emir');
  });

  test('raspon pokriva oba kraja, a ne dan poslije granice', () {
    final upis = WaitlistEntry.fromJson(red());

    expect(upis.covers(const LocalDate(2026, 10, 21)), isTrue);
    expect(upis.covers(const LocalDate(2026, 10, 30)), isTrue);
    // 31.10. je prvi slobodan termin: granica, ne dan u rasponu.
    expect(upis.covers(const LocalDate(2026, 10, 31)), isFalse);
    expect(upis.covers(const LocalDate(2026, 10, 20)), isFalse);
  });

  test('red bez raspona (stari oblik sa jednim `date`) je FormatException', () {
    final stari = red(od: null, doDana: null)..['date'] = '2026-10-27';

    expect(() => WaitlistEntry.fromJson(stari), throwsFormatException);
  });
}
