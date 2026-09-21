import 'package:core_domain/core_domain.dart';

import '../errors/errors.dart';

/// Mapira redove obje `*_conflicts` funkcije na [ScheduleConflict].
///
/// Stoji u svom fajlu, a ne uz jedan od dva repozitorija, jer ga dijele
/// `WorkingHoursRepository.conflicts` i `BlockedSlotRepository.conflicts`:
/// `blocked_slot_conflicts` vraća isti skup kolona bez `reason`, a `reason` je u modelu
/// nullable upravo zato.
List<ScheduleConflict> scheduleConflictsFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(ScheduleConflict.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan red konflikta', cause: error);
  }
}
