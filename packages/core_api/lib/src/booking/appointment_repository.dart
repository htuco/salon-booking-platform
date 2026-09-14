import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
// Mapiranje je izvuceno u `appointment_mapper.dart` kad je dobilo drugog korisnika
// (admin lista termina, task 23). Export stoji da postojeci `import` ovog fajla — i
// testovi koji ga koriste — nastave raditi bez izmjene.
import 'appointment_mapper.dart';
export 'appointment_mapper.dart';

/// Termini prijavljenog klijenta — čitanje i otkazivanje.
///
/// Ne postoji do taska 16 iz konkretnog razloga: `appointments` je do auth rada imao
/// politiku samo za osoblje, pa klijent nije mogao pročitati **nijedan** red (v. status
/// taska 08). Sada `own_appointments` propušta njegove, presječene i po identitetu i po
/// `x-salon-id` headeru.
///
/// ## Čitanje je `from(...)`, otkazivanje je `rpc`
///
/// Asimetrija je namjerna i ista kao svuda u ovom sloju: čitanje ograničava RLS, a upis
/// mora proći kroz validiranu funkciju. `cancel_appointment` provjerava vlasništvo i rok
/// iz `salon_settings.min_cancel_hours`; `update` sa klijenta bi zaobišao oboje — i,
/// gore, ne bi ni pukao nego bi tiho pogodio nula redova (v. `004_cancel_appointment`).
///
/// ## Zašto nema `salonId` filtera u upitu
///
/// Ima ga — samo ga šalje **baza**, iz `x-salon-id` headera koji `bootstrap()` postavlja.
/// Filter u upitu bi izgledao kao sigurnosna mjera, a bio bi samo udvajanje: RLS ionako
/// presijeca, a dva mjesta koja opisuju isto pravilo se raziđu. Isti razlog kao u
/// `CustomerRepository`.
class AppointmentRepository {
  const AppointmentRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '''
id, salon_id, service_id, employee_id, customer_id, auth_identity_id, device_id,
customer_name, customer_phone, customer_note, date, start_time, end_time,
buffer_minutes, status, source, cancel_reason, cancelled_by, pending_expires_at
''';

  /// Termini prijavljenog klijenta u aktivnom salonu, najnoviji prvi.
  ///
  /// Sortira se **po datumu i vremenu silazno**, a razdvajanje na „predstojeće" i „prošle"
  /// radi ekran: granica je *sada*, koje se pomjera između dva otvaranja ekrana, pa je
  /// pitanje prikaza, a ne upita. Upit koji bi vraćao samo buduće bi uz to morao znati
  /// zonu salona — a to zna baza, ne klijent.
  ///
  /// Prazna lista je prazno stanje, ne greška: korisnik koji se tek prijavio nema termina.
  Future<List<Appointment>> forCurrentCustomer() => guard(() async {
    final rows = await _client
        .from('appointments')
        .select(_columns)
        .order('date', ascending: false)
        .order('start_time', ascending: false);

    return appointmentsFromRows(rows);
  });

  /// Otkazuje termin. Vraća osvježen red — `status` je `cancelled`.
  ///
  /// Idempotentno: već otkazan termin vraća isti red bez greške, jer dva uređaja i dva
  /// tapa nisu kvar. Rok je prošao → [NotFoundError] iz `PT403`; završen termin →
  /// [ConflictError] iz `PT409`.
  Future<Appointment> cancel({
    required String salonId,
    required String appointmentId,
    String? reason,
  }) => guard(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'cancel_appointment',
      params: {
        'p_salon_id': salonId,
        'p_appointment_id': appointmentId,
        'p_reason': ?reason,
      },
    );

    return appointmentFromRow(row);
  });
}
