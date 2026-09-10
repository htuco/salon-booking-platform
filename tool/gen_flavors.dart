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
  for (final tenant in tenants) {
    stale |= _writeFile(
      File('${iosDir.path}/${tenant.flavor}.xcconfig'),
      _renderXcconfig(tenant),
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
    required this.applicationId,
    required this.bundleId,
    required this.versionName,
    required this.versionCode,
    required this.iosBuildNumber,
    required this.android,
    required this.ios,
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

    return Tenant(
      flavor: flavor,
      salonId: salonId,
      slug: tenant['slug'] as String,
      vertical: tenant['vertical'] as String,
      displayName: app['displayName'] as String,
      applicationId: app['applicationId'] as String,
      bundleId: app['bundleId'] as String,
      versionName: app['versionName'] as String,
      versionCode: app['androidVersionCode'] as int,
      iosBuildNumber: app['iosBuildNumber'] as int,
      android: targets['android'] as bool? ?? true,
      ios: targets['ios'] as bool? ?? false,
    );
  }

  final String flavor;
  final String salonId;
  final String slug;
  final String vertical;
  final String displayName;
  final String applicationId;
  final String bundleId;
  final String versionName;
  final int versionCode;
  final int iosBuildNumber;
  final bool android;
  final bool ios;
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
      ..writeln('            versionCode = ${tenant.versionCode}')
      ..writeln('            versionName = "${tenant.versionName}"')
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

String _renderXcconfig(Tenant tenant) =>
    '''
// $_marker. Pokreni: dart run tool/gen_flavors.dart
PRODUCT_BUNDLE_IDENTIFIER = ${tenant.bundleId}
PRODUCT_NAME = ${tenant.displayName}
DISPLAY_NAME = ${tenant.displayName}
MARKETING_VERSION = ${tenant.versionName}
CURRENT_PROJECT_VERSION = ${tenant.iosBuildNumber}
ASSET_CATALOG_APP_ICON_NAME = AppIcon-${tenant.flavor}
SALON_ID = ${tenant.salonId}
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
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String flavor;')
    ..writeln('  final String salonId;')
    ..writeln('  final String slug;')
    ..writeln('  final String vertical;')
    ..writeln('  final String displayName;')
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
