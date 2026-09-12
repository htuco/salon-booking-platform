import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart'
    show barberPrimary, barberSecondary, beautyPrimary, beautySecondary;

/// Obje demo palete, onakve kakve idu u store.
const palete = <String, (Color, Color, String)>{
  'barber': (barberPrimary, barberSecondary, 'modern_barber'),
  'beauty': (beautyPrimary, beautySecondary, 'elegant_beauty'),
};

void main() {
  group('AppTheme.fromName', () {
    test('poznata imena daju svoju svjetlinu', () {
      expect(AppTheme.fromName('modern_barber').brightness, Brightness.dark);
      expect(AppTheme.fromName('elegant_beauty').brightness, Brightness.light);
      expect(AppTheme.fromName('clinical_calm').brightness, Brightness.light);
    });

    test('nepoznato ime i null padaju na modern_barber, ne bacaju', () {
      // App u storeu je starija od baze: tema dodana migracijom ne smije biti izuzetak
      // pri startu. Isti razlog kao `AppointmentStatus.unknown`.
      expect(AppTheme.fromName('tema_iz_buducnosti'), AppTheme.modernBarber);
      expect(AppTheme.fromName(null), AppTheme.modernBarber);
      expect(AppTheme.fromName(''), AppTheme.modernBarber);
    });
  });

  group('buildAppTheme — kontrast na obje demo palete', () {
    palete.forEach((ime, paleta) {
      final (primary, secondary, themeName) = paleta;

      test('$ime: onPrimary i onSecondary prolaze AA', () {
        final tema = buildAppTheme(
          primary: primary,
          secondary: secondary,
          themeName: themeName,
        );
        final scheme = tema.colorScheme;

        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(kWcagAa),
          reason: '$ime: tekst na primarnoj boji ispod AA',
        );
        expect(
          contrastRatio(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(kWcagAa),
          reason: '$ime: tekst na sekundarnoj boji ispod AA',
        );
      });

      test('$ime: sav tekst teme prolazi AA na svojoj pozadini', () {
        final tema = buildAppTheme(
          primary: primary,
          secondary: secondary,
          themeName: themeName,
        );
        final scheme = tema.colorScheme;

        // Prigušeni tekst se mjeri isto kao primarni — `docs/02 §14` traži AA za **sav**
        // tekst, a `onSurfaceVariant` je najcesci kandidat da tiho padne ispod praga.
        for (final (opis, boja, pozadina) in <(String, Color, Color)>[
          ('onSurface', scheme.onSurface, scheme.surface),
          ('onSurfaceVariant', scheme.onSurfaceVariant, scheme.surface),
          (
            'onSurfaceVariant na kontejneru',
            scheme.onSurfaceVariant,
            scheme.surfaceContainerHighest,
          ),
          (
            'onSurface na kontejneru',
            scheme.onSurface,
            scheme.surfaceContainerHighest,
          ),
          ('onError', scheme.onError, scheme.error),
          // Donja navigacija stoji na `surfaceDim`, koja je tamnija (svjetlija u
          // svijetloj temi) od pozadine ekrana. Bez ova dva reda labela taba je
          // jedini tekst u sistemu koji niko ne mjeri.
          ('onSurface na traci', scheme.onSurface, scheme.surfaceDim),
          (
            'onSurfaceVariant na traci',
            scheme.onSurfaceVariant,
            scheme.surfaceDim,
          ),
        ]) {
          expect(
            contrastRatio(boja, pozadina),
            greaterThanOrEqualTo(kWcagAa),
            reason:
                '$ime/$opis: ${contrastRatio(boja, pozadina).toStringAsFixed(2)}:1',
          );
        }
      });

      test('$ime: brand boja kao tekst je citljiva na pozadini', () {
        final tema = buildAppTheme(
          primary: primary,
          secondary: secondary,
          themeName: themeName,
        );
        final brand = tema.extension<AppBrandColors>()!;
        final pozadina = tema.colorScheme.surface;

        expect(
          contrastRatio(brand.primaryOnSurface, pozadina),
          greaterThanOrEqualTo(kWcagAa),
        );
        expect(
          contrastRatio(brand.secondaryOnSurface, pozadina),
          greaterThanOrEqualTo(kWcagAa),
        );
      });

      test('$ime: statusne boje prolaze AA i ne mijenjaju se po salonu', () {
        final tema = buildAppTheme(
          primary: primary,
          secondary: secondary,
          themeName: themeName,
        );
        final status = tema.extension<AppStatusColors>()!;

        for (final (opis, tekst, pozadina) in <(String, Color, Color)>[
          ('success', status.onSuccess, status.success),
          ('warning', status.onWarning, status.warning),
          ('danger', status.onDanger, status.danger),
          ('info', status.onInfo, status.info),
          ('blocked', status.onBlocked, status.blocked),
        ]) {
          expect(
            contrastRatio(tekst, pozadina),
            greaterThanOrEqualTo(kWcagAa),
            reason: '$ime/$opis ispod AA',
          );
        }
      });
    });

    test('statusne boje ne zavise od brand boje salona', () {
      // Salon koji izabere zelenu kao primarnu ne smije dobiti statuse koji se stope s
      // njom — zato su fiksne (`docs/02 §16`).
      final zeleniSalon = buildAppTheme(
        primary: const Color(0xFF2E7D32),
        secondary: const Color(0xFF1B5E20),
        themeName: 'elegant_beauty',
      ).extension<AppStatusColors>()!;
      final rozeSalon = buildAppTheme(
        primary: beautyPrimary,
        secondary: beautySecondary,
        themeName: 'elegant_beauty',
      ).extension<AppStatusColors>()!;

      expect(zeleniSalon.success, rozeSalon.success);
      expect(zeleniSalon.danger, rozeSalon.danger);
    });

    test('zuta kao primarna — salon koji bi inace dobio neciljivu app', () {
      final tema = buildAppTheme(
        primary: const Color(0xFFFFEB3B),
        secondary: const Color(0xFF212121),
        themeName: 'elegant_beauty',
      );
      expect(
        contrastRatio(tema.colorScheme.onPrimary, tema.colorScheme.primary),
        greaterThanOrEqualTo(kWcagAa),
      );
    });

    test(
      'obje svjetline iste palete prolaze — komponenta se provjerava dvaput',
      () {
        for (final svjetlina in Brightness.values) {
          final tema = buildAppTheme(
            primary: barberPrimary,
            secondary: barberSecondary,
            themeName: 'modern_barber',
            brightness: svjetlina,
          );
          expect(tema.brightness, svjetlina);
          expect(
            contrastRatio(tema.colorScheme.onPrimary, tema.colorScheme.primary),
            greaterThanOrEqualTo(kWcagAa),
          );
        }
      },
    );
  });

  group('buildAppTheme — tokeni umjesto Flutter defaulta', () {
    test('body font nije ispod 15 sp (docs/02 §14)', () {
      final tema = buildAppTheme(
        primary: beautyPrimary,
        secondary: beautySecondary,
        themeName: 'elegant_beauty',
      );
      expect(tema.textTheme.bodyLarge!.fontSize, greaterThanOrEqualTo(15));
      expect(tema.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(15));
    });

    test('dugme ima dodirnu metu iz tokena', () {
      final tema = buildAppTheme(
        primary: beautyPrimary,
        secondary: beautySecondary,
        themeName: 'elegant_beauty',
      );
      final minimum = tema.filledButtonTheme.style!.minimumSize!.resolve({});
      expect(minimum!.height, AppSize.buttonHeight);
    });

    test('pozadina Scaffolda je iz teme, ne Flutterova bijela', () {
      final tamna = buildAppTheme(
        primary: barberPrimary,
        secondary: barberSecondary,
        themeName: 'modern_barber',
      );
      expect(tamna.scaffoldBackgroundColor, isNot(const Color(0xFFFFFFFF)));
      expect(tamna.scaffoldBackgroundColor, tamna.colorScheme.surface);
    });
  });
}
