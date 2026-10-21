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

/// Podrazumijevane vrijednosti kad `tenant.yaml` nema `branding` ključ. **Iste kao u
/// `tool/gen_flavors.dart`** (`hexBoja(..., '#C6A667')` i ostale): konzola mora iz fajla bez
/// boja pročitati isto što generator upiše u registar, inače bi „fajl ≠ baza" lagao. Slaganje
/// drži `test/sinhronizacija_test.dart`, koji pokreće pravi generator.
const podrazumijevanaPrimarna = '#C6A667';
const podrazumijevanaSekundarna = '#171717';
const podrazumijevanaTema = 'modern_barber';

/// Šta konzola čita iz postojećeg fajla: dovoljno da uporedi fajl sa bazom i da salon iz
/// fajla upiše u bazu novog okruženja (isti UUID).
class TenantNaDisku {
  const TenantNaDisku({
    required this.flavor,
    required this.salonId,
    required this.slug,
    required this.vertical,
    required this.imeAplikacije,
    required this.applicationId,
    required this.bundleId,
    required this.primarna,
    required this.sekundarna,
    required this.tema,
    required this.ios,
    this.naziv,
    this.grad,
  });

  final String flavor;
  final String salonId;
  final String slug;
  final String vertical;
  final String imeAplikacije;
  final String applicationId;
  final String bundleId;
  final String primarna;
  final String sekundarna;
  final String tema;
  final bool ios;

  /// Naziv salona i grad nisu polja `tenant.yaml`-a. Konzola ih piše u prvi komentar
  /// (`# Naziv (Grad) — …`), pa se odatle čitaju kao prijedlog; `null` kad komentar nema
  /// taj oblik (demo tenanti).
  final String? naziv;
  final String? grad;

  static TenantNaDisku procitaj(String sadrzaj) {
    final yaml = loadYaml(sadrzaj) as YamlMap;
    final tenant = yaml['tenant'] as YamlMap;
    final app = yaml['app'] as YamlMap;
    final branding = yaml['branding'] as YamlMap? ?? YamlMap();
    final targets = yaml['targets'] as YamlMap? ?? YamlMap();
    final zaglavlje = _zaglavlje.firstMatch(
      sadrzaj.replaceAll('\r\n', '\n').split('\n').first,
    );
    return TenantNaDisku(
      flavor: '${tenant['flavor']}',
      salonId: '${tenant['salonId']}',
      slug: '${tenant['slug'] ?? ''}',
      vertical: '${tenant['vertical'] ?? ''}',
      imeAplikacije: '${app['displayName']}',
      applicationId: '${app['applicationId'] ?? ''}',
      bundleId: '${app['bundleId'] ?? ''}',
      primarna: '${branding['primaryColor'] ?? podrazumijevanaPrimarna}'
          .toUpperCase(),
      sekundarna: '${branding['secondaryColor'] ?? podrazumijevanaSekundarna}'
          .toUpperCase(),
      tema: '${branding['theme'] ?? podrazumijevanaTema}',
      ios: targets['ios'] == true,
      naziv: zaglavlje?.group(1)?.trim(),
      grad: zaglavlje?.group(2)?.trim(),
    );
  }
}

/// `# Naziv (Grad) — …`: prva linija koju piše [napisiTenantYaml] (i ručno pisani
/// `authenticbarber`). Grad je zadnja zagrada prije crte, pa naziv smije imati svoju.
final _zaglavlje = RegExp(r'^# (.+) \(([^()]+)\) — ');

/// Novi `tenant.yaml`. Kratko ime je prva riječ naziva aplikacije (kao „Authentic"), jer
/// launcher na Androidu reže dugo ime.
String napisiTenantYaml(NoviTenant t) {
  final kratko = t.imeAplikacije.split(' ').first;
  return '''
# ${_jednaLinija(t.naziv)} (${_jednaLinija(t.grad)}) — napravila super admin konzola (task 72).
# salonId je isti u svakoj bazi: prvo okruženje ga izmisli, ostala ga upišu iz ovog fajla
# (konzola, „Upiši u ovu bazu iz tenant.yaml"). Polja: docs/04-flutter-tenant-factory.md §3
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

/// Mijenja boje i temu u postojećem fajlu, i ništa drugo. Mijenja se samo vrijednost: uvlaka,
/// razmak i komentar na kraju linije ostaju. Dira samo **direktnu djecu** `branding` bloka,
/// pa ugniježđen ključ istog imena ostaje kakav jeste.
///
/// `splashBackground` prati onu boju kojoj je bio jednak prije izmjene (sekundarnu ili
/// primarnu). Ako nije bio jednak nijednoj, neko je namjerno izabrao drugu i ostaje.
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
  final pocetak = linije.indexWhere(_brandingZaglavlje.hasMatch);
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

  // Uvlaka direktne djece je uvlaka prvog ključa u bloku (komentari i prazne linije ne broje).
  String? uvlaka;
  for (var i = pocetak + 1; i < kraj; i++) {
    final l = linije[i];
    if (l.trim().isEmpty || l.trimLeft().startsWith('#')) continue;
    uvlaka = RegExp(r'^ *').stringMatch(l);
    break;
  }
  if (uvlaka == null || uvlaka.isEmpty) {
    throw const FormatException('branding blok je prazan');
  }

  final stari = TenantNaDisku.procitaj(sadrzaj);
  final nove = {
    'primaryColor': '"${primarna.toUpperCase()}"',
    'secondaryColor': '"${sekundarna.toUpperCase()}"',
    'theme': tema,
  };
  final nadjeno = <String>{};
  // Grupe: ime, razmak poslije `:`, vrijednost (u navodnicima ili bez), ostatak linije
  // (razmak i komentar). Uvlaka je tačno uvlaka direktne djece, pa dublja linija ne prolazi.
  final kljuc = RegExp(
    '^${RegExp.escape(uvlaka)}'
    r'''(primaryColor|secondaryColor|splashBackground|theme):(\s*)("[^"]*"|'[^']*'|[^\s#]*)(.*)$''',
  );
  for (var i = pocetak + 1; i < kraj; i++) {
    final m = kljuc.firstMatch(linije[i]);
    if (m == null) continue;
    final ime = m.group(1)!;
    final razmak = m.group(2)!.isEmpty ? ' ' : m.group(2)!;
    final ostatak = m.group(4)!;
    if (ime == 'splashBackground') {
      final splash = _bezNavodnika(m.group(3)!).toUpperCase();
      final prati = splash == stari.sekundarna
          ? sekundarna
          : splash == stari.primarna
          ? primarna
          : null;
      if (prati != null) {
        linije[i] =
            '${uvlaka}splashBackground:$razmak"${prati.toUpperCase()}"$ostatak';
      }
      continue;
    }
    linije[i] = '$uvlaka$ime:$razmak${nove[ime]}$ostatak';
    nadjeno.add(ime);
  }
  final fali = nove.keys.toSet().difference(nadjeno);
  if (fali.isNotEmpty) {
    throw FormatException('branding blok nema: ${fali.join(', ')}');
  }
  return linije.join(crlf ? '\r\n' : '\n');
}

/// `branding:`, i sa komentarom iza (`branding: # fallback`).
final _brandingZaglavlje = RegExp(r'^branding:\s*(#.*)?$');

String _bezNavodnika(String v) =>
    v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))
    ? v.substring(1, v.length - 1)
    : v;

/// YAML string u navodnicima. Naziv salona smije imati `:` ili `#`, a bez navodnika bi to
/// promijenilo značenje linije. Kontrolni znak ide kao escape (`\n`, `\x07`), nikad doslovno:
/// baza ih odbija, ali fajl ne smije zavisiti od toga.
String _navodnici(String s) {
  final b = StringBuffer('"');
  for (final c in s.runes) {
    b.write(switch (c) {
      0x5C => r'\\',
      0x22 => r'\"',
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      < 0x20 || 0x7F => '\\x${c.toRadixString(16).padLeft(2, '0')}',
      _ => String.fromCharCode(c),
    });
  }
  b.write('"');
  return b.toString();
}

/// Tekst za komentar u jednoj liniji: kontrolni znak (prelom reda) postaje razmak, pa ne može
/// započeti novi YAML ključ.
String _jednaLinija(String s) => s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
