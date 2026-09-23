/// Sedmica osoblja — čista logika iza `3g`/`3r`, bez widgeta.
///
/// **Raspored je ponavljajući, ne sedmični.** `working_hours` nosi jedan red po danu u
/// sedmici, pa „Sedmica 18.–24. maj" samo imenuje dane na koje se taj raspored odnosi.
/// Jedino što je vezano za datum su blokade (godišnji, odsustvo), i one se čitaju od
/// danas unaprijed (`buduceBlokadeProvider`) — prošli dani sedmice ih zato ne pokazuju.
library;

import 'package:core_api/core_api.dart' show workingHoursFor;
import 'package:core_domain/core_domain.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../core/format/datum.dart';

/// Ponedjeljak sedmice u kojoj je [dan], u lokalnu ponoć.
///
/// `DateTime(g, m, d - n)` umjesto `subtract(Duration(days: n))`: oduzimanje trajanja
/// preko prelaska na ljetno vrijeme daje 23:00 prethodnog dana.
DateTime ponedjeljakSedmice(DateTime dan) =>
    DateTime(dan.year, dan.month, dan.day - (dan.weekday - 1));

/// Sedam dana od [ponedjeljak].
List<DateTime> daniSedmice(DateTime ponedjeljak) => [
  for (var i = 0; i < 7; i++)
    DateTime(ponedjeljak.year, ponedjeljak.month, ponedjeljak.day + i),
];

/// `Sedmica 18.–24. maj`, a preko granice mjeseca `Sedmica 29. juni – 5. juli`.
String sedmicaTekst(DateTime ponedjeljak) {
  final nedjelja = daniSedmice(ponedjeljak).last;
  final mjesecKraja = kMjeseci[nedjelja.month - 1];
  if (ponedjeljak.month == nedjelja.month) {
    return 'Sedmica ${ponedjeljak.day}.–${nedjelja.day}. $mjesecKraja';
  }
  return 'Sedmica ${ponedjeljak.day}. ${kMjeseci[ponedjeljak.month - 1]} – '
      '${nedjelja.day}. $mjesecKraja';
}

/// `09`, a `09:30` samo kad minute postoje — `3g` piše smjenu kao `09–20`.
String satKratko(LocalTime vrijeme) {
  final sat = vrijeme.hour.toString().padLeft(2, '0');
  if (vrijeme.minute == 0) return sat;
  return '$sat:${vrijeme.minute.toString().padLeft(2, '0')}';
}

/// Šta radnik radi jednog dana.
sealed class DanRadnika {
  const DanRadnika();
}

/// Ima smjenu.
final class RadiDan extends DanRadnika {
  const RadiDan(this.smjena);
  final WorkingHour smjena;

  /// `09–20`.
  String get kratko =>
      '${satKratko(smjena.startTime)}–${satKratko(smjena.endTime)}';
}

/// Nema smjene: nema reda ili je dan zatvoren.
final class SlobodanDan extends DanRadnika {
  const SlobodanDan();
}

/// Ima smjenu, ali je blokada pokriva cijelu — godišnji, bolovanje, salon zatvoren.
final class OdsutanDan extends DanRadnika {
  const OdsutanDan(this.razlog);
  final String? razlog;
}

bool _istiDan(LocalDate a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Blokade koje važe za radnika na [dan]: njegove i salonske.
Iterable<BlockedSlot> blokadeZa(
  List<BlockedSlot> blokade,
  String employeeId,
  DateTime dan,
) => blokade.where(
  (b) =>
      _istiDan(b.date, dan) &&
      (b.employeeId == null || b.employeeId == employeeId),
);

DanRadnika danRadnika({
  required List<WorkingHour> sati,
  required List<BlockedSlot> blokade,
  required String employeeId,
  required DateTime dan,
}) {
  final smjena = workingHoursFor(
    sati,
    dayOfWeek: dan.weekday,
    employeeId: employeeId,
  );
  if (smjena == null || smjena.isClosed) return const SlobodanDan();

  // Samo blokada koja pokriva **cijelu** smjenu mijenja polje; djelimična (sastanak od
  // 10 do 11) ostaje u kalendaru, a ovdje bi se čitala kao da radnik taj dan ne radi.
  for (final b in blokadeZa(blokade, employeeId, dan)) {
    if (b.startTime.minutesFromMidnight <=
            smjena.startTime.minutesFromMidnight &&
        b.endTime.minutesFromMidnight >= smjena.endTime.minutesFromMidnight) {
      final razlog = b.reason?.trim();
      return OdsutanDan(razlog == null || razlog.isEmpty ? null : razlog);
    }
  }
  return RadiDan(smjena);
}

/// Minute rada u sedmici po ponavljajućem rasporedu, bez pauza.
int minuteSedmice(List<WorkingHour> sati, String employeeId) {
  var ukupno = 0;
  for (var dan = 1; dan <= 7; dan++) {
    final s = workingHoursFor(sati, dayOfWeek: dan, employeeId: employeeId);
    if (s == null || s.isClosed) continue;
    ukupno += s.endTime.minutesFromMidnight - s.startTime.minutesFromMidnight;
    if (s.hasBreak) {
      ukupno -=
          s.breakEndTime!.minutesFromMidnight -
          s.breakStartTime!.minutesFromMidnight;
    }
  }
  return ukupno;
}

/// `42 h`, `37,5 h`.
String satiTekst(int minuta) {
  if (minuta % 60 == 0) return '${minuta ~/ 60} h';
  return '${(minuta / 60).toStringAsFixed(1).replaceAll('.', ',')} h';
}

/// Kratka oznaka odsustva za usku ćeliju telefona: `Godišnji odmor` → `GO`.
String skracenicaOdsustva(String? razlog) {
  final rijeci = (razlog ?? '').trim().split(RegExp(r'\s+'))
    ..removeWhere((r) => r.isEmpty);
  if (rijeci.isEmpty) return 'ODS';
  if (rijeci.length >= 2) {
    return (rijeci[0].characters.first + rijeci[1].characters.first)
        .toUpperCase();
  }
  final r = rijeci.first;
  return (r.length <= 3 ? r : r.substring(0, 3)).toUpperCase();
}

/// Stanje radnika u ovom trenutku — pilula na kartici.
sealed class StanjeDanas {
  const StanjeDanas();
}

final class USmjeni extends StanjeDanas {
  const USmjeni();
}

final class NaPauzi extends StanjeDanas {
  const NaPauzi();
}

final class Pocinje extends StanjeDanas {
  const Pocinje(this.od);
  final LocalTime od;
}

final class SmjenaGotova extends StanjeDanas {
  const SmjenaGotova();
}

final class NeRadiDanas extends StanjeDanas {
  const NeRadiDanas();
}

final class OdsutanSada extends StanjeDanas {
  const OdsutanSada();
}

final class Neaktivan extends StanjeDanas {
  const Neaktivan();
}

StanjeDanas stanjeDanas({
  required Employee radnik,
  required List<WorkingHour> sati,
  required List<BlockedSlot> blokade,
  required DateTime sada,
}) {
  if (!radnik.isActive) return const Neaktivan();
  final dan = danRadnika(
    sati: sati,
    blokade: blokade,
    employeeId: radnik.id,
    dan: sada,
  );
  switch (dan) {
    case SlobodanDan():
      return const NeRadiDanas();
    case OdsutanDan():
      return const OdsutanSada();
    case RadiDan(:final smjena):
      final m = sada.hour * 60 + sada.minute;
      if (m < smjena.startTime.minutesFromMidnight) {
        return Pocinje(smjena.startTime);
      }
      if (m >= smjena.endTime.minutesFromMidnight) return const SmjenaGotova();
      // Djelimična blokada koja traje upravo sada: „u smjeni" bi rekao da je slobodan.
      final blokiran = blokadeZa(blokade, radnik.id, sada).any(
        (b) =>
            b.startTime.minutesFromMidnight <= m &&
            m < b.endTime.minutesFromMidnight,
      );
      if (blokiran) return const OdsutanSada();
      if (smjena.hasBreak &&
          smjena.breakStartTime!.minutesFromMidnight <= m &&
          m < smjena.breakEndTime!.minutesFromMidnight) {
        return const NaPauzi();
      }
      return const USmjeni();
  }
}
