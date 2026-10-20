/// `tenants/<flavor>/tenant.yaml` iz konzole: pisanje novog i izmjena `branding` bloka.
///
/// Fajl piše čovjek i nosi komentare, pa se postojeći **ne prepisuje cijeli**. Konzola u njemu
/// mijenja samo tri linije (`primaryColor`, `secondaryColor`, `theme`), a ostalo ostaje kako je
/// napisano. Novi fajl ima isti oblik kao `tenants/_template/tenant.yaml`.
library;

import 'package:yaml/yaml.dart';

/// Podaci iz kojih nastaje novi `tenant.yaml`. Isti su kao red koji je upravo upisan u bazu.
class NoviTenant {
  const NoviTenant({
    required this.salonId,
    required this.flavor,
    required this.slug,
    required this.vertical,
    required this.naziv,
    required this.grad,
    required this.imeAplikacije,
    required this.applicationId,
    required this.bundleId,
    required this.primarna,
    required this.sekundarna,
    required this.tema,
    required this.ios,
  });

  final String salonId;
  final String flavor;
  final String slug;
  final String vertical;
  final String naziv;
  final String grad;
  final String imeAplikacije;
  final String applicationId;
  final String bundleId;
  final String primarna;
  final String sekundarna;
  final String tema;
  final bool ios;
}

/// Šta konzola čita iz postojećeg fajla: dovoljno da uporedi fajl sa bazom.
class TenantNaDisku {
  const TenantNaDisku({
    required this.flavor,
    required this.salonId,
    required this.imeAplikacije,
    required this.primarna,
    required this.sekundarna,
    required this.tema,
    required this.ios,
  });

  final String flavor;
  final String salonId;
  final String imeAplikacije;
  final String primarna;
  final String sekundarna;
  final String tema;
  final bool ios;

  static TenantNaDisku procitaj(String sadrzaj) {
    final yaml = loadYaml(sadrzaj) as YamlMap;
    final tenant = yaml['tenant'] as YamlMap;
    final app = yaml['app'] as YamlMap;
    final branding = yaml['branding'] as YamlMap? ?? YamlMap();
    final targets = yaml['targets'] as YamlMap? ?? YamlMap();
    return TenantNaDisku(
      flavor: '${tenant['flavor']}',
      salonId: '${tenant['salonId']}',
      imeAplikacije: '${app['displayName']}',
      primarna: '${branding['primaryColor'] ?? ''}'.toUpperCase(),
      sekundarna: '${branding['secondaryColor'] ?? ''}'.toUpperCase(),
      tema: '${branding['theme'] ?? 'modern_barber'}',
      ios: targets['ios'] == true,
    );
  }
}

/// Novi `tenant.yaml`. Kratko ime je prva riječ naziva aplikacije (kao „Authentic"), jer
/// launcher na Androidu reže dugo ime.
String napisiTenantYaml(NoviTenant t) {
  final kratko = t.imeAplikacije.split(' ').first;
  return '''
# ${t.naziv} (${t.grad}) — napravila super admin konzola (task 72).
# salonId je red u bazi okruženja u kojem je salon napravljen. Polja: docs/04-flutter-tenant-factory.md §3
tenant:
  flavor: ${t.flavor}
  salonId: ${t.salonId}
  slug: ${t.slug}
  vertical: ${t.vertical}

app:
  displayName: ${_navodnici(t.imeAplikacije)}
  shortName: ${_navodnici(kratko)}
  applicationId: ${t.applicationId}
  bundleId: ${t.bundleId}
  versionName: "1.0.0"
  androidVersionCode: 1
  iosBuildNumber: 1

branding:
  # Fallback boje dok backend ne odgovori — iste kao salons.primary_color/secondary_color.
  # Mijenjaju se iz konzole, koja piše oba mjesta.
  primaryColor: "${t.primarna.toUpperCase()}"
  secondaryColor: "${t.sekundarna.toUpperCase()}"
  splashBackground: "${t.sekundarna.toUpperCase()}"
  theme: ${t.tema}

auth:
  # Koji se provideri nude na login ekranu. Filtriranje po platformi radi AuthConfig —
  # `apple: true` na Androidu se ignoriše, ne pada. V. docs/06 §7.6.
  providers:
    apple: true
    google: true
    email: true

  # Google `REVERSED_CLIENT_ID` za iOS. Prazno dok konzola ne da ID;
  # v. tasks/sprint-2/12-konzole-checklist.md.
  googleReversedClientId: ''

store:
  shortDescription: ${_navodnici('Zakažite termin u par tapova.')}
  categoryAndroid: LIFESTYLE
  categoryIos: LIFESTYLE
  contentRating: everyone
  supportEmail: podrska@nasadomena.ba
  privacyPolicyUrl: https://nasadomena.ba/privatnost/${t.slug}

targets:
  android: true
  ios: ${t.ios}
  web: true
''';
}

/// Mijenja boje i temu u postojećem fajlu, i ništa drugo. `splashBackground` prati sekundarnu
/// boju samo ako je do sada bio isti kao ona, jer je inače neko namjerno izabrao drugu.
///
/// Baca [FormatException] ako fajl nema `branding` blok sa sva tri ključa. Ključ koji fali bi
/// se inače tiho preskočio, a fajl i baza bi se razišli.
String zamijeniBranding(
  String sadrzaj, {
  required String primarna,
  required String sekundarna,
  required String tema,
}) {
  // Na Windows checkoutu fajl ima CRLF. Radi se na linijama bez `\r`, a vraća se isti završetak,
  // da git ne vidi izmjenu svake linije.
  final crlf = sadrzaj.contains('\r\n');
  final linije = sadrzaj.replaceAll('\r\n', '\n').split('\n');
  final pocetak = linije.indexWhere((l) => l.trimRight() == 'branding:');
  if (pocetak < 0) {
    throw const FormatException('tenant.yaml nema branding blok');
  }
  var kraj = linije.length;
  for (var i = pocetak + 1; i < linije.length; i++) {
    final l = linije[i];
    if (l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#')) {
      kraj = i;
      break;
    }
  }

  final stara = TenantNaDisku.procitaj(sadrzaj).sekundarna;
  final nove = {
    'primaryColor': '"${primarna.toUpperCase()}"',
    'secondaryColor': '"${sekundarna.toUpperCase()}"',
    'theme': tema,
  };
  final nadjeno = <String>{};
  final kljuc = RegExp(
    r'^(\s+)(primaryColor|secondaryColor|splashBackground|theme):\s*(.*)$',
  );
  for (var i = pocetak + 1; i < kraj; i++) {
    final m = kljuc.firstMatch(linije[i]);
    if (m == null) continue;
    final uvlaka = m.group(1)!;
    final ime = m.group(2)!;
    if (ime == 'splashBackground') {
      final splash = m.group(3)!.replaceAll('"', '').toUpperCase();
      if (splash == stara) {
        linije[i] = '${uvlaka}splashBackground: "${sekundarna.toUpperCase()}"';
      }
      continue;
    }
    linije[i] = '$uvlaka$ime: ${nove[ime]}';
    nadjeno.add(ime);
  }
  final fali = nove.keys.toSet().difference(nadjeno);
  if (fali.isNotEmpty) {
    throw FormatException('branding blok nema: ${fali.join(', ')}');
  }
  return linije.join(crlf ? '\r\n' : '\n');
}

/// YAML string u navodnicima. Naziv salona smije imati `:` ili `#`, a bez navodnika bi to
/// promijenilo značenje linije.
String _navodnici(String s) =>
    '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
