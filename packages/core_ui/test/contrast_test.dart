import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stvarne palete oba demo tenanta iz `tenants/*/tenant.yaml`.
///
/// Test koji koristi izmišljene boje dokazuje formulu, ne proizvod. Ove dvije palete su
/// ono što stvarno ode u store.
const barberPrimary = Color(0xFFC6A667); // zlatna
const barberSecondary = Color(0xFF171717); // skoro crna
const beautyPrimary = Color(0xFFB76E79); // roze
const beautySecondary = Color(0xFFFFF5F5); // topla bijela

void main() {
  group('contrastRatio', () {
    test('krajnosti daju poznate vrijednosti', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.1),
      );
      expect(
        contrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
        closeTo(1, 0.01),
      );
    });

    test('simetrican je — redoslijed argumenata ne mijenja odnos', () {
      expect(
        contrastRatio(barberPrimary, barberSecondary),
        closeTo(contrastRatio(barberSecondary, barberPrimary), 0.0001),
      );
    });
  });

  group('onColorFor — WCAG AA na stvarnim paletama', () {
    // Ovo je zahtjev iz DoD-a taska 09 doslovno: bijeli tekst na `#C6A667` pada, pa
    // funkcija mora izabrati crnu; na `#171717` mora izabrati bijelu.
    for (final (ime, boja) in <(String, Color)>[
      ('barber primary (zlatna)', barberPrimary),
      ('barber secondary (skoro crna)', barberSecondary),
      ('beauty primary (roze)', beautyPrimary),
      ('beauty secondary (topla bijela)', beautySecondary),
    ]) {
      test('$ime dobija citljiv tekst', () {
        final naNjoj = onColorFor(boja);
        expect(
          contrastRatio(naNjoj, boja),
          greaterThanOrEqualTo(kWcagAa),
          reason:
              '$ime: izabrani tekst ima kontrast '
              '${contrastRatio(naNjoj, boja).toStringAsFixed(2)}:1 — ispod AA.',
        );
      });
    }

    test('na zlatnoj bira crnu, ne bijelu', () {
      // Naivni prag po luminanciji (0.42 < 0.5 → "tamna") bi ovdje stavio bijeli tekst
      // i dao 2.6:1. Zbog ovog slucaja funkcija poredi odnose, a ne luminanciju.
      final naZlatnoj = onColorFor(barberPrimary);
      expect(naZlatnoj.computeLuminance(), lessThan(0.5));
      expect(
        contrastRatio(const Color(0xFFFFFFFF), barberPrimary),
        lessThan(kWcagAa),
      );
    });

    test('na skoro crnoj bira bijelu', () {
      expect(onColorFor(barberSecondary).computeLuminance(), greaterThan(0.5));
    });

    test(
      'zuta — slucaj iz docs/02 §14 koji je i razlog postojanja funkcije',
      () {
        const zuta = Color(0xFFFFEB3B);
        final naZutoj = onColorFor(zuta);
        expect(contrastRatio(naZutoj, zuta), greaterThanOrEqualTo(kWcagAa));
        expect(
          naZutoj.computeLuminance(),
          lessThan(0.5),
          reason: 'na zutoj mora crna',
        );
      },
    );
  });

  group('readableOn — brand boja kao tekst', () {
    test('nepromijenjena kad vec prolazi', () {
      const pozadina = Color(0xFF171717);
      expect(readableOn(barberPrimary, pozadina), barberPrimary);
    });

    test('pomjera sekundarnu barbera da bude vidljiva na tamnoj pozadini', () {
      // `#171717` na `#171717` je odnos 1:1 — bez pomjeranja tekst bi bio nevidljiv.
      const pozadina = Color(0xFF171717);
      expect(contrastRatio(barberSecondary, pozadina), lessThan(kWcagAa));
      expect(
        contrastRatio(readableOn(barberSecondary, pozadina), pozadina),
        greaterThanOrEqualTo(kWcagAa),
      );
    });

    test('pomjera beauty sekundarnu na svijetloj pozadini', () {
      const pozadina = Color(0xFFFFFBFB);
      expect(
        contrastRatio(readableOn(beautySecondary, pozadina), pozadina),
        greaterThanOrEqualTo(kWcagAa),
      );
    });

    test('zadrzava prepoznatljiv ton — mijenja svjetlinu, ne nijansu', () {
      const pozadina = Color(0xFF171717);
      final pomjerena = readableOn(beautyPrimary, pozadina);
      expect(
        HSLColor.fromColor(pomjerena).hue,
        closeTo(HSLColor.fromColor(beautyPrimary).hue, 1.0),
        reason: 'roze mora ostati roze, samo svjetlija',
      );
    });
  });
}
