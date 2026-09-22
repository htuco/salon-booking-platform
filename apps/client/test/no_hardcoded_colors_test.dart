/// Test koji pada ako boja procuri u klijentski ekran.
///
/// Admin ima svoj ekvivalent (`apps/admin/test/no_hardcoded_colors_test.dart`) i ovaj mu
/// je namjerno blizanac — ali razlog je **jači** ovdje.
///
/// U adminu je hardkodirana boja greška stila: admin je jedan build za sve salone, pa
/// pogrešna boja izgleda pogrešno svima odmah. U klijentu je hardkodirana boja greška
/// koja **prolazi svaki test i svaki pregled**, jer testovi i demo crtaju jedan tenant.
/// Vidi se tek kad drugi salon otvori svoju aplikaciju i ugleda tuđu boju — a tada je
/// već u storeu. Boja klijenta dolazi iz `tenants/<flavor>/tenant.yaml` kroz
/// `buildAppTheme()`, i to je tvrdo pravilo iz `CLAUDE.md`
/// ([ADR-0018](../../docs/adr/0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md)).
///
/// Test je namjerno glup: traži tekst, ne semantiku. Zaobilazi se jednim `// ignore`
/// komentarom, ali tada je izuzetak **napisan i vidljiv u diffu**, što je cijela poenta.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Izrazi koji znače „boja je napisana ovdje, a ne uzeta iz teme".
final List<(RegExp, String)> _zabranjeno = [
  (RegExp(r'Color\(0x'), 'heks boja u ekranu'),
  (RegExp(r'Color\.fromARGB'), 'ARGB boja u ekranu'),
  // `Colors.transparent` je jedini izuzetak: nije boja nego odsustvo boje.
  (RegExp(r'\bColors\.(?!transparent)\w+'), 'Material paleta u ekranu'),
];

void main() {
  test('nijedan klijentski ekran ne piše boju sam', () {
    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final putanja = fajl.path.replaceAll(r'\', '/');
      // Generisani registar tenanata nosi brand boje **kao podatak iz `tenant.yaml`** —
      // to je upravo izvor iz kojeg tema i treba da ih uzme, a fajl se ne piše rukom.
      if (putanja.contains('lib/src/generated/')) continue;
      // Demo ulaz nije production kod: on glumi backend da bi se ekran mogao otvoriti
      // bez mreže, pa boje u njemu stoje umjesto reda iz baze.
      if (putanja.endsWith('lib/demo_main.dart')) continue;

      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final linija = linije[i];
        final ocisceno = linija.trim();
        if (ocisceno.startsWith('//') || ocisceno.startsWith('///')) continue;
        if (linija.contains('// ignore')) continue;
        for (final (izraz, opis) in _zabranjeno) {
          if (izraz.hasMatch(linija)) {
            prijave.add('$putanja:${i + 1} — $opis: ${linija.trim()}');
          }
        }
      }
    }

    expect(
      prijave,
      isEmpty,
      reason:
          'Boja klijenta dolazi iz `tenant.yaml` kroz `buildAppTheme()`, ili iz '
          '`Theme.of(context)`. Heks u ekranu se vidi tek na drugom tenantu.\n'
          '${prijave.join('\n')}',
    );
  });
}
