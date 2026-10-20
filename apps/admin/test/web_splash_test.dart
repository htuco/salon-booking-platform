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

  test('tamna pozadina u index.html je tamni ground', () {
    expect(
      html,
      contains('background-color: ${_hex(AdminPalette.dark.ground)}'),
      reason: 'Tamna pozadina mora pratiti `AdminPalette.dark.ground`.',
    );
  });

  group('animacija učitavanja (task 63) prati AdminUcitavanje', () {
    // Splash i prvi Flutter kadar moraju imati isti pokret i iste boje, inače se na
    // prelazu vidi skok. CSS ne čita Dart, pa se poredi tekst.
    test('termin je action, linija je nowLine — svijetla i tamna', () {
      for (final (paleta, tema) in [
        (AdminPalette.light, 'svijetla'),
        (AdminPalette.dark, 'tamna'),
      ]) {
        expect(
          html,
          contains('.termin { fill: ${_hex(paleta.action)}; }'),
          reason: '$tema: termin u splashu mora biti `action`.',
        );
        expect(
          html,
          contains('fill: ${_hex(paleta.nowLine)}'),
          reason: '$tema: linija u splashu mora biti `nowLine`.',
        );
      }
    });

    test('trajanje i kriva su iste kao u Dartu', () {
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
      expect(html, contains('translateY(-34px)'));
      expect(html, contains('translateY(34px)'));
    });

    test('poštuje manje pokreta i nestaje na prvom kadru', () {
      expect(html, contains('prefers-reduced-motion: reduce'));
      expect(html, contains("'flutter-first-frame'"));
    });
  });

  test('index.html ne nosi Flutter šablonske vrijednosti', () {
    expect(html, isNot(contains('A new Flutter project')));
    expect(html, isNot(contains('<title>admin</title>')));
  });
}
