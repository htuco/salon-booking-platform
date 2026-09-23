/// Test koji pada ako verzal iz `toUpperCase()` stigne do čitača ekrana — FE-502.
///
/// `Text('DANAS')` čitač ekrana ne izgovara kao riječ nego slovo po slovo, ili je
/// izgovori kao skraćenicu. Verzal je zato **stil, ne podatak**: izvorni string ostaje u
/// normalnom obliku, velika slova dolaze tek na ekranu, a `semanticsLabel` vraća riječ.
/// `AdminVerzal` to radi u jednom redu; ovaj test hvata mjesta koja ga zaobiđu.
///
/// Svaki `toUpperCase()` mora imati `semanticsLabel` u istom izrazu (do četiri reda
/// ispod). Izuzeci su napisani, ne prećutani:
/// - **inicijal** — jedno slovo (`characters.first`, `[0]`, `substring(0, 1)`) je
///   podatak i tako se i čita;
/// - `// verzal-ok: <razlog>` do dva reda iznad — npr. skraćenica koja se i treba sricati, ili
///   tekst koji je već pod `ExcludeSemantics`-om sa punom labelom.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _inicijal = RegExp(
  r'(characters\.first|\[0\]|substring\(0, 1\))\s*\.toUpperCase\(\)',
);

/// Prijave za sve `.dart` fajlove ispod [korijeni].
List<String> prijaveVerzala(List<String> korijeni) {
  final prijave = <String>[];
  for (final korijen in korijeni) {
    for (final fajl in Directory(korijen).listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final putanja = fajl.path.replaceAll(r'\', '/');
      if (putanja.contains('/generated/')) continue;

      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final linija = linije[i];
        final ocisceno = linija.trim();
        if (ocisceno.startsWith('//')) continue;
        if (!linija.contains('.toUpperCase()')) continue;
        if (_inicijal.hasMatch(linija)) continue;
        // Izuzetak važi za izraz koji počinje do dva reda iznad (`return (…)` pa
        // `.toUpperCase()` u sljedećem redu).
        final iznad = linije.sublist((i - 2).clamp(0, i), i);
        if (iznad.any((l) => l.contains('verzal-ok:'))) continue;

        // Komentari se ne broje: riječ `semanticsLabel` u komentaru nije labela.
        final izraz = linije
            .sublist(i, (i + 5).clamp(0, linije.length))
            .where((l) => !l.trim().startsWith('//'))
            .join();
        if (izraz.contains('semanticsLabel')) continue;

        prijave.add('$putanja:${i + 1}: $ocisceno');
      }
    }
  }
  return prijave;
}

void main() {
  test('verzal nikad ne stiže do čitača ekrana kao slova', () {
    final prijave = prijaveVerzala(['lib']);
    expect(
      prijave,
      isEmpty,
      reason:
          '`toUpperCase()` bez `semanticsLabel` — koristi `AdminVerzal` ili dodaj '
          'labelu:\n${prijave.join('\n')}',
    );
  });
}
