/// Živi primjeri uz vremenske postavke (task 44) — tekst, ne izračunat slot.
library;

import 'package:admin/src/features/settings/settings_primjeri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rok otkazivanja: isti dan, prethodni dan, više dana, nula', () {
    expect(primjerRokaOtkazivanja(3), contains('sa 3 sata'));
    expect(primjerRokaOtkazivanja(3), contains('najkasnije u 6:00'));
    expect(
      primjerRokaOtkazivanja(24),
      contains('najkasnije prethodnog dana u 9:00'),
    );
    expect(
      primjerRokaOtkazivanja(48),
      contains('najkasnije 2 dana ranije u 9:00'),
    );
    expect(primjerRokaOtkazivanja(0), contains('sve do 9:00'));
    expect(primjerRokaOtkazivanja(null), isNull);
  });

  test('najraniji termin koristi isti sat kao rok', () {
    expect(primjerNajranijeg(2), contains('najkasnije u 7:00'));
    expect(primjerNajranijeg(1), contains('sa 1 sat '));
    expect(primjerNajranijeg(5), contains('sa 5 sati'));
  });

  test('korak, pauza i kalendar', () {
    expect(primjerKoraka(15), contains('9:00, 9:15, 9:30'));
    expect(primjerKoraka(0), isNull);
    expect(primjerPauze(5), contains('najranije u 9:35'));
    expect(primjerPauze(0), contains('odmah u 9:30'));
    expect(primjerKalendara(21), contains('narednih 21 dan'));
    expect(primjerKalendara(30), contains('narednih 30 dana'));
  });
}
