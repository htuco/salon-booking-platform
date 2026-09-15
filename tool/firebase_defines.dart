// Pretvara privatni Firebase config u --dart-define-from-file bez izmjene placeholdera.
import 'dart:convert';
import 'dart:io';

Map<String, String> firebaseDefines(
  Map<String, dynamic> config,
  String bundleId,
) {
  final Map<String, dynamic> values;
  if (config.containsKey('project_info')) {
    final clients = (config['client'] as List).cast<Map<String, dynamic>>();
    final matches = clients
        .where(
          (client) =>
              client['client_info']['android_client_info']['package_name'] ==
              bundleId,
        )
        .toList();
    if (matches.length != 1) {
      throw const FormatException('Firebase package name se ne poklapa');
    }
    final client = matches.single;
    values = {
      'FIREBASE_API_KEY': client['api_key'][0]['current_key'],
      'FIREBASE_APP_ID': client['client_info']['mobilesdk_app_id'],
      'FIREBASE_PROJECT_ID': config['project_info']['project_id'],
      'FIREBASE_SENDER_ID': config['project_info']['project_number'],
    };
  } else {
    if (config['BUNDLE_ID'] != bundleId) {
      throw const FormatException('Firebase bundle ID se ne poklapa');
    }
    values = {
      'FIREBASE_API_KEY': config['API_KEY'],
      'FIREBASE_APP_ID': config['GOOGLE_APP_ID'],
      'FIREBASE_PROJECT_ID': config['PROJECT_ID'],
      'FIREBASE_SENDER_ID': config['GCM_SENDER_ID'],
      'FIREBASE_IOS_BUNDLE_ID': config['BUNDLE_ID'],
    };
  }
  if (values.values.any(
    (value) =>
        value is! String ||
        value.isEmpty ||
        value.toLowerCase().contains('placeholder'),
  )) {
    throw const FormatException('Firebase config nije popunjen');
  }
  return {'PUSH_ENABLED': 'true', ...values.cast<String, String>()};
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Upotreba: firebase_defines.dart <json|plist> <bundle-id> <output>',
    );
    exitCode = 2;
    return;
  }
  try {
    final [input, bundleId, output] = arguments;
    final file = File(output);
    if (file.existsSync()) throw const FileSystemException('Izlaz vec postoji');
    final String source;
    if (input.endsWith('.plist')) {
      final result = await Process.run('plutil', [
        '-convert',
        'json',
        '-o',
        '-',
        input,
      ]);
      if (result.exitCode != 0) throw const FormatException('Neispravan plist');
      source = result.stdout as String;
    } else {
      source = await File(input).readAsString();
    }
    final defines = firebaseDefines(
      jsonDecode(source) as Map<String, dynamic>,
      bundleId,
    );
    await file.writeAsString(jsonEncode(defines));
  } catch (_) {
    // Parserova greska moze sadrzavati ulaz, pa se ne ispisuje sirovi izuzetak.
    stderr.writeln(
      'Firebase config nije pripremljen: provjeri ulaz, bundle ID i novi izlazni fajl.',
    );
    exitCode = 1;
  }
}
