/// Sat admin ekrana.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sat ekrana — jedan izvor „sada" za kalendar i Danas: linija trenutnog vremena, „U toku",
/// „čeka X min", „za X min" i blok „je li došao?".
///
/// **Stream, ne `DateTime.now()` u `build`-u.** Linija koja se ne pomjera je gora od
/// linije koje nema: kalendar otvoren cijelo prijepodne bi tvrdio da je i dalje devet.
/// Minuta je dovoljno sitan korak — osa je 80 px po satu, pa je pomak po minuti 1,3 px.
///
/// Test ga override-uje sa `Stream.value(...)`. Bez toga bi svaki widget test kalendara
/// zavisio od doba dana, što je tačno zamka zbog koje task 31 i ima svoju napomenu.
///
/// **`autoDispose` zaustavlja kucanje kad nijedan od ta dva ekrana nije otvoren.** Bez njega bi
/// `Stream.periodic` radio do kraja života aplikacije, iako liniju „sada" crta jedan ekran.
final sadaProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});
