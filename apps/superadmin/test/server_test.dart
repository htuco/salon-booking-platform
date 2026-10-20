// Sigurnosne provjere servera konzole (ADR-0032 §1): host, token, origin, potvrda projekta.
// Platforma je lažna, pa test ne treba bazu. Mjeri se samo kapija ispred nje.
import 'dart:convert';
import 'dart:io';

import 'package:superadmin/src/okruzenje.dart';
import 'package:superadmin/src/platforma.dart';
import 'package:superadmin/src/repo.dart';
import 'package:superadmin/src/server.dart';
import 'package:test/test.dart';

class _LaznaPlatforma implements Platforma {
  final pozivi = <String>[];

  @override
  Future<List<Map<String, Object?>>> saloni() async => [
    {
      'id': 's1',
      'name': 'Salon',
      'slug': 'salon',
      'city': 'Vitez',
      'status': 'active',
      'plan': 'starter',
      'vertical_pack_key': 'barber',
      'theme': 'modern_barber',
      'primary_color': '#C6A667',
      'secondary_color': '#171717',
      'flavor': 'nemaovogflavora',
      'application_id': 'ba.nasadomena.nemaovogflavora',
      'bundle_id': 'ba.nasadomena.nemaovogflavora',
      'app_display_name': 'Salon',
      'play_store_status': 'draft',
      'app_store_status': 'draft',
      'admin_count': 0,
      'open_owner_invites': 0,
    },
  ];

  @override
  Future<List<Map<String, Object?>>> vertikale() async => [
    {
      'key': 'barber',
      'display_name': 'Barber',
      'default_theme': 'modern_barber',
    },
  ];

  @override
  Future<void> postaviStatus(String salonId, String status) async =>
      pozivi.add('status $salonId $status');

  @override
  Future<Map<String, Object?>> pozivVlasnika(String salonId, String ime) async {
    pozivi.add('poziv $salonId');
    return {'code': 'ABCDEFGHJK', 'expires_at': '2026-10-27T00:00:00Z'};
  }

  @override
  void zatvori() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Konzola konzola;
  late _LaznaPlatforma platforma;
  late HttpClient http;

  Future<Konzola> pokreni(Okruzenje o) async {
    platforma = _LaznaPlatforma();
    final k = Konzola(
      okruzenje: o,
      platforma: platforma,
      repo: Repo.nadji(),
      token: 'tok3n',
    );
    await k.pokreni(port: 0);
    return k;
  }

  Future<(int, Map<String, Object?>)> zahtjev(
    String metoda,
    String putanja, {
    Map<String, String> zaglavlja = const {},
    Object? tijelo,
  }) async {
    final req = await http.openUrl(
      metoda,
      Uri.parse('http://127.0.0.1:${konzola.port}$putanja'),
    );
    zaglavlja.forEach(req.headers.set);
    if (tijelo != null) req.write(jsonEncode(tijelo));
    final res = await req.close();
    final tekst = await res.transform(utf8.decoder).join();
    final json = res.headers.contentType?.mimeType == 'application/json'
        ? Map<String, Object?>.from(jsonDecode(tekst) as Map)
        : <String, Object?>{'html': tekst};
    return (res.statusCode, json);
  }

  setUp(() => http = HttpClient());
  tearDown(() async {
    http.close(force: true);
    await konzola.zaustavi();
  });

  group('lokalno', () {
    setUp(() async {
      konzola = await pokreni(
        Okruzenje(
          url: Uri.parse('http://127.0.0.1:54321'),
          kljuc: 'tajni-kljuc',
          izvor: 'test',
        ),
      );
    });

    test('stranica traži token u adresi', () async {
      expect((await zahtjev('GET', '/')).$1, 403);
      final (status, tijelo) = await zahtjev('GET', '/?t=tok3n');
      expect(status, 200);
      expect(tijelo['html'], contains('<title>Super admin</title>'));
    });

    test('API bez tokena ili sa pogrešnim je 403', () async {
      expect((await zahtjev('GET', '/api/stanje')).$1, 403);
      expect(
        (await zahtjev(
          'GET',
          '/api/stanje',
          zaglavlja: {'x-konzola-token': 'tok3m'},
        )).$1,
        403,
      );
    });

    test('tuđi Host (DNS rebinding) je 403 i sa tokenom', () async {
      final (status, _) = await zahtjev(
        'GET',
        '/api/stanje',
        zaglavlja: {
          'x-konzola-token': 'tok3n',
          'host': 'napadac.example:${konzola.port}',
        },
      );
      expect(status, 403);
    });

    test('tuđi Origin je 403 i ne dira bazu', () async {
      final (status, _) = await zahtjev(
        'POST',
        '/api/saloni/s1/status',
        zaglavlja: {
          'x-konzola-token': 'tok3n',
          'origin': 'https://napadac.example',
        },
        tijelo: {'status': 'inactive'},
      );
      expect(status, 403);
      expect(platforma.pozivi, isEmpty);
    });

    test('stanje ne nosi ključ, a nosi fajl i CI za svaki salon', () async {
      final (status, tijelo) = await zahtjev(
        'GET',
        '/api/stanje',
        zaglavlja: {'x-konzola-token': 'tok3n'},
      );
      expect(status, 200);
      expect(jsonEncode(tijelo), isNot(contains('tajni-kljuc')));
      final salon = (tijelo['saloni']! as List).single as Map;
      expect(salon['tenant'], {'postoji': false});
      expect((salon['ci'] as Map)['build-flavors'], isFalse);
      // Svi tenanti iz repoa su „samo fajl", jer lažna baza ima samo jedan salon.
      expect((tijelo['samoFajl']! as List), isNotEmpty);
    });

    test('lokalni upis ne traži potvrdu', () async {
      final (status, _) = await zahtjev(
        'POST',
        '/api/saloni/s1/status',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: {'status': 'inactive'},
      );
      expect(status, 200);
      expect(platforma.pozivi, ['status s1 inactive']);
    });

    test('poruka vlasniku nosi kod i tačan naziv dugmeta', () async {
      final (status, tijelo) = await zahtjev(
        'POST',
        '/api/saloni/s1/poziv',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: {'ime': 'Elma'},
      );
      expect(status, 200);
      expect(tijelo['kod'], 'ABCDEFGHJK');
      expect(tijelo['poruka'], contains('„Imam poziv od salona"'));
      expect(tijelo['poruka'], contains('Kod: ABCDEFGHJK'));
    });

    test('novi salon za flavor čiji folder postoji ne dira bazu', () async {
      final (status, tijelo) = await zahtjev(
        'POST',
        '/api/saloni',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: {
          'naziv': 'X',
          'grad': 'Y',
          'vertikala': 'barber',
          'primarna': '#000000',
          'sekundarna': '#FFFFFF',
          'flavor': 'amkobarber',
          'slug': 'x',
          'imeAplikacije': 'X',
        },
      );
      expect(status, 409);
      expect(tijelo['greska'], contains('tenants/amkobarber'));
      expect(platforma.pozivi, isEmpty);
    });
  });

  group('hostovani projekat', () {
    setUp(() async {
      konzola = await pokreni(
        Okruzenje(
          url: Uri.parse('https://abcd1234.supabase.co'),
          kljuc: 'k',
          izvor: '.env.prod',
        ),
      );
    });

    test('upis bez potvrde ili sa pogrešnom je 428 i ne dira bazu', () async {
      for (final potvrda in [null, 'lokalno', 'ABCD1234']) {
        final (status, _) = await zahtjev(
          'POST',
          '/api/saloni/s1/status',
          zaglavlja: {'x-konzola-token': 'tok3n', 'x-potvrda': ?potvrda},
          tijelo: {'status': 'inactive'},
        );
        expect(status, 428, reason: 'potvrda: $potvrda');
      }
      expect(platforma.pozivi, isEmpty);
    });

    test('upis sa imenom projekta prolazi; čitanje ne traži potvrdu', () async {
      final (status, _) = await zahtjev(
        'POST',
        '/api/saloni/s1/status',
        zaglavlja: {'x-konzola-token': 'tok3n', 'x-potvrda': 'abcd1234'},
        tijelo: {'status': 'inactive'},
      );
      expect(status, 200);
      expect(
        (await zahtjev(
          'GET',
          '/api/stanje',
          zaglavlja: {'x-konzola-token': 'tok3n'},
        )).$1,
        200,
      );
    });
  });
}
