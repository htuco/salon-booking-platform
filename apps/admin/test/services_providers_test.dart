import 'package:admin/src/features/services/services_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cijena se normalizuje bez floating pointa', () {
    expect(normalizeServicePrice('12'), '12.00');
    expect(normalizeServicePrice('12,5'), '12.50');
    expect(normalizeServicePrice(' 12.50 '), '12.50');
  });

  test('odbija negativno, tri decimale i tekst', () {
    expect(normalizeServicePrice('-1'), isNull);
    expect(normalizeServicePrice('12.999'), isNull);
    expect(normalizeServicePrice('KM 12'), isNull);
  });
}
