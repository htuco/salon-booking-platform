import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Lista čekanja (task 68, ADR-0031).
///
/// Tabela `waitlist_entries` nema nijedan grant za aplikaciju — sve ide kroz RPC. Klijentske
/// funkcije same izvode salon iz `x-salon-id` i identitet iz tokena, pa se ovdje ne šalju:
/// argument koji se ne šalje ne može se ni podmetnuti.
class WaitlistRepository {
  const WaitlistRepository(this._client);

  final SupabaseClient _client;

  /// Puni dani u rasponu: dan radi, a nema slobodnog vremena. Ne traži prijavu, kao ni
  /// slotovi.
  ///
  /// Dan bez slobodnog vremena je i neradni dan; po ovome kalendar razlikuje pun dan, na
  /// kojem nudi listu čekanja, od dana koji ne radi.
  Future<Set<LocalDate>> fullDates({
    required String salonId,
    required String serviceId,
    required LocalDate from,
    required LocalDate to,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'waitlist_full_dates',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_from': from.format(),
        'p_to': to.format(),
        'p_employee_id': employeeId,
      },
    );
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        LocalDate.parse(row['full_date'] as String),
    };
  });

  /// Upisuje prijavljenog klijenta. Ponovljen upis vraća isti; `PT400` kad dan nije pun,
  /// `PT429` (`RateLimitError`) za četvrti aktivan upis.
  Future<String> join({
    required String serviceId,
    required LocalDate date,
    String? employeeId,
  }) => guard(() async {
    final id = await _client.rpc<dynamic>(
      'join_waitlist',
      params: {
        'p_service_id': serviceId,
        'p_date': date.format(),
        'p_employee_id': employeeId,
      },
    );
    if (id is! String) {
      throw FormatException('join_waitlist bez ID-a', '$id');
    }
    return id;
  });

  /// Odjava. Upis koji više ne postoji nije greška.
  Future<void> leave(String entryId) => guard(() async {
    await _client.rpc<dynamic>(
      'leave_waitlist',
      params: {'p_entry_id': entryId},
    );
  });

  /// Aktivni upisi klijenta u ovom salonu, od danas.
  Future<List<WaitlistEntry>> mine() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_waitlist');
    return rows
        .cast<Map<String, dynamic>>()
        .map(WaitlistEntry.fromJson)
        .toList(growable: false);
  });

  /// Broj klijenata koji čekaju, po danu, za admina salona. Dan bez upisa nema ključ.
  Future<Map<LocalDate, int>> demand({
    required String salonId,
    required LocalDate from,
    required LocalDate to,
  }) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'waitlist_demand',
      params: {
        'p_salon_id': salonId,
        'p_from': from.format(),
        'p_to': to.format(),
      },
    );
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        LocalDate.parse(row['date'] as String): row['waiting'] as int,
    };
  });
}
