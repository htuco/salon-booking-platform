// Lokalna super admin konzola (task 72, ADR-0032).
//
//   dart run superadmin                  # lokalni stack (supabase status)
//   dart run superadmin --env .env.prod  # projekat iz fajla, sa SUPABASE_SERVICE_ROLE_KEY;
//                                        # relativna putanja je od trenutnog foldera
//   dart run superadmin --port 4711
//
// Pokreće se iz korijena repoa ili bilo kojeg foldera ispod njega. Ključ se ne ispisuje.
import 'dart:async';
import 'dart:io';

import 'package:superadmin/src/okruzenje.dart';
import 'package:superadmin/src/platforma.dart';
import 'package:superadmin/src/repo.dart';
import 'package:superadmin/src/server.dart';

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    // ignore: avoid_print — CLI pomoć ide na stdout.
    print('dart run superadmin [--env <fajl>] [--port <broj>]');
    return;
  }

  final repo = Repo.nadji();
  final Okruzenje okruzenje;
  try {
    okruzenje = await _okruzenje(args, repo);
  } on OkruzenjeGreska catch (e) {
    stderr.writeln(e.poruka);
    exitCode = 2;
    return;
  }

  final port = int.tryParse(_vrijednost(args, '--port') ?? '') ?? 4710;
  final konzola = Konzola(
    okruzenje: okruzenje,
    platforma: Platforma(okruzenje),
    repo: repo,
  );
  try {
    await konzola.pokreni(port: port);
  } on SocketException catch (e) {
    stderr.writeln(
      'Port $port je zauzet (${e.message}). Probaj --port ${port + 1}.',
    );
    exitCode = 2;
    return;
  }

  stdout
    ..writeln(
      'Super admin konzola — ${okruzenje.lokalno ? 'LOKALNI STACK' : 'PROJEKAT ${okruzenje.projekat}'}',
    )
    ..writeln('  baza:  ${okruzenje.url.host} (ključ iz: ${okruzenje.izvor})')
    ..writeln('  repo:  ${repo.korijen.path}')
    ..writeln('')
    ..writeln('  Otvori: ${konzola.adresa}')
    ..writeln('')
    ..writeln('Adresa nosi token sesije — ne dijeli je. Ctrl+C gasi konzolu.');

  final gasenje = Completer<void>();
  ProcessSignal.sigint.watch().first.then((_) => gasenje.complete());
  await gasenje.future;
  await konzola.zaustavi();
}

Future<Okruzenje> _okruzenje(List<String> args, Repo repo) async {
  final env = _vrijednost(args, '--env');
  if (env != null) {
    // Relativna putanja je od foldera iz kojeg je komanda pokrenuta, kao kod svakog CLI-ja.
    // `File(env)` to već radi: relativan `File` se razrješava od `Directory.current`.
    final f = File(env).absolute;
    if (!f.existsSync()) throw OkruzenjeGreska('Nema fajla ${f.path}.');
    return Okruzenje.izEnvFajla(f.readAsStringSync(), ime: env);
  }
  final ProcessResult r;
  try {
    r = await Process.run(
      'supabase',
      ['status', '-o', 'json'],
      workingDirectory: repo.korijen.path,
      runInShell: Platform.isWindows,
    );
  } on ProcessException {
    throw const OkruzenjeGreska(
      'Nema supabase CLI-ja na PATH-u. Pokreni supabase start, ili daj --env.',
    );
  }
  // CLI piše poruke o novoj verziji na stderr; JSON je na stdout.
  return Okruzenje.izStatusa('${r.stdout}');
}

String? _vrijednost(List<String> args, String ime) {
  final i = args.indexOf(ime);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
