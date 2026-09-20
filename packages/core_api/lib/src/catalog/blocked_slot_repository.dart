import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

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
/// ## Čitanje, ne pisanje
///
/// Ovdje nema `insert`-a ni `delete`-a. „Blokiraj vrijeme" i „Dodaj pauzu" iz `3c` su
/// **pisanje**, a pisanja u ovom sistemu idu kroz validirane `rpc` funkcije kojih za
/// blokade još nema (task 34). Dodavanje `insert`-a ovdje bi značilo da app piše direktno
/// u tabelu — obrnuto od pravila koje task 24 ima upisano u grantove
/// (`.claude/docs/security.md`).
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
