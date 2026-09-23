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

  test('index.html ne nosi Flutter šablonske vrijednosti', () {
    expect(html, isNot(contains('A new Flutter project')));
    expect(html, isNot(contains('<title>admin</title>')));
  });
}
