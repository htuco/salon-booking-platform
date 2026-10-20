import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'review_repository.dart';

/// Recenzije salona, čitane iz **admin** aplikacije (task 67).
///
/// Admin vidi i sakrivene (politika `staff_read`), a od pisanja ima samo
/// [setPublished]: salon recenziju sakriva i vraća, ali tekst, ocjenu i autora ne mijenja.
/// Tabela mu više nema `update` grant, pa ni direktan upis odavde ne bi prošao.
///
/// `salonId` je preciznost upita, ne zaštita — isti razlog kao u `StaffCustomerRepository`.
class StaffReviewRepository {
  const StaffReviewRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, salon_id, author_name, rating, comment, created_at, is_published';

  /// Recenzije salona za Meluru, najnovije prvo: i gole ocjene i sakrivene.
  ///
  /// **Dva upita, jer jedna granica ne pokriva javnu listu.** Klijent prikazuje
  /// [ReviewRepository.maxReviews] najnovijih *objavljenih sa tekstom*; jedan upit nad
  /// svim vrstama sa istom granicom bi ih, kad salon ima puno novih golih ocjena, odsjekao
  /// — a javna recenzija koju salon ne vidi je recenzija koju ne može sakriti. Zato prvi
  /// upit **jeste** klijentski ([ReviewRepository.forSalon], isti filter i granica), pa je
  /// svaki javno prikazan red ovdje po konstrukciji. Drugi daje najnovije svih vrsta (i gole
  /// ocjene i sakrivene), do iste granice; red koji stigne iz oba se broji jednom.
  ///
  /// Starije gole i sakrivene recenzije van te granice se ne vide; kad salon dođe do toga,
  /// ovo postaje straničenje. Prosjek je u `salon_rating_summary`, pa granica ne pomjera broj.
  Future<List<Review>> forSalon(String salonId) => guard(() async {
    // Redom, ne paralelno: `(a, b).wait` grešku umota u `ParallelWaitError`, koji
    // `guard` ne prepoznaje, a ekran koji se rijetko otvara ne treba uštedu jednog RTT-a.
    final javne = await ReviewRepository(_client).forSalon(salonId);
    final sve = await _client
        .from('reviews')
        .select(_columns)
        .eq('salon_id', salonId)
        .order('created_at', ascending: false)
        .limit(ReviewRepository.maxReviews);

    // Red iz drugog upita nosi `is_published`; javni je po filteru objavljen, pa je isti.
    final poId = <String, Review>{
      for (final r in javne) r.id: r,
      for (final row in sve) row['id'] as String: _recenzija(row),
    };
    return poId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  /// Sakriva ([published] = `false`) ili vraća recenziju svog salona.
  Future<void> setPublished(String reviewId, {required bool published}) =>
      guard(() async {
        await _client.rpc<dynamic>(
          'set_review_published',
          params: {'p_review_id': reviewId, 'p_published': published},
        );
      });
}

Review _recenzija(Map<String, dynamic> row) {
  try {
    return Review.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan `reviews` red', cause: error);
  }
}
