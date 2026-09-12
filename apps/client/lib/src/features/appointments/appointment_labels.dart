import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Tekst i ton statusa termina — **na jednom mjestu**.
///
/// Kartica, detalj i (kasnije) obavijesti prikazuju isti status; kad bi svaki od njih
/// mapirao sam, prvi sljedeći status bi negdje ostao neprepoznat, a ekran bi i dalje
/// izgledao ispravno.
String statusLabel(AppLocalizations l10n, AppointmentStatus status) =>
    switch (status) {
      AppointmentStatus.pending => l10n.appointmentStatusPending,
      AppointmentStatus.confirmed => l10n.appointmentStatusConfirmed,
      AppointmentStatus.cancelled => l10n.appointmentStatusCancelled,
      AppointmentStatus.completed => l10n.appointmentStatusCompleted,
      AppointmentStatus.noShow => l10n.appointmentStatusNoShow,
      AppointmentStatus.unknown => l10n.appointmentStatusUnknown,
    };

/// Ton badgea po statusu.
///
/// **`pending` je `warning`, ne `info`.** Naučeno u tasku 10: statusne boje su
/// brand-neutralne, pa plava mrlja stoji preko oba brenda; uz to „na čekanju" jeste
/// stanje koje traži pažnju — korisnik treba znati da termin **još nije njegov**.
StatusTone statusTone(AppointmentStatus status) => switch (status) {
  AppointmentStatus.confirmed => StatusTone.success,
  AppointmentStatus.pending => StatusTone.warning,
  AppointmentStatus.cancelled || AppointmentStatus.noShow => StatusTone.danger,
  AppointmentStatus.completed => StatusTone.blocked,
  AppointmentStatus.unknown => StatusTone.blocked,
};

/// Dopunska rečenica uz otkazan termin — **ko** je otkazao.
///
/// Razlika nije kozmetička: „otkazao salon" i „otkazali ste vi" su za korisnika dva
/// različita događaja, a `system` (istekao `pending`) je treći i ne smije izgledati kao
/// da ga je neko odbio.
String? cancelledByNote(AppLocalizations l10n, Appointment appointment) {
  if (appointment.status != AppointmentStatus.cancelled) return null;

  return switch (appointment.cancelledBy) {
    'salon' => l10n.appointmentCancelledBySalon,
    'system' => l10n.appointmentCancelledBySystem,
    // `customer` namjerno nema napomenu: korisnik zna da je sam otkazao.
    _ => null,
  };
}
