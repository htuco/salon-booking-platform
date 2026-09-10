// Pravi privremenu ikonu po tenantu iz boja u tenant.yaml, samo ako asset
// još ne postoji.
//
//   dart run tool/gen_placeholder_icons.dart           # popuni sto fali
//   dart run tool/gen_placeholder_icons.dart --force   # prepisi i postojece
//
// Svrha je dokazati da flutter_launcher_icons pipeline po flavoru radi, bez
// cekanja na dizajn. Pravi asset kasnije samo zamijeni PNG na istoj putanji —
// konfiguracija se ne mijenja. Zato ovaj alat NIKAD ne prepisuje postojeci
// fajl bez --force: dizajnerska ikona ne smije nestati na sljedecem pokretanju.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';
import 'package:yaml/yaml.dart';

const _size = 1024;

void main(List<String> args) {
  final force = args.contains('--force');
  final root = _repoRoot();
  final dirs =
      Directory('${root.path}/tenants')
          .listSync()
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var written = 0;
  var kept = 0;
  for (final dir in dirs) {
    final name = dir.path.split(Platform.pathSeparator).last;
    if (name.startsWith('_')) continue;
    final config = File('${dir.path}/tenant.yaml');
    if (!config.existsSync()) continue;

    final yaml = loadYaml(config.readAsStringSync()) as YamlMap;
    final target = File('${dir.path}/assets/icon.png');
    if (target.existsSync() && !force) {
      stdout.writeln('$name: preskacem, ikona postoji.');
      kept++;
      continue;
    }

    final app = yaml['app'] as YamlMap;
    final branding = yaml['branding'] as YamlMap? ?? YamlMap();
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(
      encodePng(
        _placeholder(
          initials: _initials(app['displayName'] as String),
          disc: _hex(branding['primaryColor'] as String? ?? '#888888'),
          preferredBackground: _hex(
            branding['splashBackground'] as String? ?? '#111111',
          ),
        ),
      ),
    );
    stdout.writeln('$name: napisana placeholder ikona.');
    written++;
  }
  stdout.writeln('Napisano: $written, zadrzano: $kept.');
}

/// Inicijali prve i zadnje rijeci: "Barber Studio Vitez" -> "BV".
/// Same prve rijeci nisu dovoljne — oba demo salona pocinju sa "B".
String _initials(String displayName) {
  final words = displayName
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words.first.substring(0, 1) + words.last.substring(0, 1))
      .toUpperCase();
}

ColorRgb8 _hex(String value) {
  final v = value.replaceFirst('#', '');
  return ColorRgb8(
    int.parse(v.substring(0, 2), radix: 16),
    int.parse(v.substring(2, 4), radix: 16),
    int.parse(v.substring(4, 6), radix: 16),
  );
}

/// Relativna luminancija po WCAG-u.
double _luminance(ColorRgb8 c) {
  double channel(num v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(ColorRgb8 a, ColorRgb8 b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

/// Tekst se crta na maloj podlozi pa uvecava: paket ima samo bitmap fontove
/// fiksne velicine, a ikona treba 1024px.
///
/// Boje se ne uzimaju naslijepo iz tenant.yaml. `splashBackground` smije biti
/// isti kao `primaryColor` — beautystudiotravnik ima upravo to — pa bi krug
/// nestao u pozadini. Zato se pozadina prihvata samo ako stvarno kontrastira,
/// a inace se pada na neutralnu.
Image _placeholder({
  required String initials,
  required ColorRgb8 disc,
  required ColorRgb8 preferredBackground,
}) {
  final discIsLight = _luminance(disc) > 0.4;
  final background = _contrast(preferredBackground, disc) >= 1.8
      ? preferredBackground
      : (discIsLight ? ColorRgb8(23, 23, 23) : ColorRgb8(245, 245, 245));
  final letter = discIsLight ? ColorRgb8(23, 23, 23) : ColorRgb8(255, 255, 255);

  const draft = 128;
  final small = Image(width: draft, height: draft)..clear(background);
  fillCircle(
    small,
    x: draft ~/ 2,
    y: draft ~/ 2,
    radius: (draft * 0.40).round(),
    color: disc,
  );
  final font = arial48;
  final textWidth = initials.length * font.characters[0x42]!.xAdvance;
  drawString(
    small,
    initials,
    font: font,
    x: (draft - textWidth) ~/ 2,
    y: (draft - font.lineHeight) ~/ 2,
    color: letter,
  );
  return copyResize(
    small,
    width: _size,
    height: _size,
    interpolation: Interpolation.cubic,
  );
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !Directory('${dir.path}/tenants').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Ne mogu naci korijen repozitorija (pubspec.yaml + tenants/).',
      );
      exit(1);
    }
    dir = parent;
  }
  return dir;
}
