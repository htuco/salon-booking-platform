/// Na koji Supabase projekat konzola piše i čime (ADR-0032 §3).
///
/// Ključ dolazi iz okruženja procesa: iz `supabase status -o json` lokalnog stacka, ili iz
/// fajla ignorisanog u gitu. Ne ispisuje se i ne ide stranici. [toString] ga namjerno nema.
library;

import 'dart:convert';

class Okruzenje {
  Okruzenje({required this.url, required this.kljuc, required this.izvor});

  /// Iz `supabase status -o json`. Lokalni CLI daje `API_URL` i `SERVICE_ROLE_KEY`.
  factory Okruzenje.izStatusa(String json) {
    final Object? podaci;
    try {
      podaci = jsonDecode(json);
    } on FormatException {
      throw const OkruzenjeGreska(
        'supabase status nije vratio JSON. Je li lokalni stack pokrenut (supabase start)?',
      );
    }
    if (podaci is! Map) {
      throw const OkruzenjeGreska('supabase status nije vratio objekat.');
    }
    final url = podaci['API_URL'];
    final kljuc = podaci['SERVICE_ROLE_KEY'] ?? podaci['SECRET_KEY'];
    if (url is! String || url.isEmpty || kljuc is! String || kljuc.isEmpty) {
      throw const OkruzenjeGreska(
        'supabase status nema API_URL i SERVICE_ROLE_KEY. Je li lokalni stack pokrenut?',
      );
    }
    return Okruzenje(url: Uri.parse(url), kljuc: kljuc, izvor: 'lokalni stack');
  }

  /// Iz `.env`-oblika fajla: `SUPABASE_URL` i `SUPABASE_SERVICE_ROLE_KEY`.
  factory Okruzenje.izEnvFajla(String sadrzaj, {required String ime}) {
    final vrijednosti = <String, String>{};
    for (final red in const LineSplitter().convert(sadrzaj)) {
      final l = red.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('=');
      if (i <= 0) continue;
      var v = l.substring(i + 1).trim();
      if (v.length >= 2 &&
          ((v.startsWith('"') && v.endsWith('"')) ||
              (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      vrijednosti[l.substring(0, i).trim()] = v;
    }
    final url = vrijednosti['SUPABASE_URL'] ?? '';
    final kljuc = vrijednosti['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
    if (url.isEmpty || kljuc.isEmpty) {
      throw OkruzenjeGreska(
        '$ime nema SUPABASE_URL i SUPABASE_SERVICE_ROLE_KEY.',
      );
    }
    return Okruzenje(url: Uri.parse(url), kljuc: kljuc, izvor: ime);
  }

  final Uri url;
  final String kljuc;

  /// Odakle je ključ došao, za zaglavlje konzole. Nikad sama vrijednost.
  final String izvor;

  /// Lokalni stack. Za svaki drugi host konzola traži potvrdu prije upisa.
  bool get lokalno =>
      url.host == '127.0.0.1' || url.host == 'localhost' || url.host == '::1';

  /// Ime koje se kuca kao potvrda prije upisa. Za hostovani Supabase to je ref projekta
  /// (`<ref>` iz `<ref>.supabase.co`), isti kao u URL-u dashboarda. Za svaki drugi host
  /// (custom domen, self-hosted) cijeli host: prvi dio `api.salon.ba` bi bio „api", što ne
  /// kaže na koji projekat se piše.
  String get projekat {
    if (lokalno) return 'lokalno';
    final host = url.host.toLowerCase();
    const supabase = '.supabase.co';
    if (host.endsWith(supabase)) {
      final ref = host.substring(0, host.length - supabase.length);
      if (ref.isNotEmpty && !ref.contains('.')) return ref;
    }
    return host;
  }

  @override
  String toString() => 'Okruzenje(${url.host}, $izvor)';
}

class OkruzenjeGreska implements Exception {
  const OkruzenjeGreska(this.poruka);
  final String poruka;
  @override
  String toString() => poruka;
}
