import 'package:core_api/src/vertical/vertical_repository.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Redovi kakve PostgREST vrati za upit iz `VerticalRepository` — `salons` red sa
/// ugniježđenim `vertical_packs` embedom.
void main() {
  test('mapira vertical_packs embed u Vertical', () {
    final vertical = verticalFromSalonRow({
      'terminology_override': null,
      'vertical_packs': {
        'key': 'barber',
        'display_name': 'Barber',
        'terminology': {'bookCta': 'Zakaži termin', 'staffSingular': 'Barber'},
        'default_settings': {'slotStepMinutes': 15},
        'feature_flags': {'gallery': true},
        'default_theme': 'modern_barber',
      },
    });

    expect(vertical.key, 'barber');
    expect(vertical.terms.bookCta, 'Zakaži termin');
    expect(vertical.rules.slotStepMinutes, 15);
    expect(vertical.features.gallery, isTrue);
  });

  test('terminology_override sa salona prebija vertikalu', () {
    final vertical = verticalFromSalonRow({
      'terminology_override': {'customerSingular': 'Klijentica'},
      'vertical_packs': {
        'key': 'beauty',
        'display_name': 'Beauty',
        'terminology': {
          'customerSingular': 'Klijent',
          'staffSingular': 'Stilistica',
        },
        'default_theme': 'elegant_beauty',
      },
    });

    expect(vertical.terms.customerSingular, 'Klijentica');
    // Ostatak vertikalne terminologije preživljava override.
    expect(vertical.terms.staffSingular, 'Stilistica');
  });

  test('salon koji ne postoji daje fallback, ne exception', () {
    // `SALON_ID` dolazi iz builda — salon koji nedostaje znaci pogresno konfigurisan
    // tenant, a to mora zavrsiti generic tekstom umjesto praznim ekranom.
    expect(verticalFromSalonRow(null), Vertical.fallback);
  });

  test('red bez vertical_packs embeda daje fallback', () {
    expect(
      verticalFromSalonRow({'terminology_override': null}),
      Vertical.fallback,
    );
  });

  test(
    'override koji stigne kao Map<dynamic, dynamic> se i dalje primjenjuje',
    () {
      // PostgREST kroz `json_decode` zna vratiti `Map<dynamic, dynamic>` za ugniježđeni
      // objekat — direktan `as Map<String, dynamic>` bi tu pukao u runtime-u.
      final vertical = verticalFromSalonRow({
        'terminology_override': <dynamic, dynamic>{'bookCta': 'Zakaži pregled'},
        'vertical_packs': <dynamic, dynamic>{
          'key': 'dental',
          'display_name': 'Stomatologija',
          'terminology': <dynamic, dynamic>{'bookCta': 'Zakaži termin'},
          'default_theme': 'clinical_calm',
        },
      });

      expect(vertical.key, 'dental');
      expect(vertical.terms.bookCta, 'Zakaži pregled');
    },
  );
}
