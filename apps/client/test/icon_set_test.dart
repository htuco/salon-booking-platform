import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard za [ADR-0017]: **Lucide je set ikona klijenta i `core_ui`-ja.**
/// Material `Icons.*` ostaje samo u `apps/admin`, koji se ne prevodi.
///
/// Ovaj test postoji zato što se pravilo ne vidi na ekranu dok se ne uporedi sa
/// handoffom, a `Icons.cloud_off_outlined` pored `LucideIcons.cloudOff` izgleda
/// potpuno normalno u diffu.
///
/// ## Zamka koja je ovaj test i iznjedrila
///
/// `LucideIcons` se **završava** na `Icons`, pa naivni `grep "Icons\."` hvata i
/// `LucideIcons.scissors` i `Icons.inbox_outlined`. Po tom brojanju je klijent
/// izgledao kao da nosi 34 Material ikone, a nosio je **četiri**. Zato regex
/// ispod ima negative lookbehind na `Lucide` — bez njega test prijavljuje
/// ispravan kod kao grešku.
void main() {
  test('klijent i core_ui ne koriste Material Icons — samo Lucide (ADR-0017)', () {
    // `(?<!Lucide)` je nosivi dio: bez njega `LucideIcons.x` pada kao Material.
    final materialIkona = RegExp(r'(?<!Lucide)\bIcons\.\w+');

    final nalazi = <String>[];
    for (final korijen in const ['lib', '../../packages/core_ui/lib']) {
      final dir = Directory(korijen);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final linije = f.readAsLinesSync();
        for (var i = 0; i < linije.length; i++) {
          for (final m in materialIkona.allMatches(linije[i])) {
            nalazi.add('${f.path}:${i + 1} — ${m.group(0)}');
          }
        }
      }
    }

    expect(
      nalazi,
      isEmpty,
      reason:
          'Material ikone u klijentu ili core_ui-ju. Po ADR-0017 tu ide Lucide '
          '(`LucideIcons.*`); Material ostaje samo u apps/admin.\n'
          '${nalazi.join('\n')}',
    );
  });
}
