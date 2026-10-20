/// Test koji pada ako se pozadina u `web/index.html` razmimoiđe sa `AdminPalette.light.ground`.
///
/// Admin je Flutter **web**, pa se prije prvog Flutter kadra vidi obična HTML stranica.
/// Dok je `index.html` bio netaknut Flutter šablon, to je bila **bijela** stranica — pa
/// se pri svakom otvaranju vidio bijeli bljesak, a u tamnoj temi bijelo pa tamno.
///
/// CSS ne može čitati Dart tokene, pa je ta jedna boja nužno prepisana na dva mjesta.
/// Ovaj test je cijena tog izuzetka: kad se `ground` promijeni u `admin_colors.dart`, a
/// `index.html` ostane, ovdje pukne — umjesto da bljesak primijeti korisnik.
///
/// Web loader ne vidi nijedan widget test; ovo je jedini automatski dokaz koji o njemu
/// postoji.
library;

import 'dart:io';

import 'package:admin/src/core/theme/admin_colors.dart';
import 'package:admin/src/core/widgets/admin_ucitavanje.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(Color boja) {
  final argb = boja.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

void main() {
  final html = File('web/index.html').readAsStringSync();

  test('svijetla pozadina u index.html je AdminPalette.light.ground', () {
    expect(
      html,
      contains('background-color: ${_hex(AdminPalette.light.ground)}'),
      reason:
          'Svijetla pozadina u web/index.html mora biti ista vrijednost kao '
          '`AdminPalette.light.ground`, inače se pri učitavanju vidi bljesak.',
    );
  });

  test('splash nema tamnu varijantu dok je admin uvijek svijetao', () {
    // `main.dart` drži `themeMode: ThemeMode.light` (ADR-0020). Tamna pozadina ili znak
    // po `prefers-color-scheme` bi na OS-u u dark modu dali tamno pa svijetlo — bljesak
    // koji FE-205 sklanja. Kad se vrati `ThemeMode.system`, vraća se i ovo.
    expect(html, isNot(contains('prefers-color-scheme: dark')));
    expect(html, isNot(contains(_hex(AdminPalette.dark.ground))));
    expect(html, contains('color-scheme: light;'));
  });

  group('animacija učitavanja (task 63) prati AdminUcitavanje', () {
    // Splash i Flutter znak moraju imati isti pokret i iste boje. CSS ne čita Dart, pa
    // se poredi tekst — cijelo pravilo, da boja ne prođe u pogrešnom selektoru.
    test('termin je action, linija je nowLine', () {
      const paleta = AdminPalette.light;
      expect(
        html,
        contains('#ucitavanje .termin { fill: ${_hex(paleta.action)}; }'),
      );
      expect(
        html,
        // Regex, ne tekst: na Windows checkoutu je kraj reda CRLF.
        matches(
          RegExp('#ucitavanje \\.sada \\{\\s*fill: ${_hex(paleta.nowLine)};'),
        ),
      );
    });

    test('trajanje, kriva i keyframes su iste kao u Dartu', () {
      final sekunde = AdminUcitavanje.trajanje.inMilliseconds / 1000;
      const k = AdminUcitavanje.kriva;
      String broj(double v) => v == v.roundToDouble()
          ? '${v.toInt()}'
          : '$v'.replaceFirst('0.', '.');
      expect(
        html,
        contains(
          'animation: klizi ${sekunde}s cubic-bezier('
          '${broj(k.a)}, ${broj(k.b)}, ${broj(k.c)}, ${broj(k.d)}) infinite',
        ),
      );
      expect(html, contains('0%, 100% { transform: translateY(-34px); }'));
      expect(html, contains('50% { transform: translateY(34px); }'));
    });

    test(
      'poštuje manje pokreta, ne hvata klikove i nestaje na prvom kadru',
      () {
        expect(html, contains('prefers-reduced-motion: reduce'));
        expect(html, contains('pointer-events: none'));
        expect(html, contains("'flutter-first-frame'"));
      },
    );
  });

  test('index.html ne nosi Flutter šablonske vrijednosti', () {
    expect(html, isNot(contains('A new Flutter project')));
    expect(html, isNot(contains('<title>admin</title>')));
  });
}
