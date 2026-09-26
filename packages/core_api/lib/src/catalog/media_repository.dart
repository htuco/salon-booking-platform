import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

// Lokalna provjera baca isti izuzetak koji bi vratio bucket, pa poruku za korisnika gradi
// jedno mjesto — `_mapStorage` u `error_mapper.dart`.

/// Vrsta slike — drugi segment putanje u bucketu (`<salon_id>/<vrsta>/<fajl>`).
///
/// Task 51 (čišćenje) po vrsti zna koju kolonu da uporedi sa sadržajem foldera, pa se
/// vrsta ne izmišlja na ekranu nego bira ovdje.
enum MediaKind { usluge, radnici, galerija, logo, cover }

/// Slike salona u Storage bucketu `salon-media` (task 48, ADR-0015).
///
/// Upis dozvoljava samo politika nad `storage.objects` — vlasnik salona iz prvog segmenta
/// putanje. Ovaj sloj ne provjerava prava; on samo gradi putanju koju politika razumije.
class MediaRepository {
  MediaRepository(this._client, {Random? random})
    : _random = random ?? Random.secure();

  final SupabaseClient _client;
  final Random _random;

  static const bucket = 'salon-media';

  /// Najveća veličina koju bucket prima. Aplikacija je provjerava prije slanja samo da
  /// bi poruka bila jasna; granicu drži bucket.
  static const maxBytes = 5 * 1024 * 1024;

  static const _ekstenzije = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// Pošalje sliku i vrati njen javni URL — vrijednost za `image_url` ili `gallery_urls`.
  ///
  /// **Svaki upload dobija novo ime.** Zamjena slike ne prepisuje stari objekat: javni URL
  /// se kešira (CDN, `Image.network`), pa bi isto ime pokazivalo staru sliku. Stari objekat
  /// postaje siroče koje čisti task 51 — sve u folderu vrste što nijedna kolona ne
  /// referencira.
  Future<String> upload({
    required String salonId,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
  }) => guard(() async {
    // Sadržaj je jači od deklarisanog tipa: `image_picker` na Androidu često ne zna tip,
    // pa bi fotografija bez ekstenzije u imenu bila odbijena kao „nije slika".
    final tip = tipIzSadrzaja(bytes) ?? contentType;
    final ekstenzija = _ekstenzije[tip];
    if (ekstenzija == null) {
      throw const StorageException(
        'mime type not supported',
        statusCode: '415',
      );
    }
    if (bytes.length > maxBytes) {
      throw const StorageException(
        'maximum allowed size exceeded',
        statusCode: '413',
      );
    }
    final putanja = '$salonId/${kind.name}/${_ime()}.$ekstenzija';
    final storage = _client.storage.from(bucket);
    await storage.uploadBinary(
      putanja,
      bytes,
      fileOptions: FileOptions(contentType: tip, upsert: false),
    );
    return storage.getPublicUrl(putanja);
  });

  /// JPEG, PNG ili WebP po prvim bajtovima; `null` za sve ostalo (HEIC, SVG, tekst).
  static String? tipIzSadrzaja(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  String _ime() {
    final vrijeme = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(
      36,
    );
    final slucajno = List.generate(
      8,
      (_) => _random.nextInt(36).toRadixString(36),
    ).join();
    return '$vrijeme-$slucajno';
  }
}
