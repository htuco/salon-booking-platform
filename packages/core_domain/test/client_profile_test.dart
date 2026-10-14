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

  group('isValidEmail', () {
    test('prihvata uobičajene adrese', () {
      for (final email in [
        'ana@gmail.com',
        'ana.anic+salon@primjer.co.ba',
        'A_B-c@sub.domena.ba',
      ]) {
        expect(isValidEmail(email), isTrue, reason: email);
      }
    });

    test('odbija tipfelere koje server ne objašnjava', () {
      for (final email in [
        'ana@gmail',
        'ana@@gmail.com',
        'ana@gmail..com',
        '.ana@gmail.com',
        'ana @gmail.com',
        'ana@-gmail.com',
        'ana@gmail.c',
        '@gmail.com',
        'ana',
      ]) {
        expect(isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  group('broj uz pozivni', () {
    test('lokalni zapis sa i bez nule je ispravan', () {
      for (final broj in [
        '061 123 456',
        '61 123 456',
        '61/123-456',
        '033 123 456',
      ]) {
        expect(isValidNationalNumber(broj), isTrue, reason: broj);
      }
    });

    test('slova, prekratak, predug i dvije nule nisu broj', () {
      for (final broj in [
        '',
        '061 abc',
        '12345',
        '0061 123 456',
        '1234567890123',
      ]) {
        expect(isValidNationalNumber(broj), isFalse, reason: broj);
      }
    });

    test(
      'composePhone skida vodeću nulu, čuva grupisanje i prolazi isValidPhone',
      () {
        expect(composePhone('+387', '061 123 456'), '+387 61 123 456');
        expect(composePhone('+387', '61/123-456'), '+387 61 123 456');
        expect(composePhone('+49', '0151 2345678'), '+49 151 2345678');
        expect(isValidPhone(composePhone('+387', '061 123 456')), isTrue);
      },
    );
  });
}
