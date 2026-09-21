import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';

/// Šta lista termina trenutno prikazuje — jedan dan i, opciono, jedan status.
class AppointmentsFilter {
  const AppointmentsFilter({required this.dan, this.status});

  final DateTime dan;

  /// `null` znači **svi statusi**, ne „nijedan".
  final AppointmentStatus? status;

  AppointmentsFilter kopija({DateTime? dan, AppointmentStatus? status}) =>
      AppointmentsFilter(dan: dan ?? this.dan, status: status);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentsFilter &&
          other.dan.year == dan.year &&
          other.dan.month == dan.month &&
          other.dan.day == dan.day &&
          other.status == status;

  @override
  int get hashCode => Object.hash(dan.year, dan.month, dan.day, status);
}

/// Filter liste termina. Počinje na **danas, svi statusi**.
class AppointmentsFilterNotifier extends Notifier<AppointmentsFilter> {
  @override
  AppointmentsFilter build() {
    final sada = DateTime.now();
    // Bez vremena: `AppointmentsFilter` poredi samo datum, a `DateTime.now()` sa satima bi
    // dao novu vrijednost pri svakom citanju i vrtio upit u krug.
    return AppointmentsFilter(dan: DateTime(sada.year, sada.month, sada.day));
  }

  void postaviDan(DateTime dan) {
    state = state.kopija(
      dan: DateTime(dan.year, dan.month, dan.day),
      status: state.status,
    );
  }

  void pomjeriDan(int dana) {
    final novi = state.dan.add(Duration(days: dana));
    // `DateTime.add` sa danima preskace ljetno/zimsko racunanje vremena: 23-satni dan bi
    // dao isti datum nazad. Normalizacija na ponoc to poravna.
    postaviDan(DateTime(novi.year, novi.month, novi.day));
  }

  /// `null` vraća na „svi statusi". Ponovni tap na već izabran status ga isključuje —
  /// inače se filter ne može poništiti bez traženja dugmeta „Svi".
  void postaviStatus(AppointmentStatus? status) =>
      postaviStatusTacno(state.status == status ? null : status);

  /// Postavlja status **bez prebacivanja**.
  ///
  /// Postoji odvojeno od [postaviStatus] zbog URL-a: `/appointments?status=pending`
  /// otvoren dok je „na čekanju" već izabran mora ostati filtriran. Da ruta zove metodu
  /// koja prebacuje, ista adresa bi davala dva različita ekrana — filtrirani kad se dođe
  /// izvana, prazan filter kad se ćelija „Zahtjevi" tapne dvaput.
  void postaviStatusTacno(AppointmentStatus? status) {
    state = state.kopija(dan: state.dan, status: status);
  }
}

/// Ime query parametra kojim URL nosi filter statusa.
const String kStatusUpit = 'status';

/// Status iz URL-a — `null` znači „svi", i to je jedini ispravan odgovor na smeće.
///
/// **Namjerno ne koristi `AppointmentStatus.fromWire`.** Ono nepoznatu vrijednost mapira u
/// `unknown`, što je tačno za red iz baze (buduća migracija ne smije srušiti parsiranje),
/// ali pogrešno za adresu koju čovjek može otkucati: `?status=blabla` bi filtrirao po
/// statusu koji nijedan termin nema i dao prazan ekran umjesto pune liste.
AppointmentStatus? statusIzUpita(String? vrijednost) {
  if (vrijednost == null || vrijednost.isEmpty) return null;

  for (final status in AppointmentStatus.values) {
    if (status == AppointmentStatus.unknown) continue;
    if (status.wireName == vrijednost) return status;
  }
  return null;
}

final appointmentsFilterProvider =
    NotifierProvider<AppointmentsFilterNotifier, AppointmentsFilter>(
      AppointmentsFilterNotifier.new,
    );

/// Termini po trenutnom filteru.
///
/// Prazna lista kad admin nije prijavljen ili nije vezan za salon — ekran tada ionako ne
/// stoji, jer ga router ne pušta, ali provider ne smije baciti izuzetak na tom putu.
final filtriraniTerminiProvider = FutureProvider<List<Appointment>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  final filter = ref.watch(appointmentsFilterProvider);
  final repozitorij = ref.watch(staffAppointmentRepositoryProvider);

  // Jedan dan, pa `forRange` sa istim krajevima: filter po statusu zivi tamo, a dvije
  // metode za isti ekran bi znacile dva mjesta koja treba mijenjati kad filter naraste.
  return repozitorij.forRange(
    salonId: salonId,
    from: filter.dan,
    to: filter.dan,
    status: filter.status,
  );
});

/// Broj `pending` zahtjeva — brojka na dashboardu.
final pendingCountProvider = FutureProvider<int>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return 0;

  return ref
      .watch(staffAppointmentRepositoryProvider)
      .pendingCount(salonId: salonId);
});

/// Današnji termini — dashboard ih pokazuje bez obzira na filter liste.
final danasnjiTerminiProvider = FutureProvider<List<Appointment>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref
      .watch(staffAppointmentRepositoryProvider)
      .forDay(salonId: salonId, day: DateTime.now());
});

/// Naziv statusa na bosanskom.
///
/// Stoji ovdje, a ne na modelu: `core_domain` je zajednički sa klijentskom app-om, gdje se
/// isti status zove drugačije prema korisniku („Zahtjev poslan" umjesto „Na čekanju").
String statusLabela(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Na čekanju',
  AppointmentStatus.confirmed => 'Potvrđeni',
  AppointmentStatus.cancelled => 'Otkazani',
  AppointmentStatus.completed => 'Završeni',
  AppointmentStatus.noShow => 'Nisu došli',
  AppointmentStatus.unknown => 'Nepoznato',
};

/// Akcije nad terminom — potvrdi, odbij, otkaži, no-show, završi.
///
/// Odvojeno od `FutureProvider`-a koji čitaju: čitanje se `watch`-uje i osvježava samo,
/// akcija se `read`-uje jednom iz `onPressed`. Da su na istom mjestu, svaki poziv akcije bi
/// izgledao kao zavisnost ekrana.
///
/// **Svaka akcija osvježava liste na kraju.** `invalidate` umjesto ručnog mijenjanja liste u
/// memoriji: baza je ta koja odlučuje šta je termin postao (idempotencija, brojači,
/// `cancelled_by`), pa je ponovno čitanje jedini način da ekran pokaže ono što stvarno piše.
class AppointmentActions {
  const AppointmentActions(this._ref);

  final Ref _ref;

  /// Osvježava sve tri liste koje termin dotiče.
  ///
  /// I `pendingCount` — potvrda mijenja brojku na dashboardu, a brojka koja ostane stara
  /// poslije akcije izgleda kao da akcija nije prošla.
  void _osvjezi() {
    _ref
      ..invalidate(filtriraniTerminiProvider)
      ..invalidate(danasnjiTerminiProvider)
      ..invalidate(pendingCountProvider);
  }

  String? get _salonId => _ref.read(adminSalonIdProvider);

  Future<Appointment?> potvrdi(String appointmentId) => _izvrsi(
    (repo, salonId) =>
        repo.confirm(salonId: salonId, appointmentId: appointmentId),
  );

  Future<Appointment?> odbij(String appointmentId, {String? razlog}) => _izvrsi(
    (repo, salonId) => repo.reject(
      salonId: salonId,
      appointmentId: appointmentId,
      reason: razlog,
    ),
  );

  Future<Appointment?> otkazi(String appointmentId, {String? razlog}) =>
      _izvrsi(
        (repo, salonId) => repo.cancel(
          salonId: salonId,
          appointmentId: appointmentId,
          reason: razlog,
        ),
      );

  Future<Appointment?> nijeDosao(String appointmentId, {String? razlog}) =>
      _izvrsi(
        (repo, salonId) => repo.markNoShow(
          salonId: salonId,
          appointmentId: appointmentId,
          reason: razlog,
        ),
      );

  Future<Appointment?> zavrsen(String appointmentId) => _izvrsi(
    (repo, salonId) =>
        repo.markCompleted(salonId: salonId, appointmentId: appointmentId),
  );

  /// Zajedničko tijelo: bez salona nema akcije, i lista se osvježava tek po uspjehu.
  ///
  /// **Greška se propušta dalje, ne guta.** Ekran je taj koji zna kako je prikazati, a
  /// akcija koja tiho ne uradi ništa je gora od poruke o grešci.
  Future<Appointment?> _izvrsi(
    Future<Appointment> Function(StaffAppointmentRepository, String) poziv,
  ) async {
    final salonId = _salonId;
    if (salonId == null) return null;

    final rezultat = await poziv(
      _ref.read(staffAppointmentRepositoryProvider),
      salonId,
    );
    _osvjezi();
    return rezultat;
  }
}

final appointmentActionsProvider = Provider<AppointmentActions>(
  AppointmentActions.new,
);

// ---------------------------------------------------------------------------
// Katalog za ručni unos
// ---------------------------------------------------------------------------
// **`servicesProvider` i `employeesProvider` iz `core_api` se ovdje ne mogu koristiti.**
// Oni čitaju `currentSalonIdProvider`, koji klijentska app override-uje iz `SALON_ID`
// flavora — admin app ga nema i ne smije ga imati, jer je jedna za sve salone (ADR-0003).
// Neoverride-ovan provider baca `UnimplementedError`, pa bi ekran pukao tek pri otvaranju,
// a ne pri kompajliranju.
//
// Admin salon dolazi iz `adminSalonIdProvider`, tj. iz `StaffMember.salonId` — iz reda u
// `public.users`, koji je isti podatak na koji se oslanja `private.is_admin()`.

/// Usluge salona kojim admin upravlja.
final adminServicesProvider = FutureProvider<List<Service>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(serviceRepositoryProvider).forSalon(salonId);
});

/// Radnici salona kojim admin upravlja.
final adminEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref
      .watch(employeeRepositoryProvider)
      .forSalon(salonId, includeInactive: true);
});

/// Veze radnik–usluga: koji radnik radi koju uslugu.
///
/// Ručni unos ih treba iz istog razloga kao klijentski booking flow — lista radnika za
/// izabranu uslugu je **presjek**, ne svi radnici. Salon koji ima frizera i kozmetičara ne
/// smije ponuditi kozmetičara za šišanje.
final adminEmployeeLinksProvider = FutureProvider<List<EmployeeService>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(employeeRepositoryProvider).serviceLinksForSalon(salonId);
});

/// Kratka oznaka statusa — ono što stoji u piluli uz termin.
///
/// **Nije isto što i [statusLabela].** Filter u listi imenuje *grupu* redova („Potvrđeni",
/// „Otkazani"), a pilula imenuje *jedan* termin („Potvrđeno", „Otkazano"), kako ga canvas i
/// piše. Jedan string za oboje je do taska 30 značio da uz termin piše množina.
String statusOznaka(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Na čekanju',
  AppointmentStatus.confirmed => 'Potvrđeno',
  AppointmentStatus.cancelled => 'Otkazano',
  AppointmentStatus.completed => 'Završeno',
  AppointmentStatus.noShow => 'Nije došao',
  AppointmentStatus.unknown => 'Nepoznato',
};

/// Par boja koji status nosi — podloga i tekst na njoj.
///
/// Stoji uz [statusOznaka], jer su to dvije polovine iste odluke: kako se status **zove** i
/// kako **izgleda**. Do taska 31 je `switch` postojao u `status_pill.dart`, pa je kalendar
/// dopisao svoj — dvije mape se raziđu prvi put kad se doda status, a razlika se vidi tek
/// kad se dva ekrana otvore jedan uz drugi.
AdminStatusTone statusTon(
  AdminStatusColors statusi,
  AppointmentStatus status,
) => switch (status) {
  AppointmentStatus.pending => statusi.waiting,
  AppointmentStatus.confirmed => statusi.positive,
  AppointmentStatus.cancelled => statusi.negative,
  AppointmentStatus.completed => statusi.neutral,
  // „Nije se pojavio" nije otkazivanje: otkazao je neko, ovo se prosto desilo.
  AppointmentStatus.noShow => statusi.negativeQuiet,
  AppointmentStatus.unknown => statusi.neutral,
};

/// Oznaka termina koji **upravo traje**.
///
/// Nije `AppointmentStatus`: u bazi se terminu ništa ne mijenja kad počne. Enum opisuje
/// red, ovo opisuje trenutak u kojem se red gleda.
const String kOznakaUToku = 'U toku';

/// Salon kojim admin upravlja.
///
/// Postoji zbog **imena**: breadcrumb `Vitez / Danas` iz `3b` i kartica lokacije iz `3k`
/// traže ime salona, a `StaffMember` nosi samo `salonId` — red u `public.users` nema
/// naziv. Ime se zato čita iz `salons`, istim repozitorijem kao u klijentskoj app-i.
///
/// `null` dok se ne učita ili kad admin nije vezan za salon; ekran tada crta samo naslov,
/// bez lijeve strane breadcrumba.
final adminSalonProvider = FutureProvider<Salon?>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref.watch(salonRepositoryProvider).byId(salonId);
});

/// Koliko dana unaprijed kartica „Zahtjevi" gleda.
///
/// Zahtjev za termin za dva mjeseca je rijedak, ali postoji; 60 dana je granica upita, ne
/// tvrdnja o proizvodu. Brojač u navigaciji broji **sve** `pending` redove
/// ([pendingCountProvider]), pa se ta dva broja mogu raziću — kartica zato nosi „Vidi sve",
/// koje vodi na punu filtriranu listu.
const int kZahtjeviHorizontDana = 60;

/// Zahtjevi koji čekaju odgovor — od danas unaprijed, najstariji prvi.
///
/// **Ne gleda unazad.** `pending` termin kojem je vrijeme prošlo nije zahtjev nego ostatak;
/// potvrda takvog reda bi upisala termin u prošlost, a odbijanje ništa ne mijenja.
final zahtjeviProvider = FutureProvider<List<Appointment>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  final danas = DateTime.now();
  return ref
      .watch(staffAppointmentRepositoryProvider)
      .forRange(
        salonId: salonId,
        from: DateTime(danas.year, danas.month, danas.day),
        to: DateTime(
          danas.year,
          danas.month,
          danas.day,
        ).add(const Duration(days: kZahtjeviHorizontDana)),
        status: AppointmentStatus.pending,
      );
});

/// Usluge po `id`-u — ime i cijena za red termina.
///
/// `appointments` nosi samo `service_id`, pa svaki ekran koji piše „Fade šišanje · 15 KM"
/// treba cjenovnik. Mapa se gradi **jednom** iz [adminServicesProvider]; kartica koja bi
/// sama tražila svoju uslugu pokrenula bi upit po redu liste.
final uslugePoIdProvider = Provider<Map<String, Service>>((ref) {
  final usluge =
      ref.watch(adminServicesProvider).valueOrNull ?? const <Service>[];
  return {for (final usluga in usluge) usluga.id: usluga};
});

/// Radnici po `id`-u — ime uz termin.
final radniciPoIdProvider = Provider<Map<String, Employee>>((ref) {
  final radnici =
      ref.watch(adminEmployeesProvider).valueOrNull ?? const <Employee>[];
  return {for (final radnik in radnici) radnik.id: radnik};
});

/// Cijene usluga, za sažetak prometa.
final cijenePoUsluziProvider = Provider<Map<String, double>>((ref) {
  return {
    for (final unos in ref.watch(uslugePoIdProvider).entries)
      unos.key: unos.value.price,
  };
});

/// Jedan termin, za ekran detalja.
///
/// `family` po `id`-u iz adrese. `null` znači „nema ga ili nije naš" — ekran ta dva slučaja
/// namjerno ne razlikuje, v. `StaffAppointmentRepository.byId`.
///
/// **Ne čita se iz liste u memoriji.** Detalj se otvara i iz bookmarka i iz obavijesti, kad
/// nijedna lista nije učitana; uz to je nakon akcije svježe čitanje jedini način da ekran
/// pokaže ono što stvarno piše u bazi.
final terminProvider = FutureProvider.family<Appointment?, String>((
  ref,
  appointmentId,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref
      .watch(staffAppointmentRepositoryProvider)
      .byId(salonId: salonId, appointmentId: appointmentId);
});
