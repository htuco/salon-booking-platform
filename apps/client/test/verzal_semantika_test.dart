/// Blizanac `apps/admin/test/verzal_semantika_test.dart` — FE-502.
///
/// Verzal iz `toUpperCase()` čitač ekrana izgovara slovo po slovo, pa svaki mora imati
/// `semanticsLabel`. Klijent i `core_ui` danas nemaju nijedan bez labele; test čuva da
/// tako i ostane. Kopija, ne import: aplikacije ne dijele test kod.
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
    final prijave = prijaveVerzala(['lib', '../../packages/core_ui/lib']);
    expect(
      prijave,
      isEmpty,
      reason: '`toUpperCase()` bez `semanticsLabel`:\n${prijave.join('\n')}',
    );
  });
}
