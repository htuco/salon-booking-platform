import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ClientProfileStatus', () {
    test('mapira red iz client_profile_status', () {
      final status = ClientProfileStatus.fromJson(const {
        'has_name': true,
        'has_phone': false,
        'terms_current': true,
      });

      expect(status.hasName, isTrue);
      expect(status.hasPhone, isFalse);
      expect(status.isComplete, isFalse);
    });

    test('kompletan je tek kad ništa ne fali', () {
      const kompletan = ClientProfileStatus(
        hasName: true,
        hasPhone: true,
        termsCurrent: true,
      );
      expect(kompletan.isComplete, isTrue);
      // Stara verzija uslova je dovoljna da profil nije kompletan.
      expect(
        const ClientProfileStatus(
          hasName: true,
          hasPhone: true,
          termsCurrent: false,
        ).isComplete,
        isFalse,
      );
    });

    test('red bez očekivanih polja je FormatException', () {
      expect(
        () => ClientProfileStatus.fromJson(const {'has_name': true}),
        throwsFormatException,
      );
    });
  });

  // Isto pravilo kao `private.clean_phone` u bazi (task 66). Kad se razidu, forma pusti
  // broj koji baza tiho odbaci, ili odbije broj koji bi baza primila.
  group('isValidPhone', () {
    test('prihvata broj onako kako ga ljudi pišu', () {
      for (final broj in [
        '061 123 456',
        '+387 61 123 456',
        '+38761123456',
        '061/123-456',
        '(033) 123 456',
      ]) {
        expect(isValidPhone(broj), isTrue, reason: broj);
      }
    });

    test('odbija slova, premalo i previše cifara', () {
      for (final broj in [
        '',
        'nije-broj',
        '12345',
        '1234567890123456',
        '+387 61 abc',
      ]) {
        expect(isValidPhone(broj), isFalse, reason: broj);
      }
    });
  });

  group('isValidFullName', () {
    test('prazno i predugo nije ime', () {
      expect(isValidFullName('  '), isFalse);
      expect(isValidFullName('a' * 121), isFalse);
      expect(isValidFullName(' Ana Anić '), isTrue);
    });
  });
}
