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
