/// Test koji pada ako se Material `SnackBar` vrati u admin.
///
/// Obavijest ide kroz `AdminToast` (`prototype/adminv2/toast/`). `ScaffoldMessenger` je
/// ono što Flutter nudi prvo, pa bi se bez ovog testa prvi sljedeći vratio tiho — u drugom
/// obliku, na dnu ekrana, bez vrste.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nijedan admin ekran ne zove SnackBar', () {
    final izraz = RegExp(r'\b(showSnackBar|SnackBar\(|ScaffoldMessenger\.of)');
    final prijave = <String>[];

    for (final fajl in Directory('lib').listSync(recursive: true)) {
      if (fajl is! File || !fajl.path.endsWith('.dart')) continue;
      final linije = fajl.readAsLinesSync();
      for (var i = 0; i < linije.length; i++) {
        final ocisceno = linije[i].trim();
        if (ocisceno.startsWith('//')) continue;
        if (izraz.hasMatch(linije[i])) {
          prijave.add('${fajl.path.replaceAll(r'\', '/')}:${i + 1}: $ocisceno');
        }
      }
    }

    expect(
      prijave,
      isEmpty,
      reason: 'Obavijest ide kroz `AdminToast`:\n${prijave.join('\n')}',
    );
  });
}
