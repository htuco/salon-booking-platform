/// HTTP server konzole: jedna stranica i mali JSON API, samo na loopbacku (ADR-0032 §1).
///
/// Tri provjere na svakom zahtjevu, prije bilo čega drugog:
///   1. `Host` je tačno naš (`127.0.0.1:<port>` ili `localhost:<port>`). Tuđa stranica koja
///      DNS rebindingom pogodi naš port šalje svoj host i pada ovdje.
///   2. API traži `x-konzola-token`, nasumičan po pokretanju. Custom header tuđa stranica ne
///      može poslati bez CORS preflighta, a na preflight server ne odgovara dozvolom.
///   3. `Origin`, kad postoji, mora biti naš.
/// Upis na projekat koji nije lokalni traži i `x-potvrda` sa imenom projekta.
///
/// Sama stranica (`GET /`) ne traži token: u njoj nema ničeg tajnog (statičan HTML, bez
/// podataka i bez ključa), a token iz adrese čuva u `sessionStorage` taba i briše ga iz adresne
/// trake. Zato F5 radi, a token ne ostaje vidljiv na ekranu ni u adresi koja se kopira.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'okruzenje.dart';
import 'platforma.dart';
import 'repo.dart';
import 'tenant_fajl.dart';

/// Prefiks ID-a aplikacije. CI provjerava `ba.nasadomena.<flavor>` u APK-u, pa se ID izvodi iz
/// flavora i ne kuca se. Prava domena dolazi u tasku 75 i mijenja se ovdje i u šablonu.
const idPrefiks = 'ba.nasadomena';

const _statusiStorea = ['draft', 'in_review', 'live'];

class Konzola {
  Konzola({
    required this.okruzenje,
    required this.platforma,
    required this.repo,
    String? token,
  }) : token = token ?? _nasumicanToken();

  final Okruzenje okruzenje;
  final Platforma platforma;
  final Repo repo;
  final String token;

  HttpServer? _server;

  int get port => _server!.port;
  Uri get adresa => Uri.parse('http://127.0.0.1:$port/?t=$token');

  Future<void> pokreni({int port = 4710}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_obradi);
  }

  Future<void> zaustavi() async {
    await _server?.close(force: true);
    platforma.zatvori();
  }

  Future<void> _obradi(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('cache-control', 'no-store')
      ..set('x-frame-options', 'DENY')
      ..set('x-content-type-options', 'nosniff')
      ..set('referrer-policy', 'no-referrer');
    try {
      if (!_nasHost(req.headers.value('host'))) {
        return await _greska(res, 403, 'Pogrešan host.');
      }
      final origin = req.headers.value('origin');
      if (origin != null && !_nasHost(Uri.tryParse(origin)?.authority)) {
        return await _greska(res, 403, 'Pogrešan origin.');
      }

      final putanja = req.uri.path;
      if (putanja == '/favicon.ico') {
        res.statusCode = 204;
        return await res.close();
      }
      if (req.method == 'GET' && putanja == '/') {
        return await _stranica(res);
      }
      if (!putanja.startsWith('/api/')) {
        return await _greska(res, 404, 'Nema te stranice.');
      }
      if (!_isti(req.headers.value('x-konzola-token') ?? '', token)) {
        return await _greska(
          res,
          403,
          'Nema tokena sesije. Otvori adresu koju je konzola ispisala u terminalu.',
        );
      }

      if (req.method == 'GET' && putanja == '/api/stanje') {
        return await _json(res, 200, await stanje());
      }
      if (req.method != 'POST') {
        return await _greska(res, 405, 'Samo GET i POST.');
      }
      if (!okruzenje.lokalno &&
          req.headers.value('x-potvrda') != okruzenje.projekat) {
        return await _greska(
          res,
          428,
          'Upis na ${okruzenje.projekat} traži potvrdu imenom projekta.',
        );
      }

      final tijelo = await _tijelo(req);
      final segmenti =
          req.uri.pathSegments; // ['api', 'saloni', ':id', 'akcija']
      if (putanja == '/api/saloni') {
        return await _json(res, 200, await napraviSalon(tijelo));
      }
      if (segmenti.length == 4 && segmenti[1] == 'saloni') {
        final id = segmenti[2];
        final odgovor = switch (segmenti[3]) {
          'status' => await postaviStatus(id, tijelo),
          'branding' => await postaviBranding(id, tijelo),
          'store' => await postaviStore(id, tijelo),
          'poziv' => await pozivVlasnika(id, tijelo),
          'povuci-poziv' => await povuciPoziv(id, tijelo),
          'tenant' => await napisiTenantPonovo(id, tijelo),
          'generatori' => await ponoviGeneratore(id),
          _ => null,
        };
        if (odgovor != null) return await _json(res, 200, odgovor);
      }
      // ['api', 'tenanti', ':flavor', 'upisi']
      if (segmenti.length == 4 &&
          segmenti[1] == 'tenanti' &&
          segmenti[3] == 'upisi') {
        return await _json(res, 200, await upisiIzFajla(segmenti[2], tijelo));
      }
      return await _greska(res, 404, 'Nepoznata akcija.');
    } on PlatformaGreska catch (e) {
      final status = switch (e.kod) {
        'PT400' => 400,
        'PT404' => 404,
        'PT409' => 409,
        '42501' => 403,
        _ => 502,
      };
      return await _greska(res, status, e.poruka);
    } on ZahtjevGreska catch (e) {
      return await _greska(res, e.status, e.poruka);
    } on Object catch (e) {
      stderr.writeln('Greška konzole: $e');
      return await _greska(res, 500, 'Greška konzole: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Akcije
  // -------------------------------------------------------------------------

  /// Baza, fajlovi i CI matrica za svaki salon. Tenant na disku bez reda u bazi ide posebno:
  /// na hostovanom projektu su to demo tenanti, a inače znak da je fajl napisan rukom.
  Future<Map<String, Object?>> stanje() async {
    final saloni = await platforma.saloni();
    final vertikale = await platforma.vertikale();
    final teme = await platforma.teme();
    final tenanti = repo.tenanti();
    final matrice = repo.ciMatrice();
    final uBazi = <String>{};

    final redovi = <Map<String, Object?>>[];
    for (final s in saloni) {
      uBazi.add('${s['id']}');
      final flavor = s['flavor'] as String?;
      final fajl = flavor == null ? null : tenanti[flavor];
      redovi.add({
        ...s,
        'tenant': fajl == null
            ? {'postoji': false}
            : {'postoji': true, 'ios': fajl.ios, 'razlike': _razlike(s, fajl)},
        'ci': {
          for (final e in matrice.entries)
            e.key: flavor != null && e.value.contains(flavor),
        },
      });
    }
    return {
      'okruzenje': {
        'host': okruzenje.url.host,
        'lokalno': okruzenje.lokalno,
        'projekat': okruzenje.projekat,
        'izvor': okruzenje.izvor,
      },
      'teme': teme,
      'vertikale': vertikale,
      'saloni': redovi,
      // Fajl bez reda u ovoj bazi: salon napravljen u drugom okruženju, ili lokalna baza
      // poslije `db reset`. Konzola ga upiše iz fajla, sa istim UUID-om.
      'samoFajl': [
        for (final t in tenanti.values)
          if (!uBazi.contains(t.salonId))
            {
              'flavor': t.flavor,
              'salonId': t.salonId,
              'naziv': t.naziv ?? t.imeAplikacije,
              'grad': t.grad ?? '',
              'imeAplikacije': t.imeAplikacije,
              'vertikala': t.vertical,
              'tema': t.tema,
            },
      ],
    };
  }

  Future<Map<String, Object?>> napraviSalon(Map<String, Object?> b) async {
    final flavor = _tekst(b, 'flavor');
    final ios = b['ios'] == true;
    final ikona = _ikona(b);
    // Folder koji već postoji znači da neko radi ovaj tenant rukom. Baza se ne dira dok se to
    // ne razjasni, jer bi salon u bazi ostao bez svog fajla.
    if (repo.tenantYaml(flavor).parent.existsSync()) {
      throw ZahtjevGreska(409, 'Folder tenants/$flavor već postoji.');
    }

    final id = await platforma.napraviSalon({
      'p_name': _tekst(b, 'naziv'),
      'p_slug': _tekst(b, 'slug'),
      'p_city': _tekst(b, 'grad'),
      'p_vertical': _tekst(b, 'vertikala'),
      'p_theme': b['tema'] is String && (b['tema'] as String).isNotEmpty
          ? b['tema']
          : null,
      'p_primary_color': _tekst(b, 'primarna'),
      'p_secondary_color': _tekst(b, 'sekundarna'),
      'p_flavor': flavor,
      'p_application_id': '$idPrefiks.$flavor',
      'p_bundle_id': '$idPrefiks.$flavor',
      'p_display_name': _tekst(b, 'imeAplikacije'),
      'p_plan': b['plan'] is String ? b['plan'] : 'starter',
    });

    // Od ovog trenutka salon postoji. Šta god padne ispod, konzola to kaže i nudi ponovo:
    // bez fajla „Napiši tenant.yaml", sa fajlom „Ponovi generatore".
    final koraci = <Map<String, Object?>>[];
    try {
      _napisiTenant(await _salon(id), ios: ios);
    } on Object catch (e) {
      koraci.add(Korak('tenant.yaml', uspjeh: false, izlaz: '$e').json);
      return {'id': id, 'koraci': koraci};
    }
    koraci.add(
      Korak(
        'tenant.yaml',
        uspjeh: true,
        izlaz: 'tenants/$flavor/tenant.yaml',
      ).json,
    );
    if (ikona != null) {
      try {
        repo.ikona(flavor)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(ikona);
        koraci.add(
          Korak(
            'Ikona',
            uspjeh: true,
            izlaz: 'tenants/$flavor/assets/icon.png',
          ).json,
        );
      } on Object catch (e) {
        // Generatori se ne pokreću: placeholder bi zauzeo mjesto ikone, a ne bi se vidjelo
        // da prava ikona fali. Fajl postoji, pa „Ponovi generatore" nastavlja odavde.
        koraci.add(
          Korak(
            'Ikona',
            uspjeh: false,
            izlaz:
                '$e\n\nStavi ikonu u tenants/$flavor/assets/icon.png rukom, pa „Ponovi generatore".',
          ).json,
        );
        return {'id': id, 'koraci': koraci};
      }
    }
    koraci.addAll((await repo.generisi()).map((k) => k.json));
    return {'id': id, 'koraci': koraci};
  }

  /// Samo kad fajla nema (pad između baze i fajla). Postojeći fajl je čovjekov i ne prepisuje se.
  Future<Map<String, Object?>> napisiTenantPonovo(
    String id,
    Map<String, Object?> b,
  ) async {
    final salon = await _salon(id);
    final flavor = salon['flavor'] as String?;
    if (flavor == null) {
      throw ZahtjevGreska(409, 'Salon nema build red ni flavor.');
    }
    if (repo.tenantYaml(flavor).existsSync()) {
      throw ZahtjevGreska(
        409,
        'tenants/$flavor/tenant.yaml već postoji i ne prepisuje se. '
        'Za generatore: „Ponovi generatore".',
      );
    }
    _napisiTenant(salon, ios: b['ios'] == true);
    return {
      'koraci': [
        Korak(
          'tenant.yaml',
          uspjeh: true,
          izlaz: 'tenants/$flavor/tenant.yaml',
        ).json,
        ...(await repo.generisi()).map((k) => k.json),
      ],
    };
  }

  /// Salon iz `tenant.yaml`-a u bazu ovog okruženja, sa **istim UUID-om** (`p_id`). Za salon
  /// napravljen u drugom okruženju, i za lokalni stack poslije `db reset`. Fajl se ne piše i
  /// generatori se ne pokreću: fajl je već tu i generisano se ne mijenja.
  ///
  /// Naziv salona i grad nisu polja fajla. Dolaze iz tijela (forma ih predloži iz prvog
  /// komentara fajla), a naziv bez toga pada na ime aplikacije.
  Future<Map<String, Object?>> upisiIzFajla(
    String flavor,
    Map<String, Object?> b,
  ) async {
    if (!RegExp(r'^[a-z][a-z0-9]*$').hasMatch(flavor)) {
      throw ZahtjevGreska(400, 'Flavor nije ispravan.');
    }
    final fajl = repo.tenantYaml(flavor);
    if (!fajl.existsSync()) {
      throw ZahtjevGreska(404, 'Nema tenants/$flavor/tenant.yaml.');
    }
    final TenantNaDisku t;
    try {
      t = TenantNaDisku.procitaj(fajl.readAsStringSync());
    } on Object catch (e) {
      throw ZahtjevGreska(400, 'tenants/$flavor/tenant.yaml se ne čita: $e');
    }
    if (t.flavor != flavor) {
      throw ZahtjevGreska(
        400,
        'tenants/$flavor/tenant.yaml ima flavor „${t.flavor}" — mora biti isti kao folder.',
      );
    }
    String? polje(String kljuc) {
      final v = b[kljuc];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final naziv = polje('naziv') ?? t.naziv ?? t.imeAplikacije;
    final grad = polje('grad') ?? t.grad;
    if (grad == null) {
      throw ZahtjevGreska(400, 'Grad nije u fajlu — upiši ga.');
    }
    final id = await platforma.napraviSalon({
      'p_name': naziv,
      'p_slug': t.slug,
      'p_city': grad,
      'p_vertical': t.vertical,
      'p_theme': t.tema,
      'p_primary_color': t.primarna,
      'p_secondary_color': t.sekundarna,
      'p_flavor': t.flavor,
      'p_application_id': t.applicationId,
      'p_bundle_id': t.bundleId,
      'p_display_name': t.imeAplikacije,
      'p_plan': polje('plan') ?? 'starter',
      'p_id': t.salonId,
    });
    return {
      'id': id,
      'koraci': [
        Korak(
          'Baza',
          uspjeh: true,
          izlaz: 'Salon $id upisan iz tenants/$flavor/tenant.yaml.',
        ).json,
      ],
    };
  }

  /// gen_flavors, placeholder ikona i launcher ikone za salon koji ima fajl. Za pad generatora
  /// ili ikone pri pravljenju salona, i za ikonu koju je developer stavio rukom.
  Future<Map<String, Object?>> ponoviGeneratore(String id) async {
    final flavor = (await _salon(id))['flavor'] as String?;
    if (flavor == null || !repo.tenantYaml(flavor).existsSync()) {
      throw ZahtjevGreska(
        409,
        'Salon nema tenant.yaml — prvo „Napiši tenant.yaml".',
      );
    }
    return {'koraci': (await repo.generisi()).map((k) => k.json).toList()};
  }

  Future<Map<String, Object?>> postaviStatus(
    String id,
    Map<String, Object?> b,
  ) async {
    final status = _tekst(b, 'status');
    if (status != 'active' && status != 'inactive') {
      throw ZahtjevGreska(400, 'Status je active ili inactive.');
    }
    await platforma.postaviStatus(id, status);
    return {'ok': true};
  }

  /// Baza prva, pa fajl. Fallback u fajlu mora biti isti kao baza (`tenant-factory.md`).
  Future<Map<String, Object?>> postaviBranding(
    String id,
    Map<String, Object?> b,
  ) async {
    final tema = _tekst(b, 'tema');
    final primarna = _tekst(b, 'primarna');
    final sekundarna = _tekst(b, 'sekundarna');
    await platforma.postaviBranding(
      id,
      tema: tema,
      primarna: primarna,
      sekundarna: sekundarna,
    );

    final flavor = (await _salon(id))['flavor'] as String?;
    final fajl = flavor == null ? null : repo.tenantYaml(flavor);
    if (fajl == null || !fajl.existsSync()) {
      return {
        'koraci': [
          const Korak(
            'Baza',
            uspjeh: true,
            izlaz: 'Boje i tema su upisane.',
          ).json,
          const Korak(
            'tenant.yaml',
            uspjeh: false,
            izlaz: 'Fajla nema, pa fallback nije promijenjen.',
          ).json,
        ],
      };
    }
    try {
      fajl.writeAsStringSync(
        zamijeniBranding(
          fajl.readAsStringSync(),
          primarna: primarna,
          sekundarna: sekundarna,
          tema: tema,
        ),
      );
    } on FormatException catch (e) {
      return {
        'koraci': [
          const Korak(
            'Baza',
            uspjeh: true,
            izlaz: 'Boje i tema su upisane.',
          ).json,
          Korak(
            'tenant.yaml',
            uspjeh: false,
            izlaz: '${e.message} — ispravi fajl rukom.',
          ).json,
        ],
      };
    }
    return {
      'koraci': [
        const Korak(
          'Baza',
          uspjeh: true,
          izlaz: 'Boje i tema su upisane.',
        ).json,
        Korak(
          'tenant.yaml',
          uspjeh: true,
          izlaz: 'tenants/$flavor/tenant.yaml',
        ).json,
        (await repo.samoGenFlavors()).json,
      ],
    };
  }

  Future<Map<String, Object?>> postaviStore(
    String id,
    Map<String, Object?> b,
  ) async {
    final store = _tekst(b, 'store');
    final status = _tekst(b, 'status');
    if (!_statusiStorea.contains(status)) {
      throw ZahtjevGreska(400, 'Status storea je draft, in_review ili live.');
    }
    await platforma.postaviStore(id, store, status);
    return {'ok': true};
  }

  Future<Map<String, Object?>> pozivVlasnika(
    String id,
    Map<String, Object?> b,
  ) async {
    final ime = _tekst(b, 'ime');
    final salon = await _salon(id);
    final poziv = await platforma.pozivVlasnika(id, ime);
    return {
      'kod': poziv['code'],
      'istice': poziv['expires_at'],
      'poruka': porukaVlasniku(
        ime: ime,
        salon: '${salon['name']}',
        kod: '${poziv['code']}',
      ),
    };
  }

  Future<Map<String, Object?>> povuciPoziv(
    String id,
    Map<String, Object?> b,
  ) async {
    await platforma.povuciPoziv(id, _tekst(b, 'poziv'));
    return {'ok': true};
  }

  // -------------------------------------------------------------------------
  // Pomoćno
  // -------------------------------------------------------------------------

  Future<Map<String, Object?>> _salon(String id) async {
    final saloni = await platforma.saloni();
    return saloni.firstWhere(
      (s) => s['id'] == id,
      orElse: () => throw ZahtjevGreska(404, 'Salon ne postoji.'),
    );
  }

  void _napisiTenant(Map<String, Object?> s, {required bool ios}) {
    final flavor = '${s['flavor']}';
    repo.tenantYaml(flavor)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        napisiTenantYaml(
          NoviTenant(
            salonId: '${s['id']}',
            flavor: flavor,
            slug: '${s['slug']}',
            vertical: '${s['vertical_pack_key']}',
            naziv: '${s['name']}',
            grad: '${s['city']}',
            imeAplikacije: '${s['app_display_name']}',
            applicationId: '${s['application_id']}',
            bundleId: '${s['bundle_id']}',
            primarna: '${s['primary_color']}',
            sekundarna: '${s['secondary_color']}',
            tema: '${s['theme']}',
            ios: ios,
          ),
        ),
      );
  }

  List<String> _razlike(Map<String, Object?> s, TenantNaDisku t) => [
    if (t.salonId != s['id']) 'salonId',
    if (t.primarna != '${s['primary_color']}'.toUpperCase()) 'primarna boja',
    if (t.sekundarna != '${s['secondary_color']}'.toUpperCase())
      'sekundarna boja',
    if (t.tema != s['theme']) 'tema',
    if (t.imeAplikacije != s['app_display_name']) 'ime aplikacije',
  ];

  Uint8List? _ikona(Map<String, Object?> b) {
    final base64 = b['ikona'];
    if (base64 is! String || base64.isEmpty) return null;
    final Uint8List bajtovi;
    try {
      bajtovi = base64Decode(base64);
    } on FormatException {
      throw ZahtjevGreska(400, 'Ikona nije ispravno poslana.');
    }
    final greska = provjeriIkonu(bajtovi);
    if (greska != null) throw ZahtjevGreska(400, greska);
    return bajtovi;
  }

  String _tekst(Map<String, Object?> b, String kljuc) {
    final v = b[kljuc];
    if (v is! String || v.trim().isEmpty) {
      throw ZahtjevGreska(400, 'Polje „$kljuc" je obavezno.');
    }
    return v.trim();
  }

  bool _nasHost(String? host) =>
      host == '127.0.0.1:$port' || host == 'localhost:$port';

  Future<Map<String, Object?>> _tijelo(HttpRequest req) async {
    // Ikona od 1024 px je obično ispod 2 MB. Granica čuva server od slučajno poslanog videa.
    const granica = 8 * 1024 * 1024;
    final bajtovi = BytesBuilder(copy: false);
    await for (final dio in req) {
      bajtovi.add(dio);
      if (bajtovi.length > granica) {
        throw ZahtjevGreska(413, 'Zahtjev je prevelik.');
      }
    }
    if (bajtovi.isEmpty) return {};
    final Object? podaci;
    try {
      podaci = jsonDecode(utf8.decode(bajtovi.takeBytes()));
    } on FormatException {
      throw ZahtjevGreska(400, 'Tijelo nije JSON.');
    }
    if (podaci is! Map) throw ZahtjevGreska(400, 'Tijelo nije objekat.');
    return Map<String, Object?>.from(podaci);
  }

  Future<void> _stranica(HttpResponse res) async {
    // Preko korijena repoa, ne `Isolate.resolvePackageUri`: `flutter test` (melos) ga ne podržava.
    final html = await File(
      '${repo.korijen.path}/apps/superadmin/lib/src/ui/index.html',
    ).readAsString();
    res.statusCode = 200;
    res.headers
      ..contentType = ContentType.html
      ..set(
        'content-security-policy',
        "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
            "connect-src 'self'; img-src 'self' data: blob:; form-action 'none'; "
            "frame-ancestors 'none'; base-uri 'none'",
      );
    res.write(html);
    await res.close();
  }

  Future<void> _json(HttpResponse res, int status, Object? podaci) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(podaci));
    await res.close();
  }

  Future<void> _greska(HttpResponse res, int status, String poruka) =>
      _json(res, status, {'greska': poruka});
}

/// Tekst koji developer šalje vlasniku. Dugme na prijavi u Meluri se zove tačno ovako
/// (`login_screen.dart`).
String porukaVlasniku({
  required String ime,
  required String salon,
  required String kod,
}) => [
  'Zdravo $ime, ovo je vaš pristup admin aplikaciji salona $salon.',
  'Otvorite aplikaciju Melura, dodirnite „Imam poziv od salona" i unesite kod.',
  'Kod: $kod',
  'Kod važi 7 dana i radi samo jednom.',
].join('\n');

class ZahtjevGreska implements Exception {
  ZahtjevGreska(this.status, this.poruka);
  final int status;
  final String poruka;
  @override
  String toString() => poruka;
}

String _nasumicanToken() {
  final r = Random.secure();
  return base64Url
      .encode(List<int>.generate(24, (_) => r.nextInt(256)))
      .replaceAll('=', '');
}

/// Poređenje bez ranog izlaska, da vrijeme odgovora ne otkriva koliko je tokena tačno.
bool _isti(String a, String b) {
  if (a.length != b.length) return false;
  var razlika = 0;
  for (var i = 0; i < a.length; i++) {
    razlika |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return razlika == 0;
}
