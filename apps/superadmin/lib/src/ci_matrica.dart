/// U kojim CI matricama je flavor. `flutter-build.yml` ima tri **eksplicitne** liste
/// (`tenant-factory.md`, korak 7). Tenant koji nije u njima se nikad ne builda na CI-ju, a
/// `gen_flavors.dart --check` to ne vidi.
///
/// Konzola fajl samo čita (ADR-0032). Tri liste imaju tri različita oblika reda, a alat koji
/// bi ih prepisivao bi jednom pogriješio za sve tenante.
library;

import 'package:yaml/yaml.dart';

/// Jobovi koji nose listu flavora, i šta svaki od njih dokazuje.
const ciJobovi = {
  'build-flavors': 'Android APK',
  'build-ios': 'iOS',
  'release-artifacts': 'Release AAB',
};

/// Za svaki job iz [ciJobovi]: skup flavora u njegovoj matrici. Job koji fali u fajlu daje
/// prazan skup, pa konzola kaže „nije u matrici" umjesto da padne.
Map<String, Set<String>> flavoriUMatricama(String workflow) {
  final yaml = loadYaml(workflow) as YamlMap;
  final jobs = yaml['jobs'] as YamlMap? ?? YamlMap();
  return {for (final job in ciJobovi.keys) job: _flavori(jobs[job])};
}

Set<String> _flavori(Object? job) {
  if (job is! YamlMap) return {};
  final strategy = job['strategy'];
  if (strategy is! YamlMap) return {};
  final matrix = strategy['matrix'];
  if (matrix is! YamlMap) return {};
  final rezultat = <String>{};
  // Oblik 1: `include: [{flavor: x, ...}]` (build-flavors, build-ios).
  final include = matrix['include'];
  if (include is YamlList) {
    for (final red in include) {
      if (red is YamlMap && red['flavor'] != null) {
        rezultat.add('${red['flavor']}');
      }
    }
  }
  // Oblik 2: `flavor: [x, y]` (release-artifacts).
  final lista = matrix['flavor'];
  if (lista is YamlList) {
    rezultat.addAll(lista.map((f) => '$f'));
  }
  return rezultat;
}
