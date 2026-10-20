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

  /// Sve recenzije salona, najnovije prvo, i one bez teksta: salon vidi i gole ocjene.
  ///
  /// Granica je ista kao na klijentu ([ReviewRepository.maxReviews]); prosjek je u
  /// `salon_rating_summary`, pa skraćena lista ne pomjera broj.
  Future<List<Review>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('reviews')
        .select(_columns)
        .eq('salon_id', salonId)
        .order('created_at', ascending: false)
        .limit(ReviewRepository.maxReviews);
    return [for (final row in rows) _recenzija(row)];
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
