import 'dart:io';

import 'package:superadmin/src/ci_matrica.dart';
import 'package:superadmin/src/okruzenje.dart';
import 'package:test/test.dart';

void main() {
  group('flavoriUMatricama', () {
    test('čita oba oblika matrice iz pravog workflowa', () {
      final m = flavoriUMatricama(
        File('../../.github/workflows/flutter-build.yml').readAsStringSync(),
      );
      expect(m.keys, containsAll(ciJobovi.keys));
      // Svaki tenant iz repoa je danas u sve tri matrice. Ako ovo padne, ili je matrica
      // promijenila oblik (pa konzola laže), ili je neko zaboravio korak 7.
      final tenanti = Directory('../../tenants')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .where((n) => !n.startsWith('_'))
          .toSet();
      for (final job in ciJobovi.keys) {
        expect(m[job], containsAll(tenanti), reason: job);
      }
    });

    test('job koji fali daje prazan skup', () {
      final m = flavoriUMatricama('jobs:\n  build-flavors:\n    runs-on: x\n');
      expect(m['build-flavors'], isEmpty);
      expect(m['release-artifacts'], isEmpty);
    });
  });

  group('Okruzenje', () {
    test('iz supabase status uzima API_URL i service ključ', () {
      final o = Okruzenje.izStatusa(
        '{"API_URL":"http://127.0.0.1:54321","SERVICE_ROLE_KEY":"tajna","ANON_KEY":"x"}',
      );
      expect(o.url.port, 54321);
      expect(o.lokalno, isTrue);
      expect(o.projekat, 'lokalno');
      expect(o.toString(), isNot(contains('tajna')));
    });

    test('zaustavljen stack daje razumljivu grešku', () {
      expect(
        () => Okruzenje.izStatusa('failed to inspect container'),
        throwsA(isA<OkruzenjeGreska>()),
      );
      expect(() => Okruzenje.izStatusa('{}'), throwsA(isA<OkruzenjeGreska>()));
    });

    test('env fajl: navodnici, komentari, ime projekta iz hosta', () {
      final o = Okruzenje.izEnvFajla(
        '# komentar\nSUPABASE_URL="https://abcd1234.supabase.co"\nSUPABASE_SERVICE_ROLE_KEY=\'k\'\n',
        ime: '.env.prod',
      );
      expect(o.lokalno, isFalse);
      expect(o.projekat, 'abcd1234');
      expect(o.kljuc, 'k');
      expect(o.izvor, '.env.prod');
    });

    test('ime projekta: ref za *.supabase.co, cijeli host za custom domen', () {
      Okruzenje o(String url) =>
          Okruzenje(url: Uri.parse(url), kljuc: 'k', izvor: 't');
      expect(o('https://AbCd1234.supabase.co').projekat, 'abcd1234');
      expect(o('https://api.salon.ba').projekat, 'api.salon.ba');
      expect(
        o('https://api.supabase.co.evil.ba').projekat,
        'api.supabase.co.evil.ba',
      );
      expect(o('https://a.b.supabase.co').projekat, 'a.b.supabase.co');
      expect(o('http://localhost:54321').projekat, 'lokalno');
    });

    test('env fajl bez service ključa pada (kao .env.live danas)', () {
      expect(
        () => Okruzenje.izEnvFajla(
          'SUPABASE_URL=https://a.supabase.co\nSUPABASE_ANON_KEY=x\n',
          ime: '.env.live',
        ),
        throwsA(isA<OkruzenjeGreska>()),
      );
    });
  });
}
