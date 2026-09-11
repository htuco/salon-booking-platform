import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Čita radno vrijeme salona iz `public.working_hours`.
///
/// **Ovo nije izvor slobodnih termina.** Slobodne termine računa baza
/// (`get_available_slots`, task 05) i to ostaje tamo — radno vrijeme se ovdje čita da bi
/// ekran mogao prikazati "otvoreno 09–17" i zasiviti neradne dane u kalendaru. Ako se
/// uhvatiš da iz ovoga računaš slobodne slotove, to je logika koja pripada bazi.
///
/// Vremena su [LocalTime] — lokalno zidno vrijeme salona, bez zone i bez konverzije.
class WorkingHoursRepository {
  const WorkingHoursRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '''
id, salon_id, employee_id, day_of_week,
start_time, end_time, break_start_time, break_end_time, is_closed
''';

  /// Sav raspored salona — i salonski redovi (`employee_id is null`) i oni po radniku,
  /// sortirani po ISO danu.
  ///
  /// Vraćaju se **oba sloja**, nerazdvojena: koji vrijedi za konkretnog radnika odlučuje
  /// pozivalac kroz [workingHoursFor], jer to pravilo (radnikov red nadjačava salonski)
  /// pripada domenu, ne upitu.
  Future<List<WorkingHour>> forSalon(String salonId) => guard(() async {
    final rows = await _client
        .from('working_hours')
        .select(_columns)
        .eq('salon_id', salonId)
        .order('day_of_week');

    return workingHoursFromRows(rows);
  });
}

/// Mapira `working_hours` redove na [WorkingHour].
@visibleForTesting
List<WorkingHour> workingHoursFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(WorkingHour.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan `working_hours` red', cause: error);
  }
}

/// Bira raspored koji stvarno vrijedi za dati dan i radnika.
///
/// Pravilo: **radnikov red nadjačava salonski.** Ako radnik nema svoj red za taj dan,
/// vrijedi salonski; ako nema ni njega, salon taj dan ne radi (`null`).
///
/// Stoji kao funkcija, a ne kao filter u upitu, jer isti raspored treba i ekranu salona
/// (bez radnika) i ekranu radnika — jedan upit, dva čitanja.
WorkingHour? workingHoursFor(
  List<WorkingHour> all, {
  required int dayOfWeek,
  String? employeeId,
}) {
  final forDay = all.where((h) => h.dayOfWeek == dayOfWeek);

  if (employeeId != null) {
    for (final hour in forDay) {
      if (hour.employeeId == employeeId) return hour;
    }
  }

  for (final hour in forDay) {
    if (hour.isSalonWide) return hour;
  }
  return null;
}
