/// Test koji pada ako se Material indikator vrati u admin ekran.
///
/// FE-205 je sklonio 25 upotreba `CircularProgressIndicator`/`LinearProgressIndicator`.
/// Bez ovog testa se prvi sljedeći vrati tiho: spinner je ono što Flutter nudi kao
/// podrazumijevano, pa ga svaki novi `when(loading:)` sam predloži.
///
/// **Jedan izuzetak je dopušten i napisan:** `LinearProgressIndicator` sa zadanim
/// `value`-om nije indikator učitavanja nego **traka podatka** (zauzetost radnika na
/// dashboardu). Takav red nosi `// ignore` uz razlog.
///
/// FE-501 je dodao i `RefreshIndicator(`: njegov spinner je isti Material potpis.
/// Povlačenje ide kroz `AdminRefresh`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nijedan admin ekran ne koristi Material indikator', () {
    // `RefreshIndicator(` crta Material spinner; `.noSpinner(` ne crta i dopušten je
    // (nosi ga `AdminRefresh`, FE-501).
    final izraz = RegExp(
      r'\b((Circular|Linear)ProgressIndicator\b|RefreshIndicator\s*\()',
    );

    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final putanja = fajl.path.replaceAll(r'\', '/');

      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final linija = linije[i];
        final ocisceno = linija.trim();
        if (ocisceno.startsWith('//') || ocisceno.startsWith('///')) continue;
        if (linija.contains('// ignore')) continue;
        // Izuzetak smije stajati i u redu **iznad**, jer se `LinearProgressIndicator`
        // najcesce pise kao `child:` pa mu komentar prirodno dode iznad.
        if (i > 0 && linije[i - 1].contains('// ignore')) continue;
        if (izraz.hasMatch(linija)) {
          prijave.add('$putanja:${i + 1} — ${linija.trim()}');
        }
      }
    }

    expect(
      prijave,
      isEmpty,
      reason:
          'Učitavanje nosi `AdminSkeletonList`, radnja u dugmetu `AdminButtonBusy`, '
          'povlačenje `AdminRefresh`. '
          'Traka podatka (sa `value`) je izuzetak i nosi `// ignore` uz razlog.\n'
          '${prijave.join('\n')}',
    );
  });
}
