import 'package:admin/src/features/working_hours/working_hours_dialogs.dart';
import 'package:admin/src/features/working_hours/working_hours_pisanje.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sedmica sa 09–17, pon–pet otvoreno, vikend zatvoren.
List<WorkingHoursInput> _sedmica() => [
  for (var d = 1; d <= 7; d++)
    WorkingHoursInput(
      dayOfWeek: d,
      startTime: const LocalTime(9, 0),
      endTime: const LocalTime(17, 0),
      isClosed: d > 5,
    ),
];

void main() {
  group('primijeniPauzu', () {
    test('nova pauza dobija samo izabrane dane', () {
      final nova = primijeniPauzu(
        _sedmica(),
        const {},
        const IzmjenaPauze(
          od: LocalTime(12, 0),
          do_: LocalTime(12, 30),
          dani: {1, 2},
        ),
      );
      expect(nova[0].breakStartTime, const LocalTime(12, 0));
      expect(nova[1].breakEndTime, const LocalTime(12, 30));
      expect(nova[2].hasBreak, isFalse);
    });

    test('dani koji ispadnu iz stare grupe gube pauzu', () {
      final sa = primijeniPauzu(
        _sedmica(),
        const {},
        const IzmjenaPauze(
          od: LocalTime(12, 0),
          do_: LocalTime(12, 30),
          dani: {1, 2, 3},
        ),
      );
      final nova = primijeniPauzu(
        sa,
        const {1, 2, 3},
        const IzmjenaPauze(
          od: LocalTime(13, 0),
          do_: LocalTime(13, 30),
          dani: {1},
        ),
      );
      expect(nova[0].breakStartTime, const LocalTime(13, 0));
      expect(nova[1].hasBreak, isFalse);
      expect(nova[2].hasBreak, isFalse);
    });

    test('ne mijenja ulaznu listu', () {
      final ulaz = _sedmica();
      primijeniPauzu(
        ulaz,
        const {},
        const IzmjenaPauze(
          od: LocalTime(12, 0),
          do_: LocalTime(12, 30),
          dani: {1},
        ),
      );
      expect(ulaz[0].hasBreak, isFalse);
    });
  });

  group('provjeriSedmicu', () {
    test('uredna sedmica nema problema', () {
      expect(provjeriSedmicu(_sedmica()), isNull);
    });

    test('pauza van smjene je problem sa imenom dana', () {
      final nova = primijeniPauzu(
        _sedmica(),
        const {},
        const IzmjenaPauze(
          od: LocalTime(16, 30),
          do_: LocalTime(17, 30),
          dani: {1},
        ),
      );
      expect(provjeriSedmicu(nova), contains('pauza mora biti unutar'));
    });

    test('zatvoren dan se ne provjerava', () {
      final nova = primijeniPauzu(
        _sedmica(),
        const {},
        const IzmjenaPauze(
          od: LocalTime(20, 0),
          do_: LocalTime(21, 0),
          dani: {6},
        ),
      );
      expect(provjeriSedmicu(nova), isNull);
    });
  });
}
