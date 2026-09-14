import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  void postaviStatus(AppointmentStatus? status) {
    state = state.kopija(
      dan: state.dan,
      status: state.status == status ? null : status,
    );
  }
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

  return ref.watch(employeeRepositoryProvider).forSalon(salonId);
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
