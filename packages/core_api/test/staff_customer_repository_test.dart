/// Pretraga adresara — jedino mjesto u repou gdje korisnikov tekst ulazi u PostgREST izraz.
///
/// **Ovo nije test izolacije.** Izolaciju drži `staff_manage` politika i dokazuje je
/// `supabase/tests/rest_cross_salon_isolation.ts` kroz stvaran token; RLS se primjenjuje
/// prije `where`-a, pa nijedan uslov dodan kroz `or` ne može vratiti tuđi red. Ovdje se
/// mjeri drugo: da izraz ostane **izraz koji smo napisali**, jer razbijen izraz daje tiho
/// pogrešan rezultat ili `PGRST100` koji ekran pokaže kao „ne mogu učitati".
library;

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';

String uzorak(String izraz) => StaffCustomerRepository.uzorakZaTest(izraz);

void main() {
  group('pretraga gradi izraz koji se ne da razbiti', () {
    test('obično ime pogađa i po imenu i po telefonu', () {
      expect(uzorak('Haris'), 'name.ilike.*Haris*,phone.ilike.*Haris*');
    });

    test('zarez ne postaje drugi uslov', () {
      // `or=(...)` razdvaja uslove zarezom: bez čišćenja bi „Delić, Haris" postao dva
      // uslova i upit bi vratio redove koje pretraga nije tražila.
      expect(uzorak('Delić, Haris').split(',').length, 2);
      expect(uzorak('Delić, Haris'), contains('Delić  Haris'));
    });

    test('zagrade ne zatvaraju izraz prerano', () {
      expect(uzorak('Haris (šef)'), isNot(contains('(')));
      expect(uzorak('Haris (šef)'), isNot(contains(')')));
    });

    test('navodnik se uklanja, jer citira operand', () {
      // Neuparen navodnik obara izraz sa `PGRST100`, a uparen mijenja parsiranje
      // operanda — oboje daje pogrešan rezultat dok čovjek samo kuca ime.
      expect(uzorak('Haris "Hari"'), isNot(contains('"')));
    });

    test('like džokeri iz unosa se brišu', () {
      // `_` bi pogodio bilo koji znak, pa bi pretraga izgledala kao da vraća nasumične
      // ljude; `%` bi pogodio sve.
      expect(uzorak('ha_is'), 'name.ilike.*hais*,phone.ilike.*hais*');
      expect(uzorak('100%'), 'name.ilike.*100*,phone.ilike.*100*');
      expect(uzorak(r'a\b'), 'name.ilike.*ab*,phone.ilike.*ab*');
    });

    test('unos koji se sav očisti ne pogađa nikoga', () {
      // Ovo je razlika koja se lako promaši: `*%*` bi vratio **cijeli adresar** čovjeku
      // koji je ukucao samo zareze. Prazan uzorak mora vratiti praznu listu.
      expect(uzorak(',,,'), 'name.eq.,phone.eq.');
      expect(uzorak('%%%'), 'name.eq.,phone.eq.');
      expect(uzorak('   '), 'name.eq.,phone.eq.');
    });

    test('broj telefona sa razmacima ostaje upotrebljiv', () {
      expect(uzorak('061 552 104'), contains('phone.ilike.*061 552 104*'));
    });
  });
}
