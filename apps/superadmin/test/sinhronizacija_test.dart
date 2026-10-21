// Konzola, generator, baza i `core_ui` drže iste činjenice na više mjesta. Ovaj test pada kad
// se one raziđu, umjesto da se razilaženje vidi tek na jednom tenantu:
//   - podrazumijevane boje i tema kad `tenant.yaml` nema `branding` (konzola vs generator);
//   - rezervisano ime flavora (`test*`, `lint`...) u generatoru, isto kao u bazi;
//   - lista tema (baza `private.known_themes` vs `AppTheme` u `core_ui`).
//
// Generator se pokreće stvarno, u temp repou, sa paketima ovog workspacea.
import 'dart:io';

import 'package:superadmin/src/repo.dart';
import 'package:superadmin/src/tenant_fajl.dart';
import 'package:test/test.dart';

final _korijen = Repo.nadji().korijen.path;

/// Najmanji repo koji `gen_flavors.dart` prihvata: `pubspec.yaml`, `tenants/` i gradle fajl
/// sa markerima. Generator piše samo u ovaj folder.
Directory _tempRepo(Map<String, String> tenanti) {
  final d = Directory.systemTemp.createTempSync('gen_flavors_test_');
  addTearDown(() => d.deleteSync(recursive: true));
  File('${d.path}/pubspec.yaml').writeAsStringSync('name: x\n');
  File('${d.path}/apps/client/android/app/build.gradle.kts')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      'android {\n'
      '    // >>> BEGIN GENERATED FLAVORS\n'
      '    // <<< END GENERATED FLAVORS\n'
      '}\n',
    );
  tenanti.forEach((flavor, yaml) {
    File('${d.path}/tenants/$flavor/tenant.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(yaml);
  });
  return d;
}

Future<ProcessResult> _generator(Directory repo) => Process.run(
  'dart',
  [
    '--packages=$_korijen/.dart_tool/package_config.json',
    '$_korijen/tool/gen_flavors.dart',
  ],
  workingDirectory: repo.path,
  runInShell: Platform.isWindows,
);

String _tenant(String flavor, {String branding = ''}) =>
    '''
tenant:
  flavor: $flavor
  salonId: 0b9c2a51-7f3e-4c1d-9a8b-2e6f4d3c1b0a
  slug: $flavor
  vertical: barber
app:
  displayName: "X"
  applicationId: ba.nasadomena.$flavor
  bundleId: ba.nasadomena.$flavor
  versionName: "1.0.0"
  androidVersionCode: 1
  iosBuildNumber: 1
$branding''';

void main() {
  test('tenant.yaml bez brandinga: konzola čita iste boje i temu koje generator upiše', () async {
    final yaml = _tenant('bezboja');
    final repo = _tempRepo({'bezboja': yaml});
    final r = await _generator(repo);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');

    final registar = File(
      '${repo.path}/apps/client/lib/src/generated/tenants.g.dart',
    ).readAsStringSync();
    String boja(String polje) =>
        '#${RegExp('$polje: 0xFF([0-9A-F]{6})').firstMatch(registar)!.group(1)}';
    final tema = RegExp("themeName: '([a-z_]+)'")
        .firstMatch(registar)!
        .group(1);

    final konzola = TenantNaDisku.procitaj(yaml);
    expect(konzola.primarna, boja('primaryColor'));
    expect(konzola.sekundarna, boja('secondaryColor'));
    expect(konzola.tema, tema);
    expect(boja('primaryColor'), podrazumijevanaPrimarna);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'generator odbija flavor koji Gradle ne prima, za sve tenante',
    () async {
      for (final flavor in ['testsalon', 'lint', 'release']) {
        final repo = _tempRepo({
          'dobar': _tenant('dobar'),
          flavor: _tenant(flavor),
        });
        final r = await _generator(repo);
        expect(r.exitCode, 1, reason: flavor);
        expect('${r.stderr}', contains('Gradle ne prima'), reason: flavor);
        // Ništa nije napisano: generator pada prije prvog fajla.
        expect(
          File('${repo.path}/apps/client/lib/src/generated/tenants.g.dart')
              .existsSync(),
          isFalse,
          reason: flavor,
        );
      }
      // Kontrola: `kontest` i `tefter` nisu rezervisani.
      final repo = _tempRepo({'kontest': _tenant('kontest')});
      expect((await _generator(repo)).exitCode, 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('teme u bazi su tačno teme koje core_ui zna', () {
    final appTheme = File(
      '$_korijen/packages/core_ui/lib/src/theme/app_theme.dart',
    ).readAsStringSync();
    final uCoreUi = RegExp(
      r"^\s+\w+\('([a-z_]+)', Brightness\.\w+\)",
      multiLine: true,
    ).allMatches(appTheme).map((m) => m.group(1)!).toSet();
    expect(uCoreUi, isNotEmpty);

    // Zadnja migracija koja definiše `private.known_themes` je ono što baza danas zna.
    final migracije =
        Directory('$_korijen/supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final definicija = RegExp(
      r'function private\.known_themes\(\)[\s\S]*?array\[([^\]]*)\]',
    );
    Set<String>? uBazi;
    for (final f in migracije) {
      final m = definicija.firstMatch(f.readAsStringSync());
      if (m == null) continue;
      uBazi = RegExp("'([a-z_]+)'")
          .allMatches(m.group(1)!)
          .map((x) => x.group(1)!)
          .toSet();
    }
    expect(uBazi, isNotNull, reason: 'nema private.known_themes u migracijama');
    expect(uBazi, uCoreUi);
  });
}
