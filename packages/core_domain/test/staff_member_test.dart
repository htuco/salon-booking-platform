import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// `StaffMember.isSalonAdmin` odlučuje smije li admin app pokazati ijedan ekran, pa je
/// jedina logika u ovom modelu i jedino što se ovdje testira.
void main() {
  const salonId = '550e8400-e29b-41d4-a716-446655440000';

  StaffMember clan({required String role, String? salon = salonId}) =>
      StaffMember(
        id: '11111111-0000-4000-8000-000000000001',
        name: 'Vlasnik',
        email: 'admin@primjer.test',
        role: role,
        salonId: salon,
      );

  group('isSalonAdmin', () {
    test('salon_admin sa salonom upravlja salonom', () {
      expect(clan(role: 'salon_admin').isSalonAdmin, isTrue);
    });

    test('super_admin nije salon admin iako je iznad svih', () {
      // Njegov ekran je super admin konzola iz Sprinta 3. Bez ovog razdvajanja bi usao u
      // admin app sa `salonId == null` i vidio prazan ekran koji izgleda kao greska.
      expect(clan(role: 'super_admin', salon: null).isSalonAdmin, isFalse);
    });

    test('employee nije salon admin', () {
      expect(clan(role: 'employee').isSalonAdmin, isFalse);
    });

    test('salon_admin bez salona nije salon admin', () {
      // Baza to drzi `check` ogranicenjem, ali model ne smije pasti na tu pretpostavku:
      // red koji je nekako prosao bez salona ne smije dati admina bez konteksta.
      expect(clan(role: 'salon_admin', salon: null).isSalonAdmin, isFalse);
    });

    test('nepoznata uloga iz buduce migracije ne rusi model', () {
      // Uloga je namjerno `String`, ne enum — app u storeu je uvijek starija od baze.
      final buduca = clan(role: 'receptionist');
      expect(buduca.isSalonAdmin, isFalse);
      expect(buduca.salonId, salonId);
    });
  });

  test('jednakost ide po vrijednosti, ne po referenci', () {
    expect(clan(role: 'salon_admin'), equals(clan(role: 'salon_admin')));
    expect(
      clan(role: 'salon_admin').hashCode,
      clan(role: 'salon_admin').hashCode,
    );
    expect(clan(role: 'salon_admin'), isNot(equals(clan(role: 'employee'))));
  });
}
