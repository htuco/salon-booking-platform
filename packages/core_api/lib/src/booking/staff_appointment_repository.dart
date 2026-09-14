import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';
import 'appointment_mapper.dart';

/// Termini salona, čitani iz **admin** aplikacije.
///
/// ## Zašto ne `AppointmentRepository`
///
/// Klijentski repozitorij se oslanja na `x-salon-id` header koji `bootstrap()` postavlja iz
/// `SALON_ID` flavora. **Admin app taj header nema i ne smije ga imati:** jedna je za sve
/// salone, pa bi header značio da admin sam sebi bira kontekst. Njegova prava idu kroz
/// `private.is_admin()`, koji čita JWT claim i red u `public.users`
/// ([ADR-0003](../../../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
///
/// Uz to su i upiti drugi: klijent traži *svoje* termine kroz sva vremena, admin traži
/// *jedan dan* ili *jedan status* kroz sve klijente.
///
/// ## `salonId` se prosljeđuje, ali ne štiti
///
/// Metode primaju [salonId] jer admin app mora znati **koji** salon prikazuje — dobija ga iz
/// `StaffMember.salonId`, ne iz UI-ja. Taj filter je tu da upit bude precizan, a ne da čuva
/// podatak: `staff_manage` politika ionako presijeca na članstvo, pa admin koji bi poslao
/// tuđi `salonId` dobije **praznu listu**, ne tuđe termine. Dokazano u
/// `supabase/tests/rest_admin_login.ts`.
///
/// **Samo čitanje.** Potvrda, odbijanje i ručni termin dolaze sa
/// [taskom 24](../../../../tasks/sprint-2/24-admin-akcije-nad-terminima.md) — i moraju ići
/// kroz `book_appointment`, jer direktan `insert` zaobilazi provjeru preklapanja slotova
/// (`.claude/docs/security.md`).
class StaffAppointmentRepository {
  const StaffAppointmentRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '''
id, salon_id, service_id, employee_id, customer_id, auth_identity_id, device_id,
customer_name, customer_phone, customer_note, date, start_time, end_time,
buffer_minutes, status, source, cancel_reason, cancelled_by, pending_expires_at
''';

  /// Termini jednog dana, po vremenu početka.
  ///
  /// Rastuće, za razliku od klijentske liste: admin gleda **raspored dana** odozgo nadolje,
  /// a klijent svoju historiju od najnovijeg. Isti podatak, druga svrha.
  ///
  /// Otkazani termini **ostaju u listi**. Dan sa tri termina od kojih je jedan otkazan nije
  /// isto što i dan sa dva — vlasnik mora vidjeti da je neko otkazao, inače izgleda kao da
  /// termin nikad nije ni postojao.
  Future<List<Appointment>> forDay({
    required String salonId,
    required DateTime day,
  }) => guard(() async {
    final rows = await _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('date', _datum(day))
        .order('start_time');

    return appointmentsFromRows(rows);
  });

  /// Termini u rasponu dana, po datumu pa po vremenu.
  ///
  /// Oba kraja su **uključena**: `from: danas, to: danas` je jedan dan, ne prazan raspon.
  /// Isključiv kraj bi značio da lista „danas" traži `to: sutra`, što se pogrešno napiše
  /// jednom pa se svaki put nakon toga prepisuje.
  Future<List<Appointment>> forRange({
    required String salonId,
    required DateTime from,
    required DateTime to,
    AppointmentStatus? status,
  }) => guard(() async {
    var upit = _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .gte('date', _datum(from))
        .lte('date', _datum(to));

    // Filter po statusu je opcion: `null` znači „svi", ne „nijedan". Ekran ga šalje samo
    // kad je korisnik izabrao status u filteru.
    if (status != null && status != AppointmentStatus.unknown) {
      // `wireName`, ne `.name`: `noShow` u bazi stoji kao `no_show`, pa bi `.name` tiho
      // filtrirao nula redova umjesto da pukne.
      upit = upit.eq('status', status.wireName);
    }

    final rows = await upit.order('date').order('start_time');
    return appointmentsFromRows(rows);
  });

  /// Broj zahtjeva koji čekaju odgovor — brojka na dashboardu.
  ///
  /// Broji **baza**, ne Dart: PostgREST reže odgovor na `max_rows`, pa bi salon sa mnogo
  /// termina dao tih i pogrešan broj da se lista povlači pa broji u app-i. Isti razlog zbog
  /// kojeg prosjek ocjena računa pogled, a ne ekran (task 20).
  ///
  /// **Bez datumskog ograničenja.** `pending` zahtjev od prije tri dana je i dalje zahtjev
  /// koji niko nije pogledao; skrivanje starih bi sakrilo baš one koji su ispali iz vida.
  Future<int> pendingCount({required String salonId}) => guard(() async {
    final odgovor = await _client
        .from('appointments')
        .select(_columns)
        .eq('salon_id', salonId)
        .eq('status', AppointmentStatus.pending.wireName)
        .count(CountOption.exact);

    return odgovor.count;
  });

  /// `date` kolona je `date`, ne `timestamptz` — šalje se `YYYY-MM-DD`, bez zone.
  ///
  /// Zona je namjerno izvan ovoga: `DateTime` sa lokalnom zonom pretvoren u ISO string bi
  /// oko ponoći dao susjedni dan, i lista „danas" bi u 00:30 pokazala jučerašnje termine.
  static String _datum(DateTime dan) =>
      '${dan.year.toString().padLeft(4, '0')}-'
      '${dan.month.toString().padLeft(2, '0')}-'
      '${dan.day.toString().padLeft(2, '0')}';
}
