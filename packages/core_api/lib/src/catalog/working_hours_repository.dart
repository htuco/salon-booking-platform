import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'schedule_conflict_mapper.dart';

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
        // Uzlazno eksplicitno — v. `ServiceRepository.forSalon`: default je silazno.
        // Ovdje se posljedica ne vidi na Pocetnoj (`SalonSchedule` slaze dane po kljucu
        // 1–7), ali lista koja stize obrnuto je zamka za svakog sljedeceg potrosaca.
        .order('day_of_week', ascending: true);

    return workingHoursFromRows(rows);
  });

  /// Snima **cijelu sedmicu** odjednom — salonsku ([employeeId] `null`) ili radnikovu.
  ///
  /// Sedam dana nije tvrdoglavost ugovora nego posljedica toga kako engine čita tabelu:
  /// `get_available_slots` tretira **odsustvo reda kao zatvoreno**, a ne kao „nije
  /// podešeno". Poslati tri izmijenjena dana značilo bi tiho zatvoriti ostala četiri.
  /// Zato [days] mora nositi svaki ISO dan 1–7 tačno jednom; baza to i provjerava i
  /// odbija `PT400` ako nije tako.
  ///
  /// **Postojeći termini se ne diraju.** Termin koji ispadne van novog radnog vremena
  /// ostaje gdje jeste — vidi [conflicts], koji se zove **prije** ovoga.
  Future<List<WorkingHour>> save({
    required String salonId,
    required List<WorkingHoursInput> days,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'set_working_hours',
      params: {
        'p_salon_id': salonId,
        'p_days': days.map((d) => d.toRpc()).toList(growable: false),
        'p_employee_id': employeeId,
      },
    );
    return workingHoursFromRows(rows as List<dynamic>);
  });

  /// Termini koji bi ispali van rasporeda [days], **prije** nego što se on snimi.
  ///
  /// Čitanje, ne pisanje: poziv ništa ne mijenja, pa ekran smije pitati na svaku izmjenu
  /// i pokazati posljedicu dok je još moguće odustati.
  Future<List<ScheduleConflict>> conflicts({
    required String salonId,
    required List<WorkingHoursInput> days,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'working_hours_conflicts',
      params: {
        'p_salon_id': salonId,
        'p_employee_id': employeeId,
        'p_days': days.map((d) => d.toRpc()).toList(growable: false),
      },
    );
    return scheduleConflictsFromRows(rows as List<dynamic>);
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
