import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Slobodni termini i rezervacija — jedini repozitorij koji **piše** u bazu.
///
/// ## Zašto su sve tri metode `rpc`, a nijedna `from(...)`
///
/// Ostali repozitoriji čitaju tabele kroz PostgREST. Ovaj ne smije, iz dva razloga:
///
/// 1. **Slobodni termini se ne mogu pročitati.** Slot je odsustvo termina u presjeku radnog
///    vremena, pauza, blokada i buffera; da bi ga klijent izračunao, morao bi vidjeti tuđe
///    termine — a `appointments` nema politiku za `anon` i neće je dobiti. Zato su
///    `get_available_slots` i `get_available_dates` `security definer` funkcije: vraćaju
///    samo vremena, nikad redove.
/// 2. **Rezervacija mora re-validirati slot u istoj transakciji.** Između trenutka kad je
///    lista prikazana i trenutka kad korisnik pritisne "potvrdi" prođe dovoljno vremena da
///    neko drugi uzme isti slot (`docs/01 §8.1`). `insert` sa klijenta bi tu utrku izgubio
///    tiho; `book_appointment` je dobija eksplicitno i diže `PT409`.
///
/// Zbog toga ovdje nema nijedne metode koja prima listu termina i vraća slobodna vremena, i
/// neće je biti. Availability logika je u bazi (task 05) — v. `.claude/docs/security.md`.
///
/// ## Šta ovaj sloj **ne** radi
///
/// Ne filtrira, ne sortira po pravilima, ne oduzima buffer, ne provjerava `minAdvanceBookingHours`
/// i ne izbacuje prošla vremena. Sve to je već primijenjeno u funkciji koja je vratila listu.
/// Jedina obrada je mapiranje redova u [AvailableSlot] i [LocalDate].
class BookingRepository {
  const BookingRepository(this._client);

  final SupabaseClient _client;

  /// Slobodni termini za uslugu na dati datum.
  ///
  /// [employeeId] `null` znači "bilo koji radnik" — funkcija tada vraća red po svakom
  /// slobodnom radniku, pa se isto vrijeme može pojaviti više puta. Grupisanje za prikaz
  /// radi `AvailableSlotList.distinctTimes`.
  ///
  /// Prazna lista je **prazno stanje, ne greška**: dan bez slobodnih termina je normalan
  /// ishod i ekran ga prikazuje kao takav.
  Future<List<AvailableSlot>> availableSlots({
    required String salonId,
    required String serviceId,
    required LocalDate date,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'get_available_slots',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_date': date.format(),
        'p_employee_id': employeeId,
      },
    );

    return availableSlotsFromRows(rows);
  });

  /// Datumi u rasponu koji imaju bar jedan slobodan termin.
  ///
  /// Ovo je upit za `bookingGranularity: date_only` (`docs/05 §4`), gdje klijent bira samo
  /// dan a salon dodjeljuje vrijeme. Koristi se i u `exact_slot` modu, da traka datuma
  /// odmah pokaže koji su dani puni — bez toga korisnik bira dan po dan dok ne pogodi.
  ///
  /// Raspon se ne širi ovdje: `maxAdvanceBookingDays` dolazi iz postavki i odlučuje ga
  /// pozivalac, jer je to prikaz, ne pravilo dostupnosti.
  Future<List<LocalDate>> availableDates({
    required String salonId,
    required String serviceId,
    required LocalDate from,
    required LocalDate to,
    String? employeeId,
  }) => guard(() async {
    final rows = await _client.rpc<dynamic>(
      'get_available_dates',
      params: {
        'p_salon_id': salonId,
        'p_service_id': serviceId,
        'p_from': from.format(),
        'p_to': to.format(),
        'p_employee_id': employeeId,
      },
    );

    return availableDatesFromRows(rows);
  });

  /// Kreira termin i vraća red onakav kakav je nastao.
  ///
  /// Termin **uvijek** nastaje kao `pending` — i kad salon radi u `auto` modu, potvrdu
  /// dodjeljuje baza, ne ovaj poziv. Success ekran zato govori "zahtjev poslan", a ne
  /// "termin potvrđen" (`docs/01 §18`).
  ///
  /// [employeeId] `null` prepušta izbor radnika bazi: `book_appointment` uzme prvog
  /// slobodnog iz re-validacije. Red bez radnika ne bi bio pokriven exclusion constraintom,
  /// pa radnik nikad ne ostaje prazan.
  ///
  /// **Baca `ConflictError` kad je slot u međuvremenu otišao** (`PT409`). To nije generička
  /// greška nego očekivan ishod ovog poziva — ekran na njega osvježava listu slotova, v.
  /// dokumentaciju uz `ConflictError`.
  ///
  /// Poziv traži prijavljenog korisnika: `book_appointment` je grantovan samo roli
  /// `authenticated` (`docs/06 §1.1` — login se traži na kraju flowa, ne prije). Bez
  /// tokena stiže `NotFoundError`, jer je RLS odbijanje namjerno neraspoznatljivo od
  /// nepostojećeg reda.
  Future<Appointment> book({
    required String salonId,
    required String customerId,
    required String serviceId,
    required LocalDate date,
    required LocalTime startTime,
    String? employeeId,
    String? note,
    String? deviceId,
  }) => guard(() async {
    final row = await _client.rpc<dynamic>(
      'book_appointment',
      params: {
        'p_salon_id': salonId,
        'p_customer_id': customerId,
        'p_service_id': serviceId,
        'p_date': date.format(),
        'p_start_time': startTime.format(),
        'p_employee_id': employeeId,
        'p_note': note,
        'p_device_id': deviceId,
      },
    );

    return appointmentFromRpcRow(row);
  });
}

/// Mapira izlaz `get_available_slots` na [AvailableSlot].
///
/// Izdvojeno iz repozitorija po istom razlogu kao `verticalFromSalonRow`: pravila su u
/// mapiranju, `.rpc(...)` je tuđi kod koji test ne treba lažirati.
@visibleForTesting
List<AvailableSlot> availableSlotsFromRows(dynamic rows) {
  if (rows == null) return const [];
  if (rows is! List) {
    throw MappingError('`get_available_slots` nije vratio listu');
  }
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map(AvailableSlot.fromJson)
        .toList(growable: false);
  } on ApiError {
    rethrow;
  } catch (error) {
    throw MappingError('Neispravan red iz `get_available_slots`', cause: error);
  }
}

/// Mapira izlaz `get_available_dates` na [LocalDate].
///
/// Funkcija vraća `table (available_date date)`, pa svaki red stiže kao mapa sa jednim
/// ključem — ne kao goli string. Zamka je tiha: `rows.cast<String>()` prolazi analizu i
/// puca tek u runtimeu.
@visibleForTesting
List<LocalDate> availableDatesFromRows(dynamic rows) {
  if (rows == null) return const [];
  if (rows is! List) {
    throw MappingError('`get_available_dates` nije vratio listu');
  }
  try {
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => LocalDate.parse(row['available_date'] as String))
        .toList(growable: false);
  } catch (error) {
    throw MappingError('Neispravan red iz `get_available_dates`', cause: error);
  }
}

/// Mapira izlaz `book_appointment` na [Appointment].
///
/// Funkcija je `returns public.appointments` — jedan red, ne lista. PostgREST ga vraća kao
/// mapu, ali kad se potpis funkcije promijeni u `setof`, isti poziv počne vraćati listu;
/// zato se oblik provjerava umjesto da se kastuje naslijepo.
@visibleForTesting
Appointment appointmentFromRpcRow(dynamic row) {
  final json = switch (row) {
    Map<String, dynamic>() => row,
    List<dynamic>() when row.length == 1 => row.first as Map<String, dynamic>,
    List<dynamic>() when row.isEmpty => throw MappingError(
      '`book_appointment` nije vratio termin',
    ),
    _ => throw MappingError(
      '`book_appointment` je vratio neočekivan oblik: ${row.runtimeType}',
    ),
  };

  try {
    return Appointment.fromJson(json);
  } catch (error) {
    throw MappingError('Neispravan `appointments` red', cause: error);
  }
}
