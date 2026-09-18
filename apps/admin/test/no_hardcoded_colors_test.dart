/// Test koji pada ako boja procuri nazad u ekran.
///
/// `SPEC.md` traži doslovno: „Vrijednosti prvo centralizovati u
/// `apps/admin/lib/src/core/theme/`; ne ponavljati hex vrijednosti po ekranima." Pregled
/// ovo ne hvata — jedan `Color(0xFF3D6D9E)` u ekranu izgleda tačno kao token dok se ne
/// promijeni token. Zato se čita izvor.
///
/// Test je namjerno glup: traži tekst, ne semantiku. Zaobilazi se jednim `// ignore`
/// komentarom, ali tada je izuzetak **napisan i vidljiv u diffu**, što je cijela poenta.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Folder u kojem heks **smije** stajati. Sve ostalo ga uzima odatle.
const String kTemaFolder = 'lib/src/core/theme';

/// Izrazi koji znače „boja je napisana ovdje, a ne uzeta iz teme".
final List<(RegExp, String)> _zabranjeno = [
  (RegExp(r'Color\(0x'), 'heks boja u ekranu'),
  (RegExp(r'Color\.fromARGB'), 'ARGB boja u ekranu'),
  // `Colors.transparent` je jedini izuzetak: nije boja nego odsustvo boje, i tema ga
  // koristi da ugasi Material `surfaceTint`.
  //
  // Granica rijeci sprjecava da izraz uhvati rep `AdminColors.` — token iz teme je
  // upravo ono sto ovaj test trazi da ekran koristi.
  (RegExp(r'\bColors\.(?!transparent)\w+'), 'Material paleta u ekranu'),
];

void main() {
  test('nijedan admin ekran ne piše boju sam', () {
    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final putanja = fajl.path.replaceAll(r'\', '/');
      if (putanja.contains(kTemaFolder)) continue;

      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final linija = linije[i];
        // Komentar ne iscrtava ni jedan piksel; heks u njemu je najcesce objasnjenje
        // odakle token dolazi.
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
          'Boja se uzima iz `AdminColors` ili iz `Theme.of(context)`, ne piše u ekranu.\n'
          '${prijave.join('\n')}',
    );
  });

  test('admin ne uvozi core_ui', () {
    // `core_ui` gradi temu iz **tenant** boja. Uvoz prolazi analizu, prolazi test, i vidi
    // se tek kad dva salona otvore istu aplikaciju — sidebar promijeni boju kad se
    // prijavi drugi vlasnik. Zato se drži na nivou izvora, ne dogovora.
    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final sadrzaj = fajl.readAsStringSync();
      if (sadrzaj.contains('package:core_ui/')) {
        prijave.add(fajl.path.replaceAll(r'\', '/'));
      }
    }

    expect(prijave, isEmpty, reason: 'core_ui je klijentska tema: $prijave');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('core_ui:')),
      reason: 'core_ui ne smije biti ni u zavisnostima admina',
    );
  });
}
