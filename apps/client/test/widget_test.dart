import 'package:client/main.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // SALON_ID je compile-time konstanta, pa test bez --dart-define može pokriti
  // samo prazan slučaj. Sadržaj po tenantu se provjerava kroz registar.
  testWidgets('Build bez tenanta prijavljuje da konfiguracija nedostaje', (
    tester,
  ) async {
    await tester.pumpWidget(const TenantPreviewApp());
    expect(find.text('Nedostaje SALON_ID konfiguracija.'), findsOneWidget);
  });

  group('Generisani registar tenanata', () {
    test('sadrži oba demo salona iz seed.sql', () {
      expect(
        kTenants.keys,
        containsAll(<String>[
          '550e8400-e29b-41d4-a716-446655440000',
          '550e8400-e29b-41d4-a716-446655440001',
        ]),
      );
    });

    test('ključ je salonId svakog tenanta', () {
      for (final entry in kTenants.entries) {
        expect(entry.key, entry.value.salonId);
      }
    });

    test('applicationId je jedinstven po tenantu', () {
      final flavors = kTenants.values.map((t) => t.flavor).toSet();
      expect(flavors.length, kTenants.length);
    });

    test('flavor je validan gradle identifikator', () {
      for (final tenant in kTenants.values) {
        expect(
          RegExp(r'^[a-z][a-z0-9]*$').hasMatch(tenant.flavor),
          isTrue,
          reason: '${tenant.flavor} nije validan gradle flavor',
        );
      }
    });
  });
}
