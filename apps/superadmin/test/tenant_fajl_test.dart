import 'dart:io';
import 'dart:typed_data';

import 'package:superadmin/src/repo.dart';
import 'package:superadmin/src/tenant_fajl.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _novi = NoviTenant(
  salonId: '0b9c2a51-7f3e-4c1d-9a8b-2e6f4d3c1b0a',
  flavor: 'studiolejla',
  slug: 'studio-lejla',
  vertical: 'beauty',
  naziv: 'Studio: Lejla #1',
  grad: 'Zenica',
  imeAplikacije: 'Studio "Lejla"',
  applicationId: 'ba.nasadomena.studiolejla',
  bundleId: 'ba.nasadomena.studiolejla',
  primarna: '#b07d62',
  sekundarna: '#f7efe8',
  tema: 'elegant_beauty',
  ios: false,
);

void main() {
  group('napisiTenantYaml', () {
    test(
      'daje fajl koji generator čita, sa istim UUID-om i bojama kao baza',
      () {
        final yaml = loadYaml(napisiTenantYaml(_novi)) as YamlMap;
        expect(yaml['tenant']['flavor'], 'studiolejla');
        expect(yaml['tenant']['salonId'], _novi.salonId);
        expect(yaml['tenant']['vertical'], 'beauty');
        expect(yaml['app']['displayName'], 'Studio "Lejla"');
        expect(yaml['app']['shortName'], 'Studio');
        expect(yaml['app']['applicationId'], 'ba.nasadomena.studiolejla');
        expect(yaml['branding']['primaryColor'], '#B07D62');
        expect(yaml['branding']['secondaryColor'], '#F7EFE8');
        expect(yaml['branding']['theme'], 'elegant_beauty');
        expect(yaml['targets']['ios'], isFalse);
        expect(yaml['store']['privacyPolicyUrl'], endsWith('/studio-lejla'));
      },
    );

    test('ima sve ključeve kao šablon (generator ne smije dobiti manje)', () {
      final sablon = File('../../tenants/_template/tenant.yaml');
      final ocekivano = loadYaml(sablon.readAsStringSync()) as YamlMap;
      final novi = loadYaml(napisiTenantYaml(_novi)) as YamlMap;
      for (final blok in ocekivano.keys) {
        expect(novi.containsKey(blok), isTrue, reason: 'fali blok $blok');
        final dio = ocekivano[blok];
        if (dio is YamlMap) {
          for (final k in dio.keys) {
            expect(
              (novi[blok] as YamlMap).containsKey(k),
              isTrue,
              reason: 'fali $blok.$k',
            );
          }
        }
      }
    });

    test('TenantNaDisku čita ono što je napisano', () {
      final t = TenantNaDisku.procitaj(napisiTenantYaml(_novi));
      expect(t.salonId, _novi.salonId);
      expect(t.primarna, '#B07D62');
      expect(t.tema, 'elegant_beauty');
      expect(t.imeAplikacije, 'Studio "Lejla"');
    });
  });

  group('zamijeniBranding', () {
    const fajl = '''
# Komentar koji mora ostati.
tenant:
  flavor: x
  salonId: 00000000-0000-0000-0000-000000000000

app:
  displayName: "X"

branding:
  # Fallback boje — ovaj komentar ostaje.
  primaryColor: "#C6A667"
  secondaryColor: "#171717"
  splashBackground: "#171717"
  theme: modern_barber

targets:
  android: true
  ios: true
''';

    test('mijenja samo tri ključa, komentari i ostalo ostaju', () {
      final novi = zamijeniBranding(
        fajl,
        primarna: '#8a5a44',
        sekundarna: '#f2e8dc',
        tema: 'warm_wellness',
      );
      expect(novi, contains('# Komentar koji mora ostati.'));
      expect(novi, contains('# Fallback boje — ovaj komentar ostaje.'));
      expect(novi, contains('  primaryColor: "#8A5A44"'));
      expect(novi, contains('  secondaryColor: "#F2E8DC"'));
      expect(novi, contains('  theme: warm_wellness'));
      expect(novi.split('\n').length, fajl.split('\n').length);
      expect(
        novi.replaceAll(RegExp(r'branding:[\s\S]*?\n\n'), ''),
        fajl.replaceAll(RegExp(r'branding:[\s\S]*?\n\n'), ''),
      );
    });

    test('splash prati sekundarnu boju samo kad je bio isti kao ona', () {
      final prati = zamijeniBranding(
        fajl,
        primarna: '#000000',
        sekundarna: '#FFFFFF',
        tema: 'modern_barber',
      );
      expect(prati, contains('splashBackground: "#FFFFFF"'));

      final namjerno = fajl.replaceFirst(
        'splashBackground: "#171717"',
        'splashBackground: "#222222"',
      );
      final ostaje = zamijeniBranding(
        namjerno,
        primarna: '#000000',
        sekundarna: '#FFFFFF',
        tema: 'modern_barber',
      );
      expect(ostaje, contains('splashBackground: "#222222"'));
    });

    test('ne dira isti ključ izvan branding bloka', () {
      final drugi = '$fajl\nnesto:\n  theme: ne_diraj\n';
      final novi = zamijeniBranding(
        drugi,
        primarna: '#000000',
        sekundarna: '#FFFFFF',
        tema: 'clinical_calm',
      );
      expect(novi, contains('  theme: ne_diraj'));
      expect(novi, contains('  theme: clinical_calm'));
    });

    test('fajl bez ključa pada, ne preskače tiho', () {
      final bezTeme = fajl.replaceFirst('  theme: modern_barber\n', '');
      expect(
        () => zamijeniBranding(
          bezTeme,
          primarna: '#000000',
          sekundarna: '#FFFFFF',
          tema: 'x',
        ),
        throwsFormatException,
      );
      expect(
        () => zamijeniBranding(
          'tenant:\n  flavor: x\n',
          primarna: '#000000',
          sekundarna: '#FFFFFF',
          tema: 'x',
        ),
        throwsFormatException,
      );
    });

    test('CRLF fajl (Windows checkout) se mijenja i ostaje CRLF', () {
      final crlf = fajl.replaceAll('\n', '\r\n');
      final novi = zamijeniBranding(
        crlf,
        primarna: '#000000',
        sekundarna: '#FFFFFF',
        tema: 'clinical_calm',
      );
      expect(novi, contains('  theme: clinical_calm\r\n'));
      expect(novi.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('pravi tenant iz repoa ostaje validan YAML sa novim bojama', () {
      final pravi = File('../../tenants/authenticbarber/tenant.yaml')
          .readAsStringSync();
      final novi = zamijeniBranding(
        pravi,
        primarna: '#123456',
        sekundarna: '#ABCDEF',
        tema: 'elegant_beauty',
      );
      final t = TenantNaDisku.procitaj(novi);
      expect(t.primarna, '#123456');
      expect(t.sekundarna, '#ABCDEF');
      expect(t.tema, 'elegant_beauty');
      expect(t.salonId, TenantNaDisku.procitaj(pravi).salonId);
    });
  });

  group('provjeriIkonu', () {
    List<int> png(int w, int h) => [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // potpis
      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, // IHDR
      (w >> 24) & 0xff, (w >> 16) & 0xff, (w >> 8) & 0xff, w & 0xff,
      (h >> 24) & 0xff, (h >> 16) & 0xff, (h >> 8) & 0xff, h & 0xff,
    ];

    test('1024×1024 PNG prolazi', () {
      expect(provjeriIkonu(Uint8List.fromList(png(1024, 1024))), isNull);
    });
    test('nekvadratna, mala i ne-PNG padaju', () {
      expect(
        provjeriIkonu(Uint8List.fromList(png(1024, 512))),
        contains('kvadratna'),
      );
      expect(
        provjeriIkonu(Uint8List.fromList(png(512, 512))),
        contains('1024'),
      );
      expect(
        provjeriIkonu(Uint8List.fromList(List.filled(30, 0))),
        contains('PNG'),
      );
    });
    test('prava ikona iz repoa prolazi', () {
      final bajtovi = File('../../tenants/amkobarber/assets/icon.png')
          .readAsBytesSync();
      expect(provjeriIkonu(bajtovi), isNull);
    });
  });
}
