import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Čita booking postavke salona iz `public.salon_settings` — tačno jedan red po salonu.
///
/// App ih koristi da zna **šta prikazati** (izbor radnika, cijene, dokle pustiti kalendar),
/// ne da bi sam računao dostupnost — ta pravila baza već primjenjuje u
/// `get_available_slots` i `book_appointment`. Dvije implementacije istih pravila su dvije
/// prilike da se raziđu.
class SettingsRepository {
  const SettingsRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '''
id, salon_id, booking_mode, booking_granularity, buffer_minutes,
slot_step_minutes, min_advance_booking_hours, max_advance_booking_days,
pending_expiry_hours, min_cancel_hours, require_staff_choice,
show_prices_in_app, allow_guest_booking, timezone, language
''';

  /// Postavke salona, ili [NotFoundError] ako reda nema.
  ///
  /// Red **uvijek** treba postojati — `salon_settings.salon_id` je `unique not null` i
  /// onboarding ga pravi uz salon. Nedostatak zato nije prazno stanje nego pogrešno
  /// postavljen tenant, i bolje je da se vidi kao greška nego da app tiho radi sa
  /// defaultima koje salon nikad nije izabrao.
  Future<SalonSettings> forSalon(String salonId) => guard(() async {
    final row = await _client
        .from('salon_settings')
        .select(_columns)
        .eq('salon_id', salonId)
        .maybeSingle();

    if (row == null) {
      throw NotFoundError('Salon $salonId nema red u `salon_settings`');
    }
    return salonSettingsFromRow(row);
  });
}

/// Mapira `salon_settings` red na [SalonSettings].
@visibleForTesting
SalonSettings salonSettingsFromRow(Map<String, dynamic> row) {
  try {
    return SalonSettings.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan `salon_settings` red', cause: error);
  }
}
