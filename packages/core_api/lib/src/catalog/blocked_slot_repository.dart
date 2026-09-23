import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'schedule_conflict_mapper.dart';

/// Čita blokirano vrijeme iz `public.blocked_slots`.
///
/// ## Zašto se ova tabela čita tek sada
///
/// `blocked_slots` postoji od init migracije i do taska 31 je bila čitana **isključivo iz
/// SQL-a** — `get_available_slots` i `create_appointment_admin` je oduzimaju od slobodnog
/// vremena. Klijentu je i dalje ne treba: njemu blokada nije podatak nego odsustvo slota.
/// Adminu jeste, i to je cijela razlika: kalendar koji blokadu ne crta pokazuje prazninu
/// tamo gdje je vlasnik svjesno zatvorio vrijeme, pa izgleda kao da se može zakazati.
///
/// ## Pisanje ide kroz `rpc`, i to je sada tvrdnja baze
///
/// Task 31 je ovdje ostavio otvorenu odluku: direktan `insert` bi tada **radio**, jer je
/// init migracija dala pun grant roli `authenticated`, pa bi „samo kroz `rpc`" bila
/// konvencija koju ništa ne drži. Task 34 je tu rupu zatvorio — grant je oduzet, kao što
/// ga je task 24 oduzeo nad `appointments`. Direktan `insert` sada pada na `42501`.
///
/// Zato [create] i [delete] zovu `create_blocked_slot` i `delete_blocked_slot`, koje
/// provjeravaju admina i pripadnost radnika salonu prije upisa.
///
/// ## Izolacija
///
/// [salonId] je preciznost upita, ne zaštita — isto kao u [StaffAppointmentRepository].
/// `blocked_slots` je u `staff_manage` porodici politika iz init migracije, pa admin koji
/// bi poslao tuđi `salonId` dobije **praznu listu**, ne tuđe blokade.
class BlockedSlotRepository {
  const BlockedSlotRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, salon_id, employee_id, date, start_time, end_time, reason';

  /// Blokade jednog dana, po vremenu početka.
  ///
  /// Vraćaju se **i salonske i radnikove** (`employee_id is null` vs. postavljen), kao što
  /// [WorkingHoursRepository.forSalon] vraća oba sloja rasporeda: koja se blokada odnosi na
  /// koju kolonu kalendara odlučuje ekran, jer to je pitanje prikaza, a ne upita.
  Future<List<BlockedSlot>> forDay({
    required String salonId,
    required DateTime day,
  }) => guard(() async {
    final rows = await _client
        .from('blocked_slots')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('date', _datum(day))
        // `ascending: true` je obavezan — `order()` u ovom paketu podrazumijeva
        // **descending**, suprotno od SQL-a. Ista zamka je zapisana u
        // `StaffAppointmentRepository.forDay` i u `policy_repository.dart`.
        .order('start_time', ascending: true);

    return blockedSlotsFromRows(rows);
  });

  /// Blokade **od datuma unaprijed**, po datumu pa po vremenu.
  ///
  /// [forDay] je za kalendar, koji crta jedan dan; ovo je za „Neradni dani" u `3h`, gdje
  /// vlasnik vidi šta ga tek čeka. Prošle blokade se ne vraćaju: neradni dan koji je
  /// prošao je historija, a lista koja raste unedogled je lista koju niko ne čita.
  ///
  /// [from] je `null` = od danas. Dan se računa iz [DateTime.now] **lokalno**, bez
  /// `toUtc()` — v. [LocalDate] za razlog.
  Future<List<BlockedSlot>> fromDay({
    required String salonId,
    DateTime? from,
  }) => guard(() async {
    final rows = await _client
        .from('blocked_slots')
        .select(_columns)
        .eq('salon_id', salonId)
        .gte('date', _datum(from ?? DateTime.now()))
        // Uzlazno eksplicitno — default u ovom paketu je silazno.
        .order('date', ascending: true)
        .order('start_time', ascending: true);

    return blockedSlotsFromRows(rows);
  });

  /// Nova blokada — salonska ([employeeId] `null`) ili radnikova.
  ///
  /// **Ne briše termine ispod sebe.** Termin koji se preklapa sa blokadom ostaje gdje
  /// jeste; šta se s njim dešava odlučuje vlasnik, a ne ovaj poziv. Listu takvih termina
  /// daje [conflicts], koji se zove prije.
  Future<BlockedSlot> create({
    required String salonId,
    required LocalDate date,
    required LocalTime startTime,
    required LocalTime endTime,
    String? reason,
    String? employeeId,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'create_blocked_slot',
      params: {
        'p_salon_id': salonId,
        'p_date': date.format(),
        'p_start_time': startTime.format(),
        'p_end_time': endTime.format(),
        'p_reason': reason,
        'p_employee_id': employeeId,
      },
    );
    final dynamic single = row is List && row.length == 1 ? row.single : row;
    try {
      return BlockedSlot.fromJson(single as Map<String, dynamic>);
    } catch (error) {
      throw MappingError('Neispravan `blocked_slots` red', cause: error);
    }
  });

  /// Briše blokadu. Tuđa i nepostojeća daju istu grešku — bez otkrivanja tuđih podataka.
  Future<void> delete({
    required String salonId,
    required String blockedSlotId,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'delete_blocked_slot',
      params: {'p_salon_id': salonId, 'p_blocked_slot_id': blockedSlotId},
    );
  });

  /// Termini koji bi pali unutar blokade koja se **tek dodaje**.
  ///
  /// Vraća [ScheduleConflict] bez `reason`: kod blokade je razlog očigledan, pa ga
  /// `blocked_slot_conflicts` i ne vraća kao kolonu.
  Future<List<ScheduleConflict>> conflicts({
    required String salonId,
    required LocalDate date,
    required LocalTime startTime,
    required LocalTime endTime,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'blocked_slot_conflicts',
      params: {
        'p_salon_id': salonId,
        'p_date': date.format(),
        'p_start_time': startTime.format(),
        'p_end_time': endTime.format(),
        'p_employee_id': employeeId,
      },
    );
    return scheduleConflictsFromRows(rows as List<dynamic>);
  });

  /// Termini koje bi [closeDay] otkazao — prikazuju se **prije** potvrde (task 42).
  ///
  /// Isti guard kao upis: prošli dan i danas poslije otvaranja daju grešku već ovdje, pa
  /// ekran ne nudi potvrdu koju bi `set_day_closed` odbio.
  Future<List<ScheduleConflict>> dayClosurePreview({
    required String salonId,
    required LocalDate date,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'day_closure_preview',
      params: {'p_salon_id': salonId, 'p_date': date.format()},
    );
    return scheduleConflictsFromRows(rows as List<dynamic>);
  });

  /// Proglašava dan neradnim: blokira cijeli dan i **otkazuje** sve žive termine tog dana,
  /// za razliku od [create], koji termine ostavlja. Vraća broj otkazanih.
  Future<int> closeDay({
    required String salonId,
    required LocalDate date,
    String? reason,
  }) => guard(() async {
    final broj = await _client.rpc<dynamic>(
      'set_day_closed',
      params: {
        'p_salon_id': salonId,
        'p_date': date.format(),
        'p_reason': reason,
      },
    );
    return (broj as num).toInt();
  });

  /// `2026-05-18` — `date` kolona, bez zone i bez `toIso8601String()`.
  ///
  /// `DateTime.toIso8601String()` nosi vrijeme i, za UTC vrijednost, `Z`; PostgREST bi to
  /// na `date` koloni prihvatio pa poredio po pomaknutom danu.
  static String _datum(DateTime dan) =>
      '${dan.year.toString().padLeft(4, '0')}-'
      '${dan.month.toString().padLeft(2, '0')}-'
      '${dan.day.toString().padLeft(2, '0')}';
}

/// Mapira `blocked_slots` redove na [BlockedSlot].
@visibleForTesting
List<BlockedSlot> blockedSlotsFromRows(List<dynamic> rows) {
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(BlockedSlot.fromJson)
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan `blocked_slots` red', cause: error);
  }
}
