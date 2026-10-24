/// Množina sati uz podsjetnik (task 56) — `core/format/tekst.dart`.
library;

import 'package:admin/src/core/format/tekst.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('satiTekst prati bosansku množinu, uključujući 11–14', () {
    expect(
      {
        for (final n in [1, 2, 3, 4, 5, 11, 12, 13, 14, 21, 22, 25])
          n: satiTekst(n),
      },
      {
        1: '1 sat',
        2: '2 sata',
        3: '3 sata',
        4: '4 sata',
        5: '5 sati',
        11: '11 sati',
        12: '12 sati',
        13: '13 sati',
        14: '14 sati',
        21: '21 sat',
        22: '22 sata',
        25: '25 sati',
      },
    );
  });
}
