import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Čita salon po `id`-u — jedan red iz `public.salons`.
///
/// Radi **bez prijave**: politika `public_salons` daje `select` roli `anon`, ali samo za
/// `status = 'active'`. Neaktivan salon zato izgleda isto kao nepostojeći — oboje su
/// [NotFoundError]. To nije propust nego posljedica toga da RLS ne vraća "zabranjeno" nego
/// prazan rezultat.
///
/// `salonId` dolazi iz builda (`SALON_ID`), ne iz korisnika — tenant scope se ne izvodi iz
/// toga ko je prijavljen.
class SalonRepository {
  const SalonRepository(this._client);

  final SupabaseClient _client;

  /// Kolone se nabrajaju umjesto `select('*')`: `salons` je najšira tabela u šemi i nosi
  /// polja koja klijentski app nikad ne prikazuje (`plan`, `status`, `terminology_override`).
  static const _columns = '''
id, name, slug, description, logo_url, cover_image_url,
primary_color, secondary_color, theme, address, city,
phone, email, instagram_url, facebook_url, vertical_pack_key
''';

  /// Vraća salon, ili baca [NotFoundError] ako ga nema (ili nije aktivan).
  ///
  /// Za razliku od `VerticalRepository.fetchForSalon`, ovdje se **baca** umjesto fallbacka:
  /// vertikala ima smislen generic default, a salon nema — ekran bez imena, boje i adrese
  /// nije ekran koji vrijedi prikazati.
  Future<Salon> byId(String salonId) => guard(() async {
    final row = await _client
        .from('salons')
        .select(_columns)
        .eq('id', salonId)
        .maybeSingle();

    if (row == null) {
      throw NotFoundError('Salon $salonId ne postoji ili nije aktivan');
    }
    return salonFromRow(row);
  });

  /// Galerija salona — `salons.gallery_urls jsonb`, lista URL-ova.
  ///
  /// Zaseban upit, a ne kolona u [byId]: `Salon` je `freezed` model, a `freezed` 3.2.5
  /// za `List` polje generiše kod koji aktuelni Dart odbija (v. `salon.dart`). Dok se
  /// generator ne podigne, lista stiže mimo modela.
  ///
  /// **Prazna lista nije greška.** Salon bez galerije je predviđeno stanje — ekran tada
  /// sakrije sekciju umjesto da prikaže praznu mrežu. Isto vrijedi za red koji RLS ne
  /// vrati: prazno, ne izuzetak, jer galerija nije razlog da Početna padne.
  Future<List<String>> galleryUrls(String salonId) => guard(() async {
    final row = await _client
        .from('salons')
        .select('gallery_urls')
        .eq('id', salonId)
        .maybeSingle();

    return galleryUrlsFromRow(row?['gallery_urls']);
  });
}

/// Mapira `gallery_urls` u listu URL-ova, preskačući sve što nije neprazan string.
///
/// `jsonb` kolona nema šemu — `["a", null, 3, ""]` je validan sadržaj te kolone i doći
/// će prije ili kasnije, iz admin konzole ili iz ručnog `update`-a. Padati na tome bi
/// značilo da jedan loš red u bazi obori Početnu.
@visibleForTesting
List<String> galleryUrlsFromRow(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  ];
}

/// Mapira `salons` red na [Salon].
///
/// Izdvojeno iz repozitorija da se mapiranje testira bez lažiranja cijelog PostgREST
/// builder lanca — `.from().select().eq()` je tuđi kod koji test ne treba dokazivati
/// ponovo. Isti obrazac kao `verticalFromSalonRow`.
@visibleForTesting
Salon salonFromRow(Map<String, dynamic> row) {
  try {
    return Salon.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan `salons` red', cause: error);
  }
}
