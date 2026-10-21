/// Pozivi `platform_*` RPC-ova kroz PostgREST, sa service role ključem.
///
/// Sve što konzola piše u bazu ide kroz ove funkcije (migracija `super_admin_konzola`).
/// Validacija je tamo, pa ovaj sloj samo prenosi poruku baze.
library;

import 'dart:convert';
import 'dart:io';

import 'okruzenje.dart';

class Platforma {
  Platforma(this._okruzenje, {HttpClient? klijent})
    : _http = klijent ?? HttpClient();

  final Okruzenje _okruzenje;
  final HttpClient _http;

  Future<List<Map<String, Object?>>> saloni() async =>
      _lista(await _rpc('platform_list_salons', const {}));

  /// Vertikale za izbor u formi. `vertical_packs` je javni katalog, pa ovo nije platformski
  /// podatak, ali ide istim ključem da konzola ne drži dva.
  Future<List<Map<String, Object?>>> vertikale() async => _lista(
    await _zahtjev(
      'GET',
      'rest/v1/vertical_packs',
      upit: {'select': 'key,display_name,default_theme', 'order': 'key'},
    ),
  );

  /// Teme koje baza prima (`private.known_themes`). Konzola ih ne drži sama, pa izbor u formi
  /// ne može ponuditi temu koju bi baza odbila.
  Future<List<String>> teme() async {
    final podaci = await _rpc('platform_list_themes', const {});
    if (podaci is! List) {
      throw const PlatformaGreska(
        'neocekivano',
        'Baza nije vratila listu tema.',
      );
    }
    return [for (final t in podaci) '$t'];
  }

  /// `p_id` u [polja] je UUID iz `tenant.yaml`-a kad salon već postoji u drugom okruženju.
  Future<String> napraviSalon(Map<String, Object?> polja) async =>
      '${await _rpc('platform_create_salon', polja)}';

  Future<void> postaviStatus(String salonId, String status) => _rpc(
    'platform_set_salon_status',
    {'p_salon_id': salonId, 'p_status': status},
  );

  Future<void> postaviBranding(
    String salonId, {
    required String tema,
    required String primarna,
    required String sekundarna,
  }) => _rpc('platform_set_branding', {
    'p_salon_id': salonId,
    'p_theme': tema,
    'p_primary_color': primarna,
    'p_secondary_color': sekundarna,
  });

  Future<void> postaviStore(String salonId, String store, String status) =>
      _rpc('platform_set_store_status', {
        'p_salon_id': salonId,
        'p_store': store,
        'p_status': status,
      });

  /// Kod se vidi samo ovdje, jednom. Baza čuva hash.
  Future<Map<String, Object?>> pozivVlasnika(String salonId, String ime) async {
    final redovi = _lista(
      await _rpc('platform_create_owner_invite', {
        'p_salon_id': salonId,
        'p_name': ime,
      }),
    );
    if (redovi.length != 1) {
      throw const PlatformaGreska('neocekivano', 'Baza nije vratila poziv.');
    }
    return redovi.single;
  }

  /// Povlači otvoren poziv platforme. Poziv koji je napravio salon baza ne dira (`PT404`).
  Future<void> povuciPoziv(String salonId, String pozivId) => _rpc(
    'platform_revoke_owner_invite',
    {'p_salon_id': salonId, 'p_invite_id': pozivId},
  );

  void zatvori() => _http.close(force: true);

  Future<Object?> _rpc(String funkcija, Map<String, Object?> parametri) =>
      _zahtjev('POST', 'rest/v1/rpc/$funkcija', tijelo: parametri);

  Future<Object?> _zahtjev(
    String metoda,
    String putanja, {
    Map<String, String>? upit,
    Map<String, Object?>? tijelo,
  }) async {
    final uri = _okruzenje.url.resolve(putanja).replace(queryParameters: upit);
    final HttpClientResponse odgovor;
    final String tekst;
    try {
      final zahtjev = await _http.openUrl(metoda, uri);
      zahtjev.headers.set('apikey', _okruzenje.kljuc);
      // Stari service role ključ je JWT i ide i u Authorization. Novi `sb_secret_` nije JWT i
      // gateway ga čita samo iz `apikey`.
      if (_okruzenje.kljuc.startsWith('eyJ')) {
        zahtjev.headers.set('authorization', 'Bearer ${_okruzenje.kljuc}');
      }
      zahtjev.headers.contentType = ContentType.json;
      if (tijelo != null) zahtjev.write(jsonEncode(tijelo));
      odgovor = await zahtjev.close();
      tekst = await odgovor.transform(utf8.decoder).join();
    } on SocketException catch (e) {
      throw PlatformaGreska(
        'mreza',
        'Supabase na ${uri.host} ne odgovara (${e.message}).',
      );
    }

    final Object? podaci = tekst.isEmpty ? null : _json(tekst);
    if (odgovor.statusCode >= 400) {
      if (podaci is Map) {
        throw PlatformaGreska(
          '${podaci['code'] ?? odgovor.statusCode}',
          '${podaci['message'] ?? 'Greška ${odgovor.statusCode}'}',
        );
      }
      throw PlatformaGreska(
        '${odgovor.statusCode}',
        'Greška ${odgovor.statusCode}',
      );
    }
    return podaci;
  }

  Object? _json(String tekst) {
    try {
      return jsonDecode(tekst);
    } on FormatException {
      return tekst;
    }
  }

  List<Map<String, Object?>> _lista(Object? podaci) {
    if (podaci is! List) {
      throw const PlatformaGreska('neocekivano', 'Baza nije vratila listu.');
    }
    return [for (final red in podaci) Map<String, Object?>.from(red as Map)];
  }
}

/// Greška baze, sa njenim kodom (`PT400`, `PT409`, `42501`...) i porukom za čovjeka.
class PlatformaGreska implements Exception {
  const PlatformaGreska(this.kod, this.poruka);
  final String kod;
  final String poruka;
  @override
  String toString() => '$kod: $poruka';
}
