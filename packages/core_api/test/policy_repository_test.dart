import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testira se **mapiranje i spajanje**, ne PostgREST builder lanac — isti obrazac kao
/// `review_repository_test.dart`.
///
/// Spajanje je ovdje ono što nosi ekran: dvije tabele (ADR-0009) moraju dati **jedan**
/// redoslijed, i to isti pri svakom otvaranju. Poredak koji se mijenja između dva otvaranja
/// na pravno obavezujućem dokumentu izgleda kao da se tekst promijenio.
void main() {
  const salonId = '550e8400-e29b-41d4-a716-446655440000';

  PolicySection platformska(int sortOrder, String title) => PolicySection(
    id: 'app-$sortOrder',
    sortOrder: sortOrder,
    title: title,
    body: 'Tekst.',
    updatedAt: DateTime.utc(2026, 9, 14),
  );

  PolicySection salonska(int sortOrder, String title) => PolicySection(
    id: 'salon-$sortOrder',
    salonId: salonId,
    sortOrder: sortOrder,
    title: title,
    body: 'Tekst.',
    updatedAt: DateTime.utc(2026, 9, 14),
  );

  group('policySectionFromRow', () {
    test('mapira platformsku sekciju iz seeda', () {
      final sekcija = policySectionFromRow({
        'id': 'a1',
        'sort_order': 10,
        'title': 'Zakazivanje',
        'body': 'Zahtjev za termin nije potvrda.',
        'updated_at': '2026-09-14T09:00:00+00:00',
      });

      expect(sekcija.title, 'Zakazivanje');
      expect(sekcija.sortOrder, 10);
      expect(sekcija.isPlatform, isTrue);
      expect(sekcija.updatedAt.year, 2026);
    });

    test('mapira salonsku sekciju sa salon_id', () {
      final sekcija = policySectionFromRow({
        'id': 's1',
        'salon_id': salonId,
        'sort_order': 20,
        'title': 'Otkazivanje',
        'body': 'Rok je {minCancelHours} h.',
        'updated_at': '2026-09-14T09:00:00+00:00',
      });

      expect(sekcija.isPlatform, isFalse);
      expect(sekcija.body, contains('{minCancelHours}'));
    });

    test('red bez obaveznog polja izlazi kao MappingError', () {
      expect(
        () => policySectionFromRow({'id': 'a1', 'sort_order': 10}),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('mergePolicySections', () {
    // Ovo je redoslijed sa `15-pravila-koristenja.png`: platformske i salonske sekcije se
    // isprepliću, i upravo zato `sort_order` živi u istom prostoru nad obje tabele.
    test('spaja u redoslijed iz handoffa', () {
      final spojeno = mergePolicySections(
        [
          platformska(10, 'Zakazivanje'),
          platformska(40, 'Cijene'),
          platformska(50, 'Vaši podaci'),
        ],
        [
          salonska(20, 'Otkazivanje'),
          salonska(30, 'Kašnjenje'),
          salonska(60, 'Kontakt'),
        ],
      );

      expect(spojeno.map((s) => s.title), [
        'Zakazivanje',
        'Otkazivanje',
        'Kašnjenje',
        'Cijene',
        'Vaši podaci',
        'Kontakt',
      ]);
    });

    test('kod istog sort_ordera platformska ide prva', () {
      final spojeno = mergePolicySections(
        [platformska(20, 'Platformska')],
        [salonska(20, 'Salonska')],
      );

      expect(spojeno.map((s) => s.title), ['Platformska', 'Salonska']);
    });

    // Salon bez ijedne svoje sekcije je uredno stanje: `/terms` tada prikazuje samo
    // platformske, numerisane 01..03. Beauty tenant u seedu je namjerno kraći.
    test('salon bez svojih sekcija daje samo platformske', () {
      final spojeno = mergePolicySections([
        platformska(10, 'Zakazivanje'),
        platformska(40, 'Cijene'),
      ], const []);

      expect(spojeno.map((s) => s.title), ['Zakazivanje', 'Cijene']);
    });

    test('ulazi koji stignu neuređeni izlaze uređeni', () {
      // PostgREST vraća redoslijed koji upit traži, ali dva upita stižu neovisno — bez
      // sortiranja bi redoslijed zavisio od toga koji odgovor stigne prvi.
      final spojeno = mergePolicySections(
        [platformska(50, 'Vaši podaci'), platformska(10, 'Zakazivanje')],
        [salonska(60, 'Kontakt'), salonska(20, 'Otkazivanje')],
      );

      expect(spojeno.map((s) => s.sortOrder), [10, 20, 50, 60]);
    });
  });
}
