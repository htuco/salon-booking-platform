import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Termini razvrstani na „predstojeće" i „prošle".
///
/// **Granica je *sada*, i zato je ovdje, a ne u upitu.** Repozitorij vraća sve termine
/// sortirane po datumu; koji su od njih prošli zavisi od trenutka gledanja, a taj se
/// pomjera između dva otvaranja ekrana. Upit koji bi vraćao samo buduće bi uz to morao
/// znati zonu salona — a to zna baza, ne klijent.
@immutable
class SplitAppointments {
  const SplitAppointments({required this.upcoming, required this.past});

  static const SplitAppointments empty = SplitAppointments(
    upcoming: [],
    past: [],
  );

  /// Termini koji tek dolaze — najbliži prvi.
  final List<Appointment> upcoming;

  /// Termini iza nas — najnoviji prvi.
  final List<Appointment> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;
}

/// Razvrstava termine oko [now].
///
/// **Zatvoren termin ide u „prošle" bez obzira na datum.** Otkazan termin za sljedeću
/// sedmicu nije „predstojeći" — korisnik na njega ne dolazi, a kartica sa dugmetom
/// „otkaži" iznad otkazanog termina je besmislena. Isto važi za `completed` i `no_show`.
@visibleForTesting
SplitAppointments splitAppointments(
  List<Appointment> sve, {
  required DateTime now,
}) {
  final upcoming = <Appointment>[];
  final past = <Appointment>[];

  for (final a in sve) {
    if (a.status.isClosed || !_jeUBuducnosti(a, now)) {
      past.add(a);
    } else {
      upcoming.add(a);
    }
  }

  // Repozitorij sortira silazno (najnoviji prvi) — to je tačno za „prošle", a za
  // „predstojeće" je obrnuto: prvi na redu mora biti na vrhu.
  upcoming.sort((a, b) {
    final poDatumu = a.date.compareTo(b.date);
    return poDatumu != 0
        ? poDatumu
        : a.startTime.minutesFromMidnight.compareTo(
            b.startTime.minutesFromMidnight,
          );
  });

  return SplitAppointments(upcoming: upcoming, past: past);
}

/// Da li termin još nije počeo, u **zidnom vremenu** — bez zone.
///
/// `LocalDate`/`LocalTime` su namjerno bez zone (v. `core_domain`): salon radi po svom
/// zidnom satu. Poređenje ide sa lokalnim `DateTime` uređaja, što je tačno dok je korisnik
/// u istoj zoni kao salon — a to je slučaj za klijenta koji dolazi na termin. Putnik iz
/// druge zone vidi svoj termin nekoliko sati pomjeren u razvrstavanju, ali **nikad** u
/// prikazanom vremenu: ono se crta iz `startTime`, doslovno.
bool _jeUBuducnosti(Appointment a, DateTime now) {
  final pocetak = DateTime(
    a.date.year,
    a.date.month,
    a.date.day,
    a.startTime.hour,
    a.startTime.minute,
  );
  return pocetak.isAfter(now);
}

/// Trenutak koji dijeli prošlo od budućeg.
///
/// Provider, a ne `DateTime.now()` u ekranu, iz istog razloga kao `bookingTodayProvider`:
/// test koji podiže ekran mora znati gdje je granica. Sa direktnim pozivom bi isti test
/// prolazio danas a padao sutra.
final appointmentsNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Termini prijavljenog korisnika, razvrstani.
final splitAppointmentsProvider = Provider<AsyncValue<SplitAppointments>>((
  ref,
) {
  final now = ref.watch(appointmentsNowProvider);
  return ref
      .watch(myAppointmentsProvider)
      .whenData((sve) => splitAppointments(sve, now: now));
});

/// Koliko sati prije termina se još smije otkazati — iz `salon_settings`, nikad iz
/// konstante.
///
/// Isto pravilo baza primjenjuje u `cancel_appointment`; ovdje se **samo prikazuje**.
/// Dvije implementacije istog pravila su dvije prilike da se raziđu, pa ekran ne odlučuje
/// ništa — kad se raziđu, baza je u pravu i njena greška izlazi na ekran.
///
/// **Izvor je `salon_settings.min_cancel_hours`, isti red koji čita baza.** Vertikala
/// nosi samo podrazumijevanu vrijednost pri kreiranju salona; kad vlasnik rok promijeni u
/// postavkama, vertikala ostaje na starom broju i dugme bi nudilo otkazivanje koje baza
/// odbije sa `PT403`. Vertikala je ovdje samo rezerva dok postavke ne stignu.
final minCancelHoursProvider = Provider<int>((ref) {
  final settings = ref.watch(salonSettingsProvider).valueOrNull;
  if (settings != null) return settings.minCancelHours;
  final vertical = ref.watch(verticalProvider).valueOrNull;
  return vertical?.rules.minCancelHours ?? 0;
});

/// Da li je [appointment] još u roku za otkazivanje.
///
/// **Ovo je prikaz, ne autorizacija.** Baza odlučuje; dugme je onemogućeno unaprijed samo
/// da korisnik ne dobije grešku na nešto što se vidjelo da neće proći.
bool canCancel(
  Appointment appointment, {
  required DateTime now,
  required int minCancelHours,
}) {
  if (appointment.status.isClosed) return false;

  final pocetak = DateTime(
    appointment.date.year,
    appointment.date.month,
    appointment.date.day,
    appointment.startTime.hour,
    appointment.startTime.minute,
  );
  return pocetak.difference(now) >= Duration(hours: minCancelHours);
}

/// Otkazivanje jednog termina.
///
/// `family` po `id`-u: dvije kartice mogu imati svoje stanje, pa `loading` na jednoj ne
/// blokira drugu. Bez toga bi otkazivanje jednog termina zavrtjelo indikator na svima.
final cancelAppointmentProvider = AsyncNotifierProvider.autoDispose
    .family<CancelAppointmentNotifier, void, String>(
      CancelAppointmentNotifier.new,
    );

class CancelAppointmentNotifier
    extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  Future<void> build(String arg) async {}

  /// Otkazuje termin i vraća `true` kad je prošlo.
  ///
  /// Ne navigira i ne prikazuje poruke — to radi ekran, koji jedini ima `context`. Isti
  /// razlog kao u `BookingSubmitNotifier.submit`.
  Future<bool> cancel() async {
    state = const AsyncValue<void>.loading();

    try {
      await ref
          .read(appointmentRepositoryProvider)
          .cancel(
            salonId: ref.read(currentSalonIdProvider),
            appointmentId: arg,
          );

      // Lista se ne „ažurira" nego se baca: otkazivanje mijenja i status termina i
      // slobodne slotove, a jedina istina o oboje je u bazi.
      ref.invalidate(myAppointmentsProvider);
      state = const AsyncValue<void>.data(null);
      return true;
    } on ApiError catch (error, stack) {
      state = AsyncValue<void>.error(error, stack);
      return false;
    }
  }
}
