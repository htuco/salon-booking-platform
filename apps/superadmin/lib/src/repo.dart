/// Fajlovi i generatori u repou: `tenants/`, CI matrica, `tool/gen_*.dart`.
///
/// Generisane fajlove konzola ne piše sama. Pokreće iste generatore koje developer pokreće
/// rukom, pa izlaz ostaje isti kao bez konzole, a `gen_flavors.dart --check` ostaje zelen.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'ci_matrica.dart';
import 'tenant_fajl.dart';

class Repo {
  Repo(this.korijen);

  /// Prvi roditelj sa `pubspec.yaml` i `tenants/`, isto kao `tool/gen_flavors.dart`.
  factory Repo.nadji([Directory? od]) {
    var dir = (od ?? Directory.current).absolute;
    while (!File('${dir.path}/pubspec.yaml').existsSync() ||
        !Directory('${dir.path}/tenants').existsSync()) {
      final roditelj = dir.parent;
      if (roditelj.path == dir.path) {
        throw StateError(
          'Ne mogu naći korijen repoa (pubspec.yaml + tenants/).',
        );
      }
      dir = roditelj;
    }
    return Repo(dir);
  }

  final Directory korijen;

  File tenantYaml(String flavor) =>
      File('${korijen.path}/tenants/$flavor/tenant.yaml');
  File ikona(String flavor) =>
      File('${korijen.path}/tenants/$flavor/assets/icon.png');

  /// Svi tenanti na disku, po flavoru. `_template` se preskače, kao u generatoru.
  Map<String, TenantNaDisku> tenanti() {
    final rezultat = <String, TenantNaDisku>{};
    final dir = Directory('${korijen.path}/tenants');
    for (final d in dir.listSync().whereType<Directory>()) {
      final ime = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (ime.startsWith('_')) continue;
      final f = File('${d.path}/tenant.yaml');
      if (!f.existsSync()) continue;
      try {
        rezultat[ime] = TenantNaDisku.procitaj(f.readAsStringSync());
      } on Object {
        // Pokvaren fajl je posao generatora da prijavi. Konzola ga pokazuje kao „nema fajla".
      }
    }
    return rezultat;
  }

  Map<String, Set<String>> ciMatrice() {
    final f = File('${korijen.path}/.github/workflows/flutter-build.yml');
    if (!f.existsSync()) return {for (final j in ciJobovi.keys) j: <String>{}};
    return flavoriUMatricama(f.readAsStringSync());
  }

  /// `gen_flavors.dart`, pa placeholder ikona (ne dira postojeću), pa `flutter_launcher_icons`.
  /// Staje na prvom koraku koji padne, jer svaki sljedeći čita izlaz prethodnog.
  Future<List<Korak>> generisi() async {
    final koraci = <Korak>[];
    for (final (naziv, izvrsni, argumenti, folder) in [
      (
        'gen_flavors.dart',
        'dart',
        ['run', 'tool/gen_flavors.dart'],
        korijen.path,
      ),
      (
        'Placeholder ikona',
        'dart',
        ['run', 'tool/gen_placeholder_icons.dart'],
        korijen.path,
      ),
      (
        'flutter_launcher_icons',
        'dart',
        ['run', 'flutter_launcher_icons'],
        '${korijen.path}/apps/client',
      ),
    ]) {
      // `flutter_launcher_icons` za svaki iOS flavor tekstualno upiše
      // `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` u `project.pbxproj`, i to
      // ime zadnjeg flavora u svaku konfiguraciju. pbxproj je izlaz `gen_ios_flavors.rb`, pa se
      // vraća kakav je bio. Sa `-f <jedan fajl>` alat ne zna za flavor i piše u glavni `res/`.
      final pbxproj = File(
        '${korijen.path}/apps/client/ios/Runner.xcodeproj/project.pbxproj',
      );
      final prije = naziv == 'flutter_launcher_icons' && pbxproj.existsSync()
          ? pbxproj.readAsBytesSync()
          : null;
      var korak = await _pokreni(naziv, izvrsni, argumenti, folder);
      if (prije != null && !_isti(prije, pbxproj.readAsBytesSync())) {
        pbxproj.writeAsBytesSync(prije);
        korak = Korak(
          naziv,
          uspjeh: korak.uspjeh,
          izlaz:
              '${korak.izlaz}\n\nproject.pbxproj vraćen: alat ga je prepisao, a vlasnik je gen_ios_flavors.rb.',
        );
      }
      koraci.add(korak);
      if (!korak.uspjeh) break;
    }
    return koraci;
  }

  bool _isti(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Korak> samoGenFlavors() => _pokreni('gen_flavors.dart', 'dart', [
    'run',
    'tool/gen_flavors.dart',
  ], korijen.path);

  Future<Korak> _pokreni(
    String naziv,
    String izvrsni,
    List<String> argumenti,
    String folder,
  ) async {
    try {
      final r = await Process.run(
        izvrsni,
        argumenti,
        workingDirectory: folder,
        // Na Windowsu je `dart` često `dart.bat` na PATH-u, a bez shella se ne nađe.
        runInShell: Platform.isWindows,
        // Dart alati pišu UTF-8. Podrazumijevani `systemEncoding` na Windowsu je codepage, pa
        // bi „•" i „ć" stigli kao „â€¢".
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final izlaz = '${r.stdout}${r.stderr}'.trim();
      return Korak(naziv, uspjeh: r.exitCode == 0, izlaz: _rep(izlaz));
    } on ProcessException catch (e) {
      return Korak(naziv, uspjeh: false, izlaz: e.message);
    }
  }

  /// Zadnjih 40 linija. Cijeli izlaz `flutter_launcher_icons` je stotine linija.
  String _rep(String izlaz) {
    final linije = izlaz.split('\n');
    return linije.length <= 40
        ? izlaz
        : linije.sublist(linije.length - 40).join('\n');
  }
}

class Korak {
  const Korak(this.naziv, {required this.uspjeh, required this.izlaz});
  final String naziv;
  final bool uspjeh;
  final String izlaz;

  Map<String, Object?> get json => {
    'naziv': naziv,
    'uspjeh': uspjeh,
    'izlaz': izlaz,
  };
}

/// Ikona aplikacije mora biti kvadratni PNG od najmanje 1024 px (App Store traži 1024×1024).
/// Vraća poruku greške ili `null`. Čita samo IHDR zaglavlje, bez dekodiranja slike.
String? provjeriIkonu(Uint8List bajtovi) {
  const potpis = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bajtovi.length < 24) return 'Ikona nije PNG.';
  for (var i = 0; i < potpis.length; i++) {
    if (bajtovi[i] != potpis[i]) return 'Ikona nije PNG.';
  }
  final podaci = ByteData.sublistView(bajtovi);
  final sirina = podaci.getUint32(16);
  final visina = podaci.getUint32(20);
  if (sirina != visina) {
    return 'Ikona mora biti kvadratna (sada $sirina×$visina).';
  }
  if (sirina < 1024) {
    return 'Ikona mora imati bar 1024×1024 px (sada $sirina×$visina).';
  }
  return null;
}
