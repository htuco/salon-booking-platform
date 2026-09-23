// Generiše Android productFlavors i iOS xcconfig fajlove iz tenants/*/tenant.yaml.
//
//   dart run tool/gen_flavors.dart          # generiši
//   dart run tool/gen_flavors.dart --check  # padni ako je generisano zastarjelo (CI)
//
// Gradle blok i xcconfig se NIKAD ne editaju ručno — na 20 tenanata ručno
// održavanje je izvor grešaka. V. docs/04-flutter-tenant-factory.md §4 i §5.
import 'dart:io';

import 'package:yaml/yaml.dart';

const _marker = 'GENERISANO — ne editovati ručno';

/// Imena koja `AuthProvider.fromWire` u `core_domain` poznaje. Redoslijed je redoslijed
/// prikaza na login ekranu (Apple prvi — App Review 4.8, v. docs/06 §7.2).
// `facebook` je namjerno izostavljen — ADR-0011. Tenant koji ga upiše obara generator,
// umjesto da ključ tiho prođe kao konfiguracija koja ne radi ništa.
const _poznatiProvideri = ['apple', 'google', 'email'];
const _podrazumijevaniProvideri = ['apple', 'google', 'email'];
const _beginFlavors = '    // >>> BEGIN GENERATED FLAVORS';
const _endFlavors = '    // <<< END GENERATED FLAVORS';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = _repoRoot();
  final tenants = _loadTenants(Directory('${root.path}/tenants'));

  if (tenants.isEmpty) {
    stderr.writeln('Nijedan tenant nije pronađen u tenants/.');
    exit(1);
  }

  var stale = false;
  final gradle = File('${root.path}/apps/client/android/app/build.gradle.kts');
  stale |= _writeFile(
    gradle,
    _renderGradle(gradle.readAsStringSync(), tenants),
    check,
  );

  final iosDir = Directory('${root.path}/apps/client/ios/flavors');
  if (!check) iosDir.createSync(recursive: true);
  for (final tenant in tenants.where((t) => t.ios)) {
    stale |= _writeFile(
      File('${iosDir.path}/${tenant.flavor}.xcconfig'),
      _renderXcconfig(tenant),
      check,
    );
    // Entitlement po flavoru, jer ga Xcode veze za jedan target i jedan bundle ID.
    // Sadrzi samo izjavu sposobnosti — nema ni kljuceva ni profila, pa smije u git.
    stale |= _writeFile(
      File('${iosDir.path}/${tenant.flavor}.entitlements'),
      _renderEntitlements(tenant),
      check,
    );
    // Xcode build konfiguracija se veže na wrapper, ne na tenant fajl direktno:
    // Flutterov Generated.xcconfig (FLUTTER_ROOT, build mode) mora ostati u
    // lancu, inače build ne zna gdje je SDK. Ime nosi '-<flavor>' jer
    // flutter_launcher_icons po tome prepoznaje flavor konfiguraciju.
    for (final mode in _iosModes.entries) {
      stale |= _writeFile(
        File('${iosDir.path}/${mode.key}-${tenant.flavor}.xcconfig'),
        _renderXcconfigWrapper(tenant, mode.value),
        check,
      );
    }
  }

  // Po-flavor konfiguracija za flutter_launcher_icons; alat sam skenira
  // flutter_launcher_icons-*.yaml u korijenu paketa.
  for (final tenant in tenants) {
    stale |= _writeFile(
      File(
        '${root.path}/apps/client/flutter_launcher_icons-${tenant.flavor}.yaml',
      ),
      _renderLauncherIcons(tenant),
      check,
    );
  }

  // Po-flavor Android resursi. google-services.json je placeholder: FCM veže
  // token na applicationId, pa jedan zajednički fajl znači da push ne radi.
  for (final tenant in tenants.where((t) => t.android)) {
    stale |= _writeFile(
      File(
        '${root.path}/apps/client/android/app/src/${tenant.flavor}/google-services.json',
      ),
      _renderGoogleServices(tenant),
      check,
    );
  }

  stale |= _writeFile(
    File('${root.path}/apps/client/lib/src/generated/tenants.g.dart'),
    _renderDart(tenants),
    check,
  );

  if (check && stale) {
    stderr.writeln(
      '\nGenerisani fajlovi su zastarjeli. Pokreni: dart run tool/gen_flavors.dart',
    );
    exit(1);
  }
  stdout.writeln(
    check
        ? 'Generisani fajlovi su ažurni (${tenants.length} tenanta).'
        : 'Generisano za ${tenants.length} tenanta: '
              '${tenants.map((t) => t.flavor).join(', ')}.',
  );
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/tenants').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Ne mogu naći korijen repozitorija (pubspec.yaml + tenants/).',
      );
      exit(1);
    }
    dir = parent;
  }
  return dir;
}

List<Tenant> _loadTenants(Directory dir) {
  final tenants = <Tenant>[];
  final entries = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entry in entries) {
    final name = entry.path.split(Platform.pathSeparator).last;
    if (name.startsWith('_')) continue; // _template nije tenant
    final file = File('${entry.path}/tenant.yaml');
    if (!file.existsSync()) continue;
    tenants.add(
      Tenant.fromYaml(loadYaml(file.readAsStringSync()) as YamlMap, name),
    );
  }
  return tenants;
}

class Tenant {
  Tenant({
    required this.flavor,
    required this.salonId,
    required this.slug,
    required this.vertical,
    required this.displayName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.themeName,
    required this.applicationId,
    required this.bundleId,
    required this.versionName,
    required this.versionCode,
    required this.iosBuildNumber,
    required this.android,
    required this.ios,
    required this.authProviders,
    required this.googleReversedClientId,
  });

  factory Tenant.fromYaml(YamlMap yaml, String dirName) {
    final tenant = yaml['tenant'] as YamlMap;
    final app = yaml['app'] as YamlMap;
    final targets = yaml['targets'] as YamlMap? ?? YamlMap();
    final flavor = tenant['flavor'] as String;

    // Folder i flavor moraju biti isti — inače gradle traži src/<flavor>/ koji ne postoji.
    if (flavor != dirName) {
      stderr.writeln(
        'tenants/$dirName/tenant.yaml: flavor "$flavor" != ime foldera "$dirName".',
      );
      exit(1);
    }
    if (!RegExp(r'^[a-z][a-z0-9]*$').hasMatch(flavor)) {
      stderr.writeln(
        '$flavor: gradle flavor mora biti [a-z][a-z0-9]* (bez crtica i _).',
      );
      exit(1);
    }
    final salonId = tenant['salonId'] as String;
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(salonId)) {
      stderr.writeln('$flavor: salonId "$salonId" nije UUID.');
      exit(1);
    }

    final branding = yaml['branding'] as YamlMap? ?? YamlMap();

    // Fallback boje ulaze u generisani registar da app ima sta iscrtati prije prvog
    // odgovora backenda. Format se validira ovdje, a ne u Dartu na uredjaju: neispravan
    // heks bi tamo bio izuzetak pri startu app-e, ovdje je pad generatora u CI-ju.
    String hexBoja(String kljuc, String podrazumijevana) {
      final vrijednost = branding[kljuc] as String? ?? podrazumijevana;
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(vrijednost)) {
        stderr.writeln('$flavor: branding.$kljuc "$vrijednost" nije #RRGGBB.');
        exit(1);
      }
      return vrijednost.toUpperCase();
    }

    // Provideri se validiraju ovdje, a ne u Dartu na uredjaju: nepoznat kljuc u
    // `auth.providers` je tipfeler u konfiguraciji, pa je pad generatora u CI-ju jedino
    // mjesto gdje se vidi prije nego stigne do korisnika. Isti razlog kao za heks boje.
    final auth = yaml['auth'] as YamlMap? ?? YamlMap();
    if (auth.containsKey('allowGuestBooking')) {
      stderr.writeln(
        '$flavor: auth.allowGuestBooking je uklonjen — svaki klijent se mora prijaviti '
        '(task 41). Ukloni ključ iz tenant.yaml.',
      );
      exit(1);
    }
    final provideri = auth['providers'] as YamlMap? ?? YamlMap();
    for (final kljuc in provideri.keys) {
      if (!_poznatiProvideri.contains(kljuc)) {
        stderr.writeln(
          '$flavor: auth.providers."$kljuc" nije poznat provider. '
          'Dozvoljeni: ${_poznatiProvideri.join(', ')}.',
        );
        exit(1);
      }
    }
    final ukljuceni = <String>[];
    for (final kljuc in _poznatiProvideri) {
      final vrijednost = provideri[kljuc];
      if (vrijednost == null) continue;
      if (vrijednost is! bool) {
        stderr.writeln(
          '$flavor: auth.providers.$kljuc mora biti true ili false, a ne "$vrijednost".',
        );
        exit(1);
      }
      if (vrijednost) ukljuceni.add(kljuc);
    }

    // Apple je **obavezan na iOS-u** cim postoji ijedan drugi social provider — App Review
    // odbija build po pravilu 4.8 (`docs/06 §7.2`). To nije nasa politika nego Appleova, i
    // jedino mjesto gdje se moze uhvatiti prije submissiona je ovdje.
    //
    // Provjera pada samo kad tenant stvarno gradi iOS. Android-only tenant smije imati
    // Google bez Applea, jer Apple na Androidu nema ni implementaciju (`AuthProvider`).
    //
    // Bez ovoga se greska otkriva tek kad Apple odbije build — sedmicama kasnije, i to
    // ne kao poruka o konfiguraciji nego kao odbijen submission.
    final gradiIos = (targets['ios'] as bool? ?? false);
    final socialBezApplea = ukljuceni
        .where((p) => p != 'email' && p != 'apple')
        .toList();
    if (gradiIos &&
        !ukljuceni.contains('apple') &&
        socialBezApplea.isNotEmpty) {
      stderr.writeln(
        '$flavor: iOS build sa social providerom (${socialBezApplea.join(', ')}) '
        'mora ukljuciti i apple — App Review pravilo 4.8 (docs/06 §7.2).\n'
        '  Rjesenje: dodaj `apple: true` u auth.providers, ili iskljuci iOS '
        '(`targets.ios: false`), ili ostavi samo `email`.',
      );
      exit(1);
    }

    return Tenant(
      flavor: flavor,
      salonId: salonId,
      slug: tenant['slug'] as String,
      vertical: tenant['vertical'] as String,
      displayName: app['displayName'] as String,
      primaryColor: hexBoja('primaryColor', '#C6A667'),
      secondaryColor: hexBoja('secondaryColor', '#171717'),
      themeName: branding['theme'] as String? ?? 'modern_barber',
      applicationId: app['applicationId'] as String,
      bundleId: app['bundleId'] as String,
      versionName: app['versionName'] as String,
      versionCode: app['androidVersionCode'] as int,
      iosBuildNumber: app['iosBuildNumber'] as int,
      android: targets['android'] as bool? ?? true,
      ios: targets['ios'] as bool? ?? false,
      // Bez `auth:` bloka tenant dobija isto sto i AuthConfig.fallback — Apple, Google,
      // email. Postojeci tenant.yaml tako ne mora biti dopunjen da bi prijava radila.
      authProviders: auth.isEmpty ? _podrazumijevaniProvideri : ukljuceni,
      // Prazno je ispravno stanje: vecina tenanata jos nema Google klijenta.
      googleReversedClientId: auth['googleReversedClientId'] as String? ?? '',
    );
  }

  final String flavor;
  final String salonId;
  final String slug;
  final String vertical;
  final String displayName;
  final String primaryColor;
  final String secondaryColor;
  final String themeName;
  final String applicationId;
  final String bundleId;
  final String versionName;
  final int versionCode;
  final int iosBuildNumber;
  final bool android;
  final bool ios;

  /// Imena providera ukljucenih u `auth.providers`, u redoslijedu `_poznatiProvideri`.
  /// Parsira se u `AuthProvider` tek u app-u (`AuthConfig.fromNames`).
  final List<String> authProviders;

  /// Google `REVERSED_CLIENT_ID` za iOS — client ID sa obrnutim segmentima, koji ide u
  /// `CFBundleURLTypes`. Prazno dok konzola ne da ID; v. `12-konzole-checklist.md`.
  final String googleReversedClientId;
}

/// Zamjenjuje samo blok između markera — ostatak gradle fajla (signing,
/// compileOptions, buildTypes) ostaje ručno održavan.
String _renderGradle(String current, List<Tenant> tenants) {
  final buffer = StringBuffer()
    ..writeln(_beginFlavors)
    ..writeln('    // $_marker. Pokreni: dart run tool/gen_flavors.dart')
    ..writeln('    // AGP 9 gasi resValues po defaultu; app_name po flavoru')
    ..writeln('    // se generiše upravo kroz resValue, pa mora biti uključen.')
    ..writeln('    buildFeatures {')
    ..writeln('        resValues = true')
    ..writeln('    }')
    ..writeln()
    ..writeln('    flavorDimensions += "tenant"')
    ..writeln()
    ..writeln('    productFlavors {');
  for (final tenant in tenants.where((t) => t.android)) {
    buffer
      ..writeln('        create("${tenant.flavor}") {')
      ..writeln('            dimension = "tenant"')
      ..writeln('            applicationId = "${tenant.applicationId}"')
      ..writeln(
        '            resValue("string", "app_name", "${tenant.displayName}")',
      )
      // CI mora moći podići versionCode bez editovanja tenant.yaml (docs/04 §8.1),
      // a vrijednost iz tenant.yaml ostaje default za lokalni build. Flavor blok
      // nadjačava flutter.versionCode, pa `--build-number` sam ovdje ne stiže —
      // zato Gradle property, koju prosljeđuje tool/build_tenant.sh.
      ..writeln(
        '            versionCode = (project.findProperty("tenantVersionCode") '
        'as String?)?.toInt() ?: ${tenant.versionCode}',
      )
      ..writeln(
        '            versionName = (project.findProperty("tenantVersionName") '
        'as String?) ?: "${tenant.versionName}"',
      )
      ..writeln('        }');
  }
  buffer
    ..writeln('    }')
    ..write(_endFlavors);

  final begin = current.indexOf(_beginFlavors);
  if (begin >= 0) {
    final end = current.indexOf(_endFlavors) + _endFlavors.length;
    return current.replaceRange(begin, end, buffer.toString());
  }
  // Prvi put: ubaci blok prije buildTypes bloka.
  final anchor = current.indexOf('\n    buildTypes {');
  if (anchor < 0) {
    stderr.writeln('Ne mogu naći buildTypes blok u build.gradle.kts.');
    exit(1);
  }
  return current.replaceRange(anchor, anchor, '\n\n$buffer\n');
}

/// Build mode -> Flutterov xcconfig koji wrapper mora uključiti.
/// Flutter generiše samo Debug i Release; Profile se veže na Release, isto
/// kao što to radi Runner target u praznom Flutter projektu.
const _iosModes = <String, String>{
  'Debug': 'Debug',
  'Profile': 'Release',
  'Release': 'Release',
};

String _renderXcconfig(Tenant tenant) =>
    '''
// $_marker. Pokreni: dart run tool/gen_flavors.dart
//
// PRODUCT_NAME puni CFBundleName i CFBundleDisplayName kroz Info.plist.
// ASSETCATALOG_COMPILER_APPICON_NAME je stvarno ime Xcode postavke —
// ASSET_CATALOG_APP_ICON_NAME ne postoji i tiho se ignoriše.
PRODUCT_BUNDLE_IDENTIFIER = ${tenant.bundleId}
PRODUCT_NAME = ${tenant.displayName}
MARKETING_VERSION = ${tenant.versionName}
CURRENT_PROJECT_VERSION = ${tenant.iosBuildNumber}
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-${tenant.flavor}
SALON_ID = ${tenant.salonId}

// Sign in with Apple trazi entitlement po flavoru (`docs/06 §7.2`). Fajl je generisan i
// prazan od tajni — entitlement je izjava sposobnosti, ne potpisni materijal.
CODE_SIGN_ENTITLEMENTS = flavors/${tenant.flavor}.entitlements

// URL shema kojom se Google vraca u app. Google je zove REVERSED_CLIENT_ID: iOS client ID
// sa obrnutim segmentima. **Prazno je ispravno stanje** dok konzola ne da ID
// (`tasks/sprint-2/12-konzole-checklist.md`); Info.plist tada nosi praznu shemu, sto iOS
// ignorise, a `signInWithGoogle` ionako baca prije dijaloga.
GOOGLE_REVERSED_CLIENT_ID = ${tenant.googleReversedClientId}
''';

/// `Runner.entitlements` po flavoru — Sign in with Apple (`docs/06 §7.2`).
///
/// **Generise se i kad tenant nema Apple u `auth.providers`.** Prazan entitlement fajl bi
/// bio treci mogucnost koju Xcode konfiguracija mora razlikovati, a korist je nula: bez
/// odgovarajuce capability na App ID-u u Apple Developer konzoli entitlement svejedno ne
/// radi, a sa njom ne smeta. Jedan oblik fajla za sve flavore znaci i da ukljucivanje
/// Applea za jednog tenanta ne trazi novi prolaz kroz generator.
///
/// XML je namjerno bez komentara: `plutil` i Xcode ih tolerisu, ali ih prvi `plutil
/// -convert` izbaci, pa bi fajl odmah bio "izmijenjen" naspram generisanog.
String _renderEntitlements(Tenant tenant) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>com.apple.developer.applesignin</key>
\t<array>
\t\t<string>Default</string>
\t</array>
\t<key>aps-environment</key>
\t<string>\$(PUSH_APS_ENVIRONMENT)</string>
\t<key>keychain-access-groups</key>
\t<array>
\t\t<string>\$(AppIdentifierPrefix)\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
\t</array>
</dict>
</plist>
''';

String _renderXcconfigWrapper(Tenant tenant, String flutterMode) =>
    '''
// $_marker. Pokreni: dart run tool/gen_flavors.dart
#include "../Flutter/$flutterMode.xcconfig"
#include "${tenant.flavor}.xcconfig"
''';

String _renderLauncherIcons(Tenant tenant) =>
    '''
# $_marker. Pokreni: dart run tool/gen_flavors.dart
#
# Izvorna ikona: tenants/${tenant.flavor}/assets/icon.png
# Placeholder se pravi sa: dart run tool/gen_placeholder_icons.dart
# Pravi asset samo zamijeni taj fajl — ovdje se ništa ne mijenja.
flutter_launcher_icons:
  image_path: "../../tenants/${tenant.flavor}/assets/icon.png"
  android: ${tenant.android}
  ios: ${tenant.ios}
  remove_alpha_ios: true
''';

/// Placeholder da google-services plugin ne pukne prije pravog Firebase
/// projekta. Ne sadrži prave ključeve — push sa ovim fajlom ne radi.
String _renderGoogleServices(Tenant tenant) =>
    '''
{
  "project_info": {
    "project_number": "000000000000",
    "project_id": "placeholder-${tenant.flavor}",
    "storage_bucket": "placeholder-${tenant.flavor}.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": {
          "package_name": "${tenant.applicationId}"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "PLACEHOLDER_NOT_A_REAL_KEY"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
''';

/// `#RRGGBB` → `0xFFRRGGBB` literal za Dart. Alfa je uvijek puna: `tenant.yaml` opisuje
/// brand boju, a ne prozirnost.
String _argb(String hex) => '0xFF${hex.substring(1).toUpperCase()}';

String _renderDart(List<Tenant> tenants) {
  final buffer = StringBuffer()
    ..writeln('// $_marker. Pokreni: dart run tool/gen_flavors.dart')
    ..writeln('//')
    ..writeln(
      '// Build-time registar tenanata. Runtime izvor istine je backend —',
    )
    ..writeln(
      '// ovdje su samo fallback vrijednosti dostupne prije prvog odgovora.',
    )
    ..writeln()
    ..writeln('class TenantConfig {')
    ..writeln('  const TenantConfig({')
    ..writeln('    required this.flavor,')
    ..writeln('    required this.salonId,')
    ..writeln('    required this.slug,')
    ..writeln('    required this.vertical,')
    ..writeln('    required this.displayName,')
    ..writeln('    required this.primaryColor,')
    ..writeln('    required this.secondaryColor,')
    ..writeln('    required this.themeName,')
    ..writeln('    required this.authProviders,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String flavor;')
    ..writeln('  final String salonId;')
    ..writeln('  final String slug;')
    ..writeln('  final String vertical;')
    ..writeln('  final String displayName;')
    ..writeln()
    ..writeln('  /// ARGB, ne heks string — app ne parsira boju pri startu.')
    ..writeln('  /// Izvor: `branding.primaryColor` iz `tenant.yaml`.')
    ..writeln('  final int primaryColor;')
    ..writeln('  final int secondaryColor;')
    ..writeln()
    ..writeln(
      '  /// Imenovana tema (`modern_barber` | `elegant_beauty`); bira svjetlinu',
    )
    ..writeln('  /// i neutralnu paletu dok backend ne odgovori.')
    ..writeln('  final String themeName;')
    ..writeln()
    ..writeln(
      '  /// Provideri iz `auth.providers` u `tenant.yaml`, kao imena koja',
    )
    ..writeln(
      '  /// `AuthProvider.fromWire` poznaje. Parsira se u `AuthConfig.fromNames`;',
    )
    ..writeln('  /// filtriranje po platformi radi `AuthConfig.forPlatform`.')
    ..writeln('  final List<String> authProviders;')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'const Map<String, TenantConfig> kTenants = <String, TenantConfig>{',
    );
  for (final tenant in tenants) {
    buffer
      ..writeln("  '${tenant.salonId}': TenantConfig(")
      ..writeln("    flavor: '${tenant.flavor}',")
      ..writeln("    salonId: '${tenant.salonId}',")
      ..writeln("    slug: '${tenant.slug}',")
      ..writeln("    vertical: '${tenant.vertical}',")
      ..writeln("    displayName: '${tenant.displayName}',")
      ..writeln('    primaryColor: ${_argb(tenant.primaryColor)},')
      ..writeln('    secondaryColor: ${_argb(tenant.secondaryColor)},')
      ..writeln("    themeName: '${tenant.themeName}',")
      ..writeln(
        '    authProviders: <String>['
        '${tenant.authProviders.map((p) => "'$p'").join(', ')}],',
      )
      ..writeln('  ),');
  }
  buffer.writeln('};');
  return buffer.toString();
}

bool _writeFile(File file, String content, bool check) {
  final normalized = content.replaceAll('\r\n', '\n');
  final current = file.existsSync()
      ? file.readAsStringSync().replaceAll('\r\n', '\n')
      : null;
  if (current == normalized) return false;
  if (check) {
    stderr.writeln('Zastarjelo: ${file.path}');
    return true;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(normalized);
  return true;
}
