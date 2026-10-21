// Sigurnosne provjere servera konzole (ADR-0032 §1): host, token, origin, potvrda projekta,
// i akcije koje ne trebaju bazu da bi se izmjerile (upis iz fajla, poziv, generatori, ikona).
// Platforma je lažna, pa test ne treba bazu; pravila baze mjeri pgTAP `034`.
import 'dart:convert';
import 'dart:io';

import 'package:superadmin/src/okruzenje.dart';
import 'package:superadmin/src/platforma.dart';
import 'package:superadmin/src/repo.dart';
import 'package:superadmin/src/server.dart';
import 'package:superadmin/src/tenant_fajl.dart';
import 'package:test/test.dart';

class _LaznaPlatforma implements Platforma {
  final pozivi = <String>[];
  final napravljeni = <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> saloni() async => [
    for (final n in napravljeni)
      {
        'id': n['p_id'] ?? 'novi',
        'name': n['p_name'],
        'slug': n['p_slug'],
        'city': n['p_city'],
        'status': 'active',
        'plan': 'starter',
        'vertical_pack_key': n['p_vertical'],
        'theme': n['p_theme'] ?? 'modern_barber',
        'primary_color': n['p_primary_color'],
        'secondary_color': n['p_secondary_color'],
        'flavor': n['p_flavor'],
        'application_id': n['p_application_id'],
        'bundle_id': n['p_bundle_id'],
        'app_display_name': n['p_display_name'],
      },
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
  Future<List<String>> teme() async => ['modern_barber', 'elegant_beauty'];

  @override
  Future<String> napraviSalon(Map<String, Object?> polja) async {
    pozivi.add('napravi ${polja['p_flavor']}');
    napravljeni.add(polja);
    return '${polja['p_id'] ?? 'novi'}';
  }

  @override
  Future<void> postaviStatus(String salonId, String status) async =>
      pozivi.add('status $salonId $status');

  @override
  Future<void> povuciPoziv(String salonId, String pozivId) async =>
      pozivi.add('povuci $salonId $pozivId');

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

/// Repo u temp folderu: generatori se samo bilježe (pravi traju i pišu po `apps/client`).
class _LazniRepo extends Repo {
  _LazniRepo(super.korijen, {this.pokvarenaIkona = false});

  final bool pokvarenaIkona;
  var generisano = 0;

  @override
  Future<List<Korak>> generisi() async {
    generisano++;
    return [const Korak('gen_flavors.dart', uspjeh: true, izlaz: 'lažno')];
  }

  /// Ikona ispod običnog fajla: `createSync` roditelja pada kao što bi pao pun disk ili
  /// zaključan folder na Windowsu.
  @override
  File ikona(String flavor) => pokvarenaIkona
      ? File('${korijen.path}/blokada/assets/icon.png')
      : super.ikona(flavor);
}

const _lokalno = 'http://127.0.0.1:54321';

void main() {
  late Konzola konzola;
  late _LaznaPlatforma platforma;
  late HttpClient http;

  Future<Konzola> pokreni(Okruzenje o, {Repo? repo}) async {
    platforma = _LaznaPlatforma();
    final k = Konzola(
      okruzenje: o,
      platforma: platforma,
      repo: repo ?? Repo.nadji(),
      token: 'tok3n',
    );
    await k.pokreni(port: 0);
    return k;
  }

  Okruzenje lokalnoOkruzenje() =>
      Okruzenje(url: Uri.parse(_lokalno), kljuc: 'tajni-kljuc', izvor: 'test');

  /// Prazan repo u temp folderu: `pubspec.yaml` i `tenants/`, kao što `Repo.nadji` traži.
  Directory tempRepo() {
    final d = Directory.systemTemp.createTempSync('superadmin_test_');
    File('${d.path}/pubspec.yaml').writeAsStringSync('name: x\n');
    Directory('${d.path}/tenants').createSync();
    addTearDown(() => d.deleteSync(recursive: true));
    return d;
  }

  List<String> sadrzaj(Directory d) =>
      d
          .listSync(recursive: true)
          .map((e) => e.path.substring(d.path.length))
          .toList()
        ..sort();

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
      konzola = await pokreni(lokalnoOkruzenje());
    });

    test('stranica se daje i bez tokena (F5), a u njoj nema tokena', () async {
      for (final putanja in ['/', '/?t=tok3n']) {
        final (status, tijelo) = await zahtjev('GET', putanja);
        expect(status, 200, reason: putanja);
        expect(tijelo['html'], contains('<title>Super admin</title>'));
        expect(tijelo['html'], isNot(contains('tok3n')));
      }
      // Stranica bez tokena ne otvara API.
      final (status, tijelo) = await zahtjev('GET', '/api/stanje');
      expect(status, 403);
      expect(tijelo['greska'], contains('adresu'));
    });

    test('stranica bez tokena i dalje odbija tuđi Host', () async {
      final (status, _) = await zahtjev(
        'GET',
        '/',
        zaglavlja: {'host': 'napadac.example:${konzola.port}'},
      );
      expect(status, 403);
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
      // Teme dolaze iz baze, ne iz konzole.
      expect(tijelo['teme'], ['modern_barber', 'elegant_beauty']);
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

    test('povlačenje poziva ide u bazu sa id-em poziva', () async {
      final (status, _) = await zahtjev(
        'POST',
        '/api/saloni/s1/povuci-poziv',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: {'poziv': 'p1'},
      );
      expect(status, 200);
      expect(platforma.pozivi, ['povuci s1 p1']);
      final (bez, _) = await zahtjev(
        'POST',
        '/api/saloni/s1/povuci-poziv',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: <String, Object?>{},
      );
      expect(bez, 400);
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

  group('temp repo', () {
    late Directory dir;
    late _LazniRepo repo;

    Future<void> start({bool pokvarenaIkona = false}) async {
      dir = tempRepo();
      repo = _LazniRepo(dir, pokvarenaIkona: pokvarenaIkona);
      konzola = await pokreni(lokalnoOkruzenje(), repo: repo);
    }

    test(
      'upis iz tenant.yaml: isti UUID i polja iz fajla, fajl se ne dira',
      () async {
        await start();
        final fajl = File('${dir.path}/tenants/studiolejla/tenant.yaml')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            napisiTenantYaml(
              const NoviTenant(
                salonId: '0b9c2a51-7f3e-4c1d-9a8b-2e6f4d3c1b0a',
                flavor: 'studiolejla',
                slug: 'studio-lejla',
                vertical: 'beauty',
                naziv: 'Studio Lejla (Centar)',
                grad: 'Zenica',
                imeAplikacije: 'Lejla',
                applicationId: 'ba.nasadomena.studiolejla',
                bundleId: 'ba.nasadomena.studiolejla',
                primarna: '#b07d62',
                sekundarna: '#f7efe8',
                tema: 'elegant_beauty',
                ios: false,
              ),
            ),
          );
        final prije = fajl.readAsStringSync();
        final stablo = sadrzaj(dir);

        // Lista ga nudi kao „samo fajl", sa nazivom i gradom iz komentara.
        final (_, stanje) = await zahtjev(
          'GET',
          '/api/stanje',
          zaglavlja: {'x-konzola-token': 'tok3n'},
        );
        final samo = (stanje['samoFajl']! as List).single as Map;
        expect(samo['naziv'], 'Studio Lejla (Centar)');
        expect(samo['grad'], 'Zenica');

        final (status, tijelo) = await zahtjev(
          'POST',
          '/api/tenanti/studiolejla/upisi',
          zaglavlja: {'x-konzola-token': 'tok3n'},
          tijelo: {'grad': 'Zenica', 'plan': 'pro'},
        );
        expect(status, 200, reason: '$tijelo');
        expect(tijelo['id'], '0b9c2a51-7f3e-4c1d-9a8b-2e6f4d3c1b0a');
        expect(platforma.napravljeni.single, {
          'p_name': 'Studio Lejla (Centar)',
          'p_slug': 'studio-lejla',
          'p_city': 'Zenica',
          'p_vertical': 'beauty',
          'p_theme': 'elegant_beauty',
          'p_primary_color': '#B07D62',
          'p_secondary_color': '#F7EFE8',
          'p_flavor': 'studiolejla',
          'p_application_id': 'ba.nasadomena.studiolejla',
          'p_bundle_id': 'ba.nasadomena.studiolejla',
          'p_display_name': 'Lejla',
          'p_plan': 'pro',
          'p_id': '0b9c2a51-7f3e-4c1d-9a8b-2e6f4d3c1b0a',
        });
        expect(fajl.readAsStringSync(), prije);
        expect(sadrzaj(dir), stablo);
        expect(repo.generisano, 0);
      },
    );

    test(
      'upis iz fajla: nema fajla je 404, fajl bez grada traži grad',
      () async {
        await start();
        expect(
          (await zahtjev(
            'POST',
            '/api/tenanti/nema/upisi',
            zaglavlja: {'x-konzola-token': 'tok3n'},
            tijelo: <String, Object?>{},
          )).$1,
          404,
        );
        File('${dir.path}/tenants/demo/tenant.yaml')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            '# Demo tenant — bez grada.\ntenant:\n  flavor: demo\n'
            '  salonId: 550e8400-e29b-41d4-a716-446655440000\n  slug: demo\n'
            '  vertical: barber\napp:\n  displayName: "Demo"\n'
            '  applicationId: ba.nasadomena.demo\n  bundleId: ba.nasadomena.demo\n',
          );
        final (status, tijelo) = await zahtjev(
          'POST',
          '/api/tenanti/demo/upisi',
          zaglavlja: {'x-konzola-token': 'tok3n'},
          tijelo: <String, Object?>{},
        );
        expect(status, 400);
        expect(tijelo['greska'], contains('Grad'));
        expect(platforma.napravljeni, isEmpty);
        // Sa gradom prolazi; boje i tema bez `branding` bloka su defaulti generatora.
        final (ok, _) = await zahtjev(
          'POST',
          '/api/tenanti/demo/upisi',
          zaglavlja: {'x-konzola-token': 'tok3n'},
          tijelo: {'grad': 'Vitez'},
        );
        expect(ok, 200);
        expect(platforma.napravljeni.single['p_name'], 'Demo');
        expect(platforma.napravljeni.single['p_primary_color'], '#C6A667');
        expect(platforma.napravljeni.single['p_theme'], 'modern_barber');
      },
    );

    test('pad ikone je svoj korak; generatori se ne pokreću', () async {
      await start(pokvarenaIkona: true);
      File('${dir.path}/blokada').writeAsStringSync('fajl, ne folder');
      final (status, tijelo) = await zahtjev(
        'POST',
        '/api/saloni',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: {
          'naziv': 'Novi',
          'grad': 'Vitez',
          'vertikala': 'barber',
          'primarna': '#000000',
          'sekundarna': '#FFFFFF',
          'flavor': 'novisalon',
          'slug': 'novi-salon',
          'imeAplikacije': 'Novi',
          'ikona': base64Encode(_png(1024)),
        },
      );
      expect(status, 200);
      final koraci = [
        for (final k in tijelo['koraci']! as List)
          '${(k as Map)['naziv']}:${k['uspjeh']}',
      ];
      expect(koraci, ['tenant.yaml:true', 'Ikona:false']);
      expect(repo.generisano, 0);
      expect(
        File('${dir.path}/tenants/novisalon/tenant.yaml').existsSync(),
        isTrue,
      );

      // Fajl postoji, pa „Napiši tenant.yaml" odbija, a „Ponovi generatore" nastavlja.
      final (napisi, _) = await zahtjev(
        'POST',
        '/api/saloni/novi/tenant',
        zaglavlja: {'x-konzola-token': 'tok3n'},
        tijelo: <String, Object?>{},
      );
      expect(napisi, 409);
      final (gen, genTijelo) = await zahtjev(
        'POST',
        '/api/saloni/novi/generatori',
        zaglavlja: {'x-konzola-token': 'tok3n'},
      );
      expect(gen, 200);
      expect((genTijelo['koraci']! as List), hasLength(1));
      expect(repo.generisano, 1);
    });

    test('ponovi generatore bez tenant.yaml je 409', () async {
      await start();
      final (status, tijelo) = await zahtjev(
        'POST',
        '/api/saloni/s1/generatori',
        zaglavlja: {'x-konzola-token': 'tok3n'},
      );
      expect(status, 409);
      expect(tijelo['greska'], contains('Napiši tenant.yaml'));
      expect(repo.generisano, 0);
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

/// Najmanji PNG zaglavlja koje `provjeriIkonu` čita: potpis i IHDR sa širinom i visinom.
List<int> _png(int strana) => [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // potpis
  0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, // IHDR
  for (var i = 0; i < 2; i++) ...[
    (strana >> 24) & 0xff,
    (strana >> 16) & 0xff,
    (strana >> 8) & 0xff,
    strana & 0xff,
  ],
];
