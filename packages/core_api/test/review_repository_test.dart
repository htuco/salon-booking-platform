import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testira se **mapiranje**, ne PostgREST builder lanac — isti obrazac kao
/// `catalog_repository_test.dart`. Izuzetak je admin lista, gdje je oblik upita sam
/// ugovor (v. grupu `StaffReviewRepository.forSalon`).
void main() {
  const salonId = '550e8400-e29b-41d4-a716-446655440000';

  group('reviewFromRow', () {
    test('mapira red iz seeda', () {
      final review = reviewFromRow({
        'id': 'r1',
        'salon_id': salonId,
        'author_name': 'Nedim H.',
        'rating': 5,
        'comment': 'Fade je uvijek isti, tačno kako tražim.',
        'created_at': '2026-09-11T09:00:00+00:00',
      });

      expect(review.authorName, 'Nedim H.');
      expect(review.rating, 5);
      expect(review.hasComment, isTrue);
      expect(review.createdAt.year, 2026);
    });

    test('ocjena bez teksta je uredan red, ne greška', () {
      final review = reviewFromRow({
        'id': 'r2',
        'salon_id': salonId,
        'author_name': 'Adnan P.',
        'rating': 5,
        'comment': null,
        'created_at': '2026-09-09T09:00:00+00:00',
      });

      expect(review.hasComment, isFalse);
    });

    test('red bez is_published je objavljen', () {
      // Klijentski upit ne traži `is_published`; default ne smije javnu recenziju
      // pretvoriti u sakrivenu.
      final review = reviewFromRow({
        'id': 'r3',
        'salon_id': salonId,
        'author_name': 'Nedim H.',
        'rating': 4,
        'created_at': '2026-09-11T09:00:00+00:00',
      });

      expect(review.isPublished, isTrue);
    });

    test('red iz admina nosi sakrivenost (task 67)', () {
      final review = reviewFromRow({
        'id': 'r4',
        'salon_id': salonId,
        'author_name': 'Ana K.',
        'rating': 2,
        'comment': null,
        'created_at': '2026-10-20T09:00:00+00:00',
        'is_published': false,
      });

      expect(review.isPublished, isFalse);
    });
  });

  group('ratingsFromRows', () {
    test('par termin → ocjena iz my_review_ratings', () {
      expect(
        ratingsFromRows([
          {'appointment_id': 'a1', 'rating': 4},
          {'appointment_id': 'a2', 'rating': 1},
        ]),
        {'a1': 4, 'a2': 1},
      );
    });

    test('red bez termina je greška mapiranja, ne tiha nula', () {
      expect(
        () => ratingsFromRows([
          {'appointment_id': null, 'rating': 4},
        ]),
        throwsA(isA<MappingError>()),
      );
    });

    test('prazan i razmakom popunjen komentar se broje kao da ga nema', () {
      // Import zna upisati `''` umjesto `null`. Kartica sa imenom, zvjezdicama i
      // prazninom ispod izgleda kao slika koja se nije učitala.
      for (final prazno in ['', '   ', '\n']) {
        final review = reviewFromRow({
          'id': 'r3',
          'salon_id': salonId,
          'author_name': 'Tarik B.',
          'rating': 4,
          'comment': prazno,
          'created_at': '2026-09-01T09:00:00+00:00',
        });
        expect(review.hasComment, isFalse, reason: 'za komentar "$prazno"');
      }
    });

    test('neispravan red je MappingError, ne goli TypeError', () {
      expect(
        () => reviewFromRow({'id': 'r4', 'salon_id': salonId}),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('ratingSummaryFromRow', () {
    Map<String, dynamic> red(Object average) => {
      'salon_id': salonId,
      'average': average,
      'total': 25,
      'count_5': 21,
      'count_4': 3,
      'count_3': 1,
      'count_2': 0,
      'count_1': 0,
    };

    test('mapira agregat kakav pogled vraća', () {
      final summary = ratingSummaryFromRow(red(4.8));

      expect(summary.average, 4.8);
      expect(summary.total, 25);
      expect(summary.countFor(5), 21);
      expect(summary.countFor(3), 1);
      expect(summary.countFor(2), 0);
    });

    test('`numeric` koji stigne kao String se i dalje mapira', () {
      // `round(avg(rating), 1)` je `numeric`, a `supabase_flutter` ga ovisno o
      // vrijednosti daje kao `num` ili kao `String`. Bez normalizacije ovdje, ekran bi
      // na jednom salonu radio a na drugom bacio TypeError — i to tek u produkciji.
      expect(ratingSummaryFromRow(red('4.8')).average, 4.8);
      expect(ratingSummaryFromRow(red('5')).average, 5.0);
      expect(ratingSummaryFromRow(red(5)).average, 5.0);
    });

    test('neispravan agregat je MappingError', () {
      expect(
        () =>
            ratingSummaryFromRow({'salon_id': salonId, 'average': 'nije broj'}),
        throwsA(isA<MappingError>()),
      );
    });
  });

  group('SalonRatingSummary — histogram', () {
    const summary = SalonRatingSummary(
      salonId: salonId,
      average: 4.8,
      total: 25,
      count5: 21,
      count4: 3,
      count3: 1,
    );

    test('udio se mjeri prema ukupnom broju, ne prema najvećem redu', () {
      // Normalizacija na maksimum bi svakom salonu nacrtala jednu punu traku, pa bi
      // salon sa 5 petica izgledao isto kao salon sa 500.
      expect(summary.share(5), closeTo(21 / 25, 0.0001));
      expect(summary.share(4), closeTo(3 / 25, 0.0001));
      expect(summary.share(1), 0);
    });

    test('salon bez ocjena ne dijeli sa nulom', () {
      const prazan = SalonRatingSummary(salonId: salonId, average: 0, total: 0);
      expect(prazan.share(5), 0);
    });

    test('countFor van opsega vraća nulu umjesto da baci', () {
      expect(summary.countFor(0), 0);
      expect(summary.countFor(6), 0);
    });
  });

  group('StaffReviewRepository.forSalon', () {
    Map<String, dynamic> red(
      String id,
      String createdAt, {
      String? comment,
      bool published = true,
    }) => {
      'id': id,
      'salon_id': salonId,
      'author_name': 'Ana K.',
      'rating': 4,
      'comment': comment,
      'created_at': createdAt,
      'is_published': published,
    };

    test('svaka javno prikazana recenzija je i u Meluri, i kad je potisnu gole ocjene', () async {
      // Scenario iz pregleda: novije gole ocjene popune granicu, a starije tekstualne
      // klijent i dalje prikazuje. Jedan upit nad svim vrstama bi ih odsjekao, pa ih
      // salon ne bi mogao sakriti.
      final javna = red('javna', '2026-09-01T09:00:00+00:00', comment: 'Top');
      final gola = red('gola', '2026-10-01T09:00:00+00:00');
      final sakrivena = red(
        'sakrivena',
        '2026-10-02T09:00:00+00:00',
        comment: 'Ružno',
        published: false,
      );

      final zahtjevi = <http.Request>[];
      final client = SupabaseClient(
        'http://127.0.0.1:54321',
        'anon',
        httpClient: MockClient((zahtjev) async {
          zahtjevi.add(zahtjev);
          final javniUpit = zahtjev.url.query.contains('is_published=eq.true');
          return http.Response(
            jsonEncode(javniUpit ? [javna] : [sakrivena, gola]),
            200,
            // `postgrest` čita `response.request` — v. `staff_appointment_repository_test`.
            request: zahtjev,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final recenzije = await StaffReviewRepository(client).forSalon(salonId);

      expect(recenzije.map((r) => r.id), ['sakrivena', 'gola', 'javna']);
      expect(recenzije.first.isPublished, isFalse);

      // Javni upit je doslovno klijentski: objavljene, sa tekstom, ista granica.
      final javni = zahtjevi
          .map((z) => z.url.queryParameters)
          .singleWhere((q) => q['is_published'] == 'eq.true');
      expect(javni['comment'], 'neq.');
      expect(javni['limit'], '${ReviewRepository.maxReviews}');
    });
  });
}
