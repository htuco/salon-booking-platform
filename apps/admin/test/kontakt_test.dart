/// Pravila kontakta jednim tapom (task 58), bez ekrana.
///
/// Broj je ono što salon upiše rukom, pa test ide po oblicima koji se stvarno pojavljuju u
/// adresaru: sa nulom, sa razmacima i crticama, sa `00` i sa `+`.
library;

import 'package:admin/src/core/kontakt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('medjunarodniBroj', () {
    test('lokalni broj sa nulom dobije +387', () {
      expect(medjunarodniBroj('061 552 104'), '+38761552104');
      expect(medjunarodniBroj('062/123-456'), '+38762123456');
    });

    test('broj iz aplikacije ostaje svoj, i van BiH', () {
      expect(medjunarodniBroj('+387 61 552 104'), '+38761552104');
      expect(medjunarodniBroj('+385 91 234 5678'), '+385912345678');
    });

    test('00 je isto što i +', () {
      expect(medjunarodniBroj('00387 61 552 104'), '+38761552104');
      expect(medjunarodniBroj('0049 151 2345678'), '+491512345678');
    });

    test('pozivni uz nulu gubi nulu', () {
      expect(medjunarodniBroj('+387 061 552 104'), '+38761552104');
      expect(medjunarodniBroj('00387 061 552 104'), '+38761552104');
    });

    test('BiH broj kraći od 8 cifara nema link', () {
      expect(medjunarodniBroj('12345'), isNull);
      expect(medjunarodniBroj('061 552'), isNull);
    });

    test('pozivni bez plusa i lokalni bez nule', () {
      expect(medjunarodniBroj('387 61 552 104'), '+38761552104');
      expect(medjunarodniBroj('61 552 104'), '+38761552104');
    });

    test('prazno i ono što nije broj nema link', () {
      expect(medjunarodniBroj(null), isNull);
      expect(medjunarodniBroj(''), isNull);
      expect(medjunarodniBroj('   '), isNull);
      expect(medjunarodniBroj('nema'), isNull);
      expect(medjunarodniBroj('+387 12'), isNull);
      expect(medjunarodniBroj('+1234567890123456'), isNull);
    });
  });

  group('uriKontakta', () {
    const broj = '+38761552104';

    test('poziv je tel: sa plusom', () {
      expect(
        uriKontakta(KanalKontakta.poziv, broj).toString(),
        'tel:+38761552104',
      );
    });

    test('Viber dobije kodiran plus', () {
      // Nekodiran `+` Viber pročita kao razmak i otvori prazan chat.
      expect(
        uriKontakta(KanalKontakta.viber, broj).toString(),
        'viber://chat?number=%2B38761552104',
      );
    });

    test('wa.me dobije samo cifre', () {
      expect(
        uriKontakta(KanalKontakta.whatsapp, broj).toString(),
        'https://wa.me/38761552104',
      );
    });
  });

  test('na webu nema Vibera', () {
    expect(kanaliPoruke(web: true), [KanalKontakta.whatsapp]);
    expect(kanaliPoruke(web: false), [
      KanalKontakta.viber,
      KanalKontakta.whatsapp,
    ]);
  });
}
