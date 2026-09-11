import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

/// Doba dana bez datuma i **bez vremenske zone** — `09:00`, `14:30`.
///
/// Postoji zato što `working_hours.start_time`, `blocked_slots` i `appointments` u bazi
/// koriste Postgresov `time` tip, koji nema ni datum ni zonu. To je **lokalno zidno vrijeme
/// salona**: "otvaramo u 9" znači devet po satu na zidu salona, bez obzira na to gdje stoji
/// telefon koji čita raspored.
///
/// Zamka koju ovaj tip postoji da spriječi: `DateTime.parse('09:00:00')` daje vrijeme koje
/// Dart smatra lokalnim za **uređaj**, a `toUtc()` ga onda pomjeri za pomak zone. Radno
/// vrijeme salona tako tiho sklizne za sat ili dva i to niko ne primijeti dok neko ne
/// rezerviše termin u devet i ne dobije ga u sedam. [DateTime] se zato ovdje ne koristi
/// uopšte — nema ga ni u jednom polju.
///
/// Pretvaranje u stvarni trenutak traži datum **i** `salon_settings.timezone`, i radi se tek
/// na mjestu prikaza. Ovaj sloj to namjerno ne zna.
@immutable
class LocalTime implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute)
    : assert(hour >= 0 && hour <= 23, 'sat je 0–23'),
      assert(minute >= 0 && minute <= 59, 'minuta je 0–59');

  /// Parsira `HH:mm` ili `HH:mm:ss` — oblik u kojem PostgREST vraća `time` kolonu.
  ///
  /// Sekunde se čitaju i odbacuju: šema nema nijedno vrijeme sa sekundama različitim od
  /// nule (`time` kolone se pune sa `'09:00'`), a zadržavanje bi značilo da se dva ista
  /// termina razlikuju po polju koje nikad nije postavljeno.
  factory LocalTime.parse(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      throw FormatException('Očekivano HH:mm ili HH:mm:ss', value);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      throw FormatException('Sat i minuta moraju biti brojevi', value);
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Sat mora biti 0–23, minuta 0–59', value);
    }
    return LocalTime(hour, minute);
  }

  final int hour;
  final int minute;

  /// Minute od ponoći — jedini oblik u kojem se vremena porede i oduzimaju.
  int get minutesFromMidnight => hour * 60 + minute;

  /// `09:00` — oblik koji baza očekuje nazad i koji je čitljiv u logu.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalTime other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  bool operator <(LocalTime other) => compareTo(other) < 0;
  bool operator <=(LocalTime other) => compareTo(other) <= 0;
  bool operator >(LocalTime other) => compareTo(other) > 0;
  bool operator >=(LocalTime other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'LocalTime(${format()})';
}

/// Most između `time` kolone (string) i [LocalTime] za `json_serializable`.
class LocalTimeConverter implements JsonConverter<LocalTime, String> {
  const LocalTimeConverter();

  @override
  LocalTime fromJson(String json) => LocalTime.parse(json);

  @override
  String toJson(LocalTime object) => object.format();
}

/// Isto, za nullable kolone (`break_start_time`, `break_end_time`).
class NullableLocalTimeConverter implements JsonConverter<LocalTime?, String?> {
  const NullableLocalTimeConverter();

  @override
  LocalTime? fromJson(String? json) =>
      json == null ? null : LocalTime.parse(json);

  @override
  String? toJson(LocalTime? object) => object?.format();
}
