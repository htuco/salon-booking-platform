import 'package:meta/meta.dart';

import 'local_time.dart';
import 'working_hour.dart';

/// Jedan dan sedmice **na putu ka bazi** — ulaz za `set_working_hours`.
///
/// Zašto ovo nije [WorkingHour]: [WorkingHour] je red koji je baza već zapisala, sa `id`
/// i `salonId`. Dan koji se tek snima nema ni jedno ni drugo, a zatvoren dan nema ni
/// vremena. Kad bi se slao [WorkingHour], ekran bi morao izmisliti `id` za dan koji još
/// ne postoji — i to je tačno ona vrsta praznog polja koje kasnije neko pročita kao
/// podatak.
///
/// **Šalje se uvijek svih sedam dana**, jer `get_available_slots` čita odsustvo reda kao
/// zatvoreno, a ne kao „nije podešeno". Djelimičan upis bi tiho zatvorio dane koje ekran
/// nije poslao. Baza tu provjeru ponavlja i odbija `PT400`.
@immutable
class WorkingHoursInput {
  const WorkingHoursInput({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    this.isClosed = false,
  });

  /// Postojeći red kao ulaz — za ekran koji učita sedmicu pa mijenja jedan dan.
  factory WorkingHoursInput.fromWorkingHour(WorkingHour hour) =>
      WorkingHoursInput(
        dayOfWeek: hour.dayOfWeek,
        startTime: hour.startTime,
        endTime: hour.endTime,
        breakStartTime: hour.breakStartTime,
        breakEndTime: hour.breakEndTime,
        isClosed: hour.isClosed,
      );

  /// Dan koji salon ne radi. Vremena i dalje stoje jer ih kolona traži `not null`, ali
  /// ih niko ne čita dok je [isClosed] — isto pravilo kao u [WorkingHour].
  factory WorkingHoursInput.closed(int dayOfWeek) => WorkingHoursInput(
    dayOfWeek: dayOfWeek,
    startTime: const LocalTime(9, 0),
    endTime: const LocalTime(17, 0),
    isClosed: true,
  );

  /// ISO 1–7 (ponedjeljak–nedjelja), isto kao `DateTime.weekday`.
  final int dayOfWeek;
  final LocalTime startTime;
  final LocalTime endTime;
  final LocalTime? breakStartTime;
  final LocalTime? breakEndTime;
  final bool isClosed;

  bool get hasBreak => breakStartTime != null && breakEndTime != null;

  WorkingHoursInput copyWith({
    LocalTime? startTime,
    LocalTime? endTime,
    bool? isClosed,
    // Pauza se **briše** slanjem `clearBreak`, ne slanjem `null`: `null` u `copyWith`
    // znači „ne diraj", pa bez ovog flaga ne postoji način da se pauza ukloni.
    bool clearBreak = false,
    LocalTime? breakStartTime,
    LocalTime? breakEndTime,
  }) => WorkingHoursInput(
    dayOfWeek: dayOfWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    breakStartTime: clearBreak ? null : (breakStartTime ?? this.breakStartTime),
    breakEndTime: clearBreak ? null : (breakEndTime ?? this.breakEndTime),
    isClosed: isClosed ?? this.isClosed,
  );

  /// Oblik koji PostgREST mapira na `public.working_hours_input` composite tip.
  ///
  /// Ključevi su imena polja composite tipa, ne kolona tabele — slučajno su ista, ali
  /// mijenja ih migracija tipa, a ne migracija tabele.
  Map<String, dynamic> toRpc() => {
    'day_of_week': dayOfWeek,
    'start_time': startTime.format(),
    'end_time': endTime.format(),
    'break_start_time': breakStartTime?.format(),
    'break_end_time': breakEndTime?.format(),
    'is_closed': isClosed,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkingHoursInput &&
      other.dayOfWeek == dayOfWeek &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.breakStartTime == breakStartTime &&
      other.breakEndTime == breakEndTime &&
      other.isClosed == isClosed;

  @override
  int get hashCode => Object.hash(
    dayOfWeek,
    startTime,
    endTime,
    breakStartTime,
    breakEndTime,
    isClosed,
  );
}

/// Sedmica poredana po ISO danu, sa popunjenim danima koji u bazi ne postoje.
///
/// Salon koji nikad nije snimio raspored nema nijedan red, a ekran mora prikazati svih
/// sedam. Dan bez reda je **zatvoren** — isto kako ga čita `get_available_slots`, pa
/// ekran i engine vide istu stvar.
List<WorkingHoursInput> weekFromWorkingHours(
  List<WorkingHour> all, {
  String? employeeId,
}) => List.generate(7, (i) {
  final dayOfWeek = i + 1;
  for (final hour in all) {
    if (hour.dayOfWeek == dayOfWeek && hour.employeeId == employeeId) {
      return WorkingHoursInput.fromWorkingHour(hour);
    }
  }
  return WorkingHoursInput.closed(dayOfWeek);
}, growable: false);
