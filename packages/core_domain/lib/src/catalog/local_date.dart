import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

/// Kalendarski datum bez vremena i **bez vremenske zone** — `2026-09-11`.
///
/// Isti razlog postojanja kao [LocalTime](local_time.dart): `appointments.date` i
/// `blocked_slots.date` su Postgresov `date`, a `DateTime.parse('2026-09-11')` daje ponoć
/// **po zoni uređaja**. Jedan `toUtc()` na tome pomjeri termin za dan unazad svima istočno
/// od Greenwicha — a Sarajevo jeste istočno. Zato ovdje nema `DateTime`.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12, 'mjesec je 1–12'),
      assert(day >= 1 && day <= 31, 'dan je 1–31');

  /// Parsira `yyyy-MM-dd` — oblik u kojem PostgREST vraća `date` kolonu.
  factory LocalDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Očekivano yyyy-MM-dd', value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('Godina, mjesec i dan moraju biti brojevi', value);
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw FormatException('Mjesec je 1–12, dan 1–31', value);
    }
    return LocalDate(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  /// ISO dan u sedmici, 1 = ponedjeljak … 7 = nedjelja — isti ključ kao
  /// `working_hours.day_of_week`.
  ///
  /// Jedino mjesto gdje se [DateTime] smije pojaviti u ovom tipu: koristi se kao kalendar
  /// za računanje dana u sedmici, u lokalnoj zoni i bez ikakve konverzije, pa pomak zone
  /// ne može promijeniti rezultat.
  int get weekday => DateTime(year, month, day).weekday;

  /// `2026-09-11` — oblik koji baza očekuje nazad.
  String format() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'LocalDate(${format()})';
}

/// Most između `date` kolone (string) i [LocalDate] za `json_serializable`.
class LocalDateConverter implements JsonConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromJson(String json) => LocalDate.parse(json);

  @override
  String toJson(LocalDate object) => object.format();
}
