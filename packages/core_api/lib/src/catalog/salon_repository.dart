import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'media_repository.dart';

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

  /// Mijenja kontakt podatke salona — `public.update_salon_contact`, samo iz admina.
  ///
  /// **Nema `update` nad `salons` iz aplikacije.** Grant je oduzet u tasku 36, pa je ovo
  /// jedini put; tuđi salon i pozivalac koji nije njegov admin daju istu `42501`.
  ///
  /// **Boje, `status`, `plan` i `slug` nisu ovdje i to nije propust.** Boje dolaze iz
  /// `tenant.yaml` kroz generator — polje za boju u adminu bi napravilo drugi izvor
  /// istine za isti podatak, i sljedeće generisanje bi ga vratilo na staro. Logo i cover
  /// su runtime slike salona i idu kroz [setImage].
  ///
  /// [facebookUrl] je **stranica salona kao kontakt**, ne prijava Facebookom; ta ne
  /// postoji (`docs/adr/0011-facebook-login-se-ne-implementira.md`).
  ///
  /// Prazan string za opciona polja baza pretvara u `null` — „nema telefona" i „telefon
  /// je prazan" su isto stanje i ne razdvajaju se ovdje.
  Future<Salon> updateContact({
    required String salonId,
    required String expectedName,
    required String address,
    required String city,
    String description = '',
    String? phone,
    String? email,
    String? instagramUrl,
    String? facebookUrl,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'update_salon_contact',
      params: {
        'p_salon_id': salonId,
        // Naziv je build-time podatak. RPC ga prima kao optimistic assertion da forma
        // nije pokušala promjenu, ne kao vrijednost koju treba upisati.
        'p_name': expectedName,
        'p_address': address,
        'p_city': city,
        'p_description': description,
        'p_phone': phone,
        'p_email': email,
        'p_instagram_url': instagramUrl,
        'p_facebook_url': facebookUrl,
      },
    );
    return salonFromRow(Map<String, dynamic>.from(row as Map));
  });

  /// Postavlja ili briše logo ili naslovnu sliku — `public.set_salon_image` (task 50).
  ///
  /// Jedna kolona po pozivu: forma koja bi slala obje vrijednosti bi zamjenom loga vratila
  /// cover koji je drugi tab u međuvremenu promijenio. [url] mora biti javni URL objekta
  /// ovog salona iz [MediaRepository.upload] sa istom vrstom; `null` briše sliku.
  ///
  /// App ikona i splash **nisu** ovo — oni su build artefakti iz `tenant.yaml`.
  Future<Salon> setImage({
    required String salonId,
    required SalonImage kind,
    required String? url,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'set_salon_image',
      params: {'p_salon_id': salonId, 'p_kind': kind.name, 'p_url': url},
    );
    return salonFromRow(Map<String, dynamic>.from(row as Map));
  });

  /// Zamjenjuje galeriju — `public.set_salon_gallery` (task 50, ADR-0008).
  ///
  /// [expected] je niz koji je ekran učitao. Ako ga je u međuvremenu promijenio drugi tab
  /// ili uređaj, baza ne upisuje ništa i ovo baca [ConflictError] — ekran tada ponovo učita
  /// galeriju, umjesto da tiho pregazi tuđu izmjenu. Redoslijed [urls] je redoslijed prikaza.
  Future<List<String>> setGallery({
    required String salonId,
    required List<String> expected,
    required List<String> urls,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'set_salon_gallery',
      params: {'p_salon_id': salonId, 'p_expected': expected, 'p_urls': urls},
    );
    return galleryUrlsFromRow(row);
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

/// Slika salona koja se mijenja kroz [SalonRepository.setImage]. Ime je vrijednost
/// `p_kind` i ujedno folder u bucketu ([MediaKind.logo], [MediaKind.cover]).
enum SalonImage {
  logo,
  cover;

  MediaKind get mediaKind => switch (this) {
    SalonImage.logo => MediaKind.logo,
    SalonImage.cover => MediaKind.cover,
  };
}
