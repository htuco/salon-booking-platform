import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Terminologija barber vertikale, prepisana iz `supabase/seed.sql`.
const _barberTerminology = {
  'businessSingular': 'Barbershop',
  'customerSingular': 'Klijent',
  'customerPlural': 'Klijenti',
  'serviceSingular': 'Usluga',
  'servicePlural': 'Usluge',
  'staffSingular': 'Barber',
  'staffPlural': 'Naš tim',
  'appointmentSingular': 'Termin',
  'bookCta': 'Zakaži termin',
  'noteLabel': 'Napomena',
  'myAppointments': 'Moji termini',
  'priceLabel': 'Cijena',
  'durationLabel': 'Trajanje',
};

void main() {
  group('VerticalTerms', () {
    test('čita sve ključeve iz JSONB oblika kakav stoji u bazi', () {
      final terms = VerticalTerms.fromJson(_barberTerminology);

      expect(terms.businessSingular, 'Barbershop');
      expect(terms.staffSingular, 'Barber');
      expect(terms.bookCta, 'Zakaži termin');
      expect(terms.durationLabel, 'Trajanje');
    });

    test('ključ koji nedostaje pada na generic default, ne na exception', () {
      final terms = VerticalTerms.fromJson({'staffSingular': 'Doktor'});

      expect(terms.staffSingular, 'Doktor');
      expect(terms.customerSingular, VerticalTerms.fallback.customerSingular);
      expect(terms.bookCta, VerticalTerms.fallback.bookCta);
    });

    test('vrijednost pogrešnog tipa pada na default umjesto CastError-a', () {
      // Baza je JSONB — pogrešan tip je moguć preko lošeg update-a, a app iz storea
      // ne smije pući na tuđoj grešci u podacima.
      final terms = VerticalTerms.fromJson({
        'customerSingular': 42,
        'bookCta': null,
        'noteLabel': '',
      });

      expect(terms.customerSingular, VerticalTerms.fallback.customerSingular);
      expect(terms.bookCta, VerticalTerms.fallback.bookCta);
      expect(terms.noteLabel, VerticalTerms.fallback.noteLabel);
    });

    group('mergeOverride', () {
      test('override mijenja samo poslane ključeve', () {
        final terms = VerticalTerms.fromJson(_barberTerminology)
            .mergeOverride({'customerSingular': 'Klijentica'});

        expect(terms.customerSingular, 'Klijentica');
        // Ostatak terminologije mora preživjeti — ovo je cijeli razlog zašto se
        // sloji po ključu, a ne zamjenom objekta (docs/05 §3, rod je dio proizvoda).
        expect(terms.staffSingular, 'Barber');
        expect(terms.bookCta, 'Zakaži termin');
        expect(terms.businessSingular, 'Barbershop');
      });

      test('prazan i null override ne mijenjaju ništa', () {
        final base = VerticalTerms.fromJson(_barberTerminology);

        expect(base.mergeOverride(null), base);
        expect(base.mergeOverride(const {}), base);
      });
    });
  });

  group('BookingRules', () {
    test('čita barber default_settings iz seeda', () {
      final rules = BookingRules.fromJson(const {
        'bookingMode': 'manual',
        'bookingGranularity': 'exact_slot',
        'slotStepMinutes': 15,
        'bufferMinutes': 5,
        'minAdvanceBookingHours': 2,
        'maxAdvanceBookingDays': 30,
        'minCancelHours': 3,
        'pendingExpiryHours': 12,
        'requireStaffChoice': false,
        'showPricesInApp': true,
      });

      expect(rules.mode, BookingMode.manual);
      expect(rules.granularity, BookingGranularity.exactSlot);
      expect(rules.slotStepMinutes, 15);
      expect(rules.bufferMinutes, 5);
      expect(rules.requireStaffChoice, isFalse);
    });

    test('date_only granularnost se čita iz snake_case vrijednosti', () {
      final rules = BookingRules.fromJson(const {
        'bookingGranularity': 'date_only',
      });

      expect(rules.granularity, BookingGranularity.dateOnly);
    });

    test('nepoznata granularnost pada na exact_slot', () {
      final rules = BookingRules.fromJson(const {
        'bookingGranularity': 'nesto_novo',
      });

      expect(rules.granularity, BookingGranularity.exactSlot);
    });
  });

  group('Vertical', () {
    test('gradi se iz cijelog vertical_packs reda', () {
      final vertical = Vertical.fromJson({
        'key': 'barber',
        'display_name': 'Barber',
        'terminology': _barberTerminology,
        'default_settings': const {'slotStepMinutes': 15, 'bufferMinutes': 5},
        'feature_flags': const {'gallery': true, 'recall': false},
        'default_theme': 'modern_barber',
      });

      expect(vertical.key, 'barber');
      expect(vertical.displayName, 'Barber');
      expect(vertical.terms.staffSingular, 'Barber');
      expect(vertical.rules.slotStepMinutes, 15);
      expect(vertical.features.gallery, isTrue);
      expect(vertical.defaultTheme, 'modern_barber');
    });

    test('terminology_override sa salona se sloji preko vertikale', () {
      final vertical = Vertical.fromJson(
        {
          'key': 'beauty',
          'display_name': 'Beauty',
          'terminology': const {
            'customerSingular': 'Klijent',
            'staffSingular': 'Stilistica',
          },
          'default_theme': 'elegant_beauty',
        },
        terminologyOverride: const {'customerSingular': 'Klijentica'},
      );

      expect(vertical.terms.customerSingular, 'Klijentica');
      expect(vertical.terms.staffSingular, 'Stilistica');
    });

    test('nepoznat ključ vertikale ne ruši parsiranje', () {
      // App u storeu je starija od baze: `key` check constraint se širi migracijom,
      // pa vertikala koja ne postoji u ovoj verziji app-e mora proći kroz generic
      // ponašanje, a ne kroz exception.
      final vertical = Vertical.fromJson({
        'key': 'veterinary',
        'display_name': 'Veterina',
        'default_theme': 'clinical_calm',
      });

      expect(vertical.key, 'veterinary');
      expect(vertical.terms, VerticalTerms.fallback);
      expect(vertical.rules, BookingRules.fallback);
    });

    test('prazan red daje potpuni fallback, bez null-a', () {
      final vertical = Vertical.fromJson(const {});

      expect(vertical, Vertical.fallback);
    });
  });

  group('seed.sql', () {
    // Model i baza dijele oblik. Kad neko doda ključ u seed a zaboravi na Dart stranu
    // (ili obrnuto), ovaj test to prijavi ovdje — a ne kroz prazan Text na ekranu.
    test('svaka vertikala iz seeda se parsira bez pada na fallback', () {
      // Terminologija u seedu je jedan red po vertikali, oblika `'{...}',` — zarad
      // citljivosti seeda, a ne slucajno. Ne veži se za kraj reda (`$`): red zavrsava
      // zarezom, a fajl je u repou sa CRLF krajevima, pa je `$` dvostruko krhak.
      final seed = File('../../supabase/seed.sql').readAsStringSync();
      final terminologies = RegExp(
        r'''^'(\{"businessSingular.*?\})',?\s*$''',
        multiLine: true,
      ).allMatches(seed).map((match) => match.group(1)!).toList();

      expect(
        terminologies,
        hasLength(3),
        reason: 'seed.sql ima barber, beauty i generic terminologiju',
      );

      for (final raw in terminologies) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final terms = VerticalTerms.fromJson(json);

        expect(
          terms.toJson().keys.toSet(),
          json.keys.toSet(),
          reason: 'seed i VerticalTerms moraju imati iste ključeve',
        );
      }
    });
  });
}
