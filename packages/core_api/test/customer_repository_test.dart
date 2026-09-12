import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Isti obrazac kao ostali repozitoriji: gađa se mapiranje, ne `.rpc(...)`.
///
/// Ono što se ovdje **ne** dokazuje su autorizacija i idempotentnost — to su svojstva
/// baze i dokazuju se u `supabase/tests/003_customer_upsert.test.sql` i
/// `rest_customer_upsert.ts`. Dart test koji bi ih „provjerio" nad lažnim klijentom
/// dokazivao bi samo da mock vraća ono što mu je rečeno.
void main() {
  group('customerIdFromRow', () {
    test('vraća id iz reda koji funkcija stvarno vraća', () {
      expect(
        customerIdFromRow(const {
          'id': '30000000-0000-4000-8000-000000000001',
          'salon_id': '550e8400-e29b-41d4-a716-446655440000',
          'name': 'Amina',
        }),
        '30000000-0000-4000-8000-000000000001',
      );
    });

    test('prazan objekat je greška, ne `null` koji putuje dalje', () {
      // `ensure_customer` je `returns public.customers`; PostgREST njen `null` pretvara u
      // prazan objekat, ne u grešku. Bez ove grane bi `book_appointment` dobio `null` kao
      // `customerId` i pao kasnije, na mjestu koje ne govori gdje je stvarno puklo.
      expect(() => customerIdFromRow(const {}), throwsA(isA<ServerError>()));
      expect(() => customerIdFromRow(null), throwsA(isA<ServerError>()));
    });

    test('prazan string se ne propušta kao validan id', () {
      expect(
        () => customerIdFromRow(const {'id': ''}),
        throwsA(isA<ServerError>()),
      );
    });
  });
}
