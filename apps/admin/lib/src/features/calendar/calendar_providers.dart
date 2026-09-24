/// Šta kalendar čita i koji dan pokazuje.
///
/// **Kalendar ima svoj datum, odvojen od `appointmentsFilterProvider`.** Dijeljeno stanje
/// bi značilo da otvaranje kalendara tiho pomjeri filter liste termina, i obrnuto — ista
/// vrsta greške koju je task 29 našao na dashboardu, gdje je kartica mijenjala stanje
/// providera pa navigirala, pa su „nazad" i refresh vraćali nešto treće.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appointments/appointments_providers.dart';
import 'calendar_day.dart';

/// Dan koji kalendar pokazuje. Počinje na danas, uvijek normalizovan na ponoć.
class KalendarDatumNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final sada = DateTime.now();
    // Bez sati: vrijednost sa satima bi se mijenjala pri svakom čitanju i vrtjela upit u
    // krug — ista zamka koju `AppointmentsFilterNotifier` već ima zapisanu.
    return DateTime(sada.year, sada.month, sada.day);
  }

  void postavi(DateTime dan) => state = DateTime(dan.year, dan.month, dan.day);

  /// Pomjera prikazani dan.
  ///
  /// **Računa po kalendaru, ne po trajanju.** `state.add(Duration(days: 1))` dodaje 24 sata,
  /// a zadnja nedjelja oktobra u Sarajevu ima 25 — ponoć + 24 h tada padne u 23:00 **istog
  /// dana**, pa normalizacija na ponoć vrati isti datum i strelica „Sljedeći dan" jednom
  /// godišnje ne uradi ništa. Konstruktor `DateTime` prekoračenje dana normalizuje po
  /// kalendaru, pa ljetno računanje vremena u račun nikad ne ulazi.
  void pomjeri(int dana) =>
      postavi(DateTime(state.year, state.month, state.day + dana));

  void danas() => postavi(DateTime.now());
}

final kalendarDatumProvider = NotifierProvider<KalendarDatumNotifier, DateTime>(
  KalendarDatumNotifier.new,
);

/// Radnik izabran na telefonu (`3l` chip traka). `null` = „Svi".
///
/// Postoji samo za mobilni prikaz: desktop `3c` crta sve radnike jedan pored drugog, pa mu
/// izbor ne treba. Stoji ipak ovdje, a ne u `State` ekrana, da izbor preživi rotaciju i
/// prelaz preko breakpointa.
final izabraniRadnikProvider = NotifierProvider<IzabraniRadnik, String?>(
  IzabraniRadnik.new,
);

class IzabraniRadnik extends Notifier<String?> {
  @override
  String? build() => null;

  void postavi(String? radnikId) => state = radnikId;
}

/// Termini izabranog dana.
///
/// **Isti `forDay` koji koristi dashboard** — kalendar ne uvodi nijedan novi upit nad
/// `appointments`. Otkazani termini ostaju u listi, jer slot koji je bio zauzet pa
/// oslobođen nije isto što i slot koji nikad nije ni postojao.
final kalendarTerminiProvider = FutureProvider.autoDispose<List<Appointment>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref
      .watch(staffAppointmentRepositoryProvider)
      .forDay(
        salonId: salonId,
        day: ref.watch(kalendarDatumProvider),
        employeeId: ref.watch(adminRadnikIdProvider),
      );
});

/// Radno vrijeme salona — svi redovi, i salonski i po radniku.
///
/// Ne zavisi od izabranog dana: upit vraća svih sedam dana odjednom, pa listanje kroz
/// sedmicu ne pravi novi upit za raspored.
final kalendarRadnoVrijemeProvider =
    FutureProvider.autoDispose<List<WorkingHour>>((ref) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return const [];

      return ref.watch(workingHoursRepositoryProvider).forSalon(salonId);
    });

/// Blokade izabranog dana.
final kalendarBlokadeProvider = FutureProvider.autoDispose<List<BlockedSlot>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  return ref
      .watch(blockedSlotRepositoryProvider)
      .forDay(salonId: salonId, day: ref.watch(kalendarDatumProvider));
});

/// Sastavljen dan — ono što ekran crta.
///
/// **`autoDispose`, kao i tri čitanja ispod njega.** Desktop `3c` nema pull-to-refresh, a
/// `FutureProvider` bez `autoDispose` drži vrijednost do kraja života aplikacije: vlasnik
/// koji potvrdi zahtjev u modulu „Zahtjevi" pa se vrati na kalendar vidio bi taj termin i
/// dalje narandžastim, dok god ne pomjeri dan i vrati se. Ovako se čitanja oslobode kad
/// ekran ode sa stabla i ponove se pri povratku.
///
/// Čeka **sva četiri** čitanja, umjesto da svako gleda svoj `valueOrNull`. Razlog je
/// tačnost, ne urednost: dan sastavljen dok radno vrijeme još nije stiglo nacrtao bi svaku
/// kolonu kao neradnu, pa bi se na trenutak vidio zatvoren salon. Gubitak veze na bilo
/// kojem od četiri upita je zato greška cijelog ekrana, koju `_Greska` nudi da se ponovi.
final kalendarDanProvider = FutureProvider.autoDispose<KalendarDan>((
  ref,
) async {
  final dan = ref.watch(kalendarDatumProvider);

  final (termini, radnici, radnoVrijeme, blokade) = await (
    ref.watch(kalendarTerminiProvider.future),
    ref.watch(adminEmployeesProvider.future),
    ref.watch(kalendarRadnoVrijemeProvider.future),
    ref.watch(kalendarBlokadeProvider.future),
  ).wait;

  // Radnik vidi **svoju** kolonu, ne salon (task 47). Katalog radnika je javan, pa bi bez
  // ovoga crtao i tuđe kolone — prazne, jer tuđe termine politika ne vraća, i zato lažne:
  // prazna kolona kolege izgleda kao slobodan dan kolege.
  final radnikId = ref.watch(adminRadnikIdProvider);

  return izgradiDan(
    dan: dan,
    radnici: radnikId == null
        ? radnici
        : [
            for (final r in radnici)
              if (r.id == radnikId) r,
          ],
    termini: termini,
    radnoVrijeme: radnoVrijeme,
    blokade: blokade,
  );
});

/// Osvježava sve što kalendar čita.
///
/// Na jednom mjestu, jer se poziva sa dva (pull-to-refresh na telefonu i dugme „Pokušaj
/// opet" u stanju greške) — a provider zaboravljen na jednom od njih daje ekran koji se
/// „ponekad" ne osvježi.
///
/// **Usluge su peto čitanje, i lako ispadnu.** Kalendar ih ne čita direktno nego kroz
/// `uslugePoIdProvider`, ali o njima zavisi naziv usluge u bloku i u mobilnom redu; bez
/// ovog reda preimenovana usluga preživi i pull-to-refresh i „Pokušaj opet".
void osvjeziKalendar(WidgetRef ref) {
  ref
    ..invalidate(kalendarTerminiProvider)
    ..invalidate(kalendarBlokadeProvider)
    ..invalidate(kalendarRadnoVrijemeProvider)
    ..invalidate(adminEmployeesProvider)
    ..invalidate(adminServicesProvider);
}

/// Sat ekrana — jedan izvor „sada" za liniju trenutnog vremena i za oznaku „U toku".
///
/// **Stream, ne `DateTime.now()` u `build`-u.** Linija koja se ne pomjera je gora od
/// linije koje nema: kalendar otvoren cijelo prijepodne bi tvrdio da je i dalje devet.
/// Minuta je dovoljno sitan korak — osa je 80 px po satu, pa je pomak po minuti 1,3 px.
///
/// Test ga override-uje sa `Stream.value(...)`. Bez toga bi svaki widget test kalendara
/// zavisio od doba dana, što je tačno zamka zbog koje task 31 i ima svoju napomenu.
///
/// **`autoDispose` zaustavlja kucanje kad kalendar nije otvoren.** Bez njega bi
/// `Stream.periodic` radio do kraja života aplikacije, iako liniju „sada" crta jedan ekran.
final sadaProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});
