import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Recenzije salona i sažetak ocjena (`SPEC.md` 5m).
///
/// Radi **bez prijave**: politika `public_published` daje `select` roli `anon`, ali samo za
/// objavljene recenzije aktivnog salona. Sakrivena recenzija i recenzija neaktivnog salona
/// ne dolaze kao greška nego kao odsustvo reda — RLS ne vraća „zabranjeno".
///
/// **Pisanje ide samo kroz `submit_review`** (task 67). Klijent nema write grant nad
/// tabelom: RPC traži njegov završen termin u salonu iz `x-salon-id` i sam pravi ime
/// autora, pa [submit] ne šalje ni salon ni ime.
class ReviewRepository {
  const ReviewRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, salon_id, author_name, rating, comment, created_at';

  /// Gornja granica liste.
  ///
  /// Nije stranicenje nego zaštita: PostgREST ionako reže na `max_rows = 1000`, a ekran
  /// koji bez pitanja povuče hiljadu redova na mobilnoj mreži je ekran koji se ne otvara.
  /// Prosjek i histogram **ne zavise od ovog broja** — njih računa baza nad svim redovima,
  /// pa skraćena lista ne pomjera nijedan prikazani broj.
  static const maxReviews = 50;

  /// Recenzije **sa tekstom**, najnovije prvo.
  ///
  /// Filtriranje na `comment` ide u upit, ne u Dart: većina ocjena nema tekst (one nose
  /// histogram), pa bi povlačenje svih redova da bi se 4 od 25 prikazala bilo plaćanje
  /// prometa za podatak koji se odbaci.
  Future<List<Review>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('reviews')
        .select(_columns)
        .eq('salon_id', salonId)
        .not('comment', 'is', null)
        .neq('comment', '')
        .order('created_at', ascending: false)
        .limit(maxReviews);

    return [for (final row in rows) reviewFromRow(row)];
  });

  /// Prosjek, ukupan broj i histogram — jedan red iz `public.salon_rating_summary`.
  ///
  /// Vraća `null` kad salon nema nijednu ocjenu. **To nije greška nego stanje koje ekran
  /// crta drugačije:** sekcija se sakrije umjesto da pokaže „0,0 od 5", što bi izgledalo
  /// kao loš salon umjesto kao nov salon.
  Future<SalonRatingSummary?> summaryForSalon(String salonId) =>
      guard(() async {
        final row = await _client
            .from('salon_rating_summary')
            .select(
              'salon_id, average, total, count_5, count_4, count_3, count_2, count_1',
            )
            .eq('salon_id', salonId)
            .maybeSingle();

        return row == null ? null : ratingSummaryFromRow(row);
      });

  /// Ocjene koje je klijent dao za [appointmentIds], kao `appointment_id → ocjena`.
  ///
  /// Upit ide **po mojim terminima**, ne po identitetu: klijent ne zna svoj
  /// `auth_identity_id`, a javna politika mu daje i tuđe objavljene recenzije sa terminom.
  /// Tuđa recenzija ne može nositi ID mog termina, pa filter po njima vraća samo moje —
  /// i sakrivene, kroz politiku `client_own`.
  Future<Map<String, int>> myRatings(
    String salonId,
    Iterable<String> appointmentIds,
  ) => guard(() async {
    final ids = appointmentIds.toList();
    if (ids.isEmpty) return const <String, int>{};
    final rows = await _client
        .from('reviews')
        .select('appointment_id, rating')
        .eq('salon_id', salonId)
        .inFilter('appointment_id', ids);
    return {
      for (final row in rows)
        row['appointment_id'] as String: (row['rating'] as num).toInt(),
    };
  });

  /// Ocjena završenog termina, 1–5, uz opcionalan tekst.
  ///
  /// Druga ocjena istog termina stiže kao [ConflictError] (`PT409`), termin koji salon još
  /// nije označio završenim kao [ServerError] sa porukom baze (`PT400`).
  Future<void> submit({
    required String appointmentId,
    required int rating,
    String? comment,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'submit_review',
      params: {
        'p_appointment_id': appointmentId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );
  });

  /// Najduži tekst koji baza prima.
  static const maxCommentLength = 1000;
}

/// Mapira `reviews` red na [Review].
///
/// Izdvojeno iz repozitorija da se mapiranje testira bez lažiranja PostgREST builder lanca —
/// isti obrazac kao `salonFromRow`.
@visibleForTesting
Review reviewFromRow(Map<String, dynamic> row) {
  try {
    return Review.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan `reviews` red', cause: error);
  }
}

/// Mapira red pogleda `salon_rating_summary` na [SalonRatingSummary].
///
/// `average` stiže kao `numeric`, što `supabase_flutter` daje kao `String` ili `num` ovisno
/// o vrijednosti — `4.8` zna doći kao `"4.8"`. Zato se normalizuje ovdje, jednom, umjesto da
/// svaki pozivalac pogađa tip.
@visibleForTesting
SalonRatingSummary ratingSummaryFromRow(Map<String, dynamic> row) {
  try {
    final average = row['average'];
    return SalonRatingSummary.fromJson({
      ...row,
      'average': average is num ? average.toDouble() : double.parse('$average'),
    });
  } catch (error) {
    throw MappingError('Neispravan `salon_rating_summary` red', cause: error);
  }
}
