/// Test koji pada ako radius procuri u ekran kao broj.
///
/// `CLAUDE.md` traži da se generisano i tokenizovano ne prepisuje rukom, a
/// `admin_tokens.dart` nosi sve četiri vrijednosti sistema ([AdminRadius]). Uprkos tome,
/// FE-103 je u ekranima zatekao **sedam** literala — među njima `circular(6)` i
/// `circular(20)`, koji su doslovno `AdminRadius.base` i `AdminRadius.pill` prepisani
/// brojem.
///
/// To je greška koja se ne vidi u pregledu: `circular(6)` izgleda tačno kao token dok se
/// token ne promijeni. Tada se ugao promijeni na 180 mjesta i ostane isti na sedam.
///
/// Zaobilazi se jednim `// ignore` komentarom, ali tada je izuzetak napisan i vidljiv u
/// diffu.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Folder u kojem radius **smije** biti broj.
const String kTemaFolder = 'lib/src/core/theme';

void main() {
  test('nijedan admin ekran ne piše radius kao broj', () {
    // Hvata `circular(6)`, `circular(20.0)`, `Radius.circular(4)` — ali ne
    // `circular(AdminRadius.base)`, jer iza zagrade mora stajati cifra.
    final literal = RegExp(r'[Cc]ircular\(\s*\d');

    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final putanja = fajl.path.replaceAll(r'\', '/');
      if (putanja.contains(kTemaFolder)) continue;

      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final linija = linije[i];
        final ocisceno = linija.trim();
        if (ocisceno.startsWith('//') || ocisceno.startsWith('///')) continue;
        if (linija.contains('// ignore')) continue;
        if (literal.hasMatch(linija)) {
          prijave.add('$putanja:${i + 1} — ${linija.trim()}');
        }
      }
    }

    expect(
      prijave,
      isEmpty,
      reason:
          'Radius se uzima iz `AdminRadius`, ne piše u ekranu. Ako vrijednost '
          'ne postoji u tokenima, dodaje se tamo sa razlogom.\n'
          '${prijave.join('\n')}',
    );
  });
}
