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

export '../../core/sat.dart';

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
/// Dnevni desktop `3c` ga ne čita: crta sve radnike jedan pored drugog. Čitaju ga mobilni
/// dan i **sedmica na oba ekrana** (task 69), gdje su svi radnici u istoj koloni dana pa
/// čipovi filtriraju. Stoji ovdje, a ne u `State` ekrana, da izbor preživi rotaciju i
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

/// Šta kalendar pokazuje — prekidač `Dan · Sedmica · Mjesec` iz `3c` (task 69).
enum KalendarPrikaz { dan, sedmica }

/// Izabrani prikaz. **Dan je podrazumijevani i na telefonu i na računaru**: telefon ga
/// traži po DoD-u taska 69, a računar ga zadržava jer je to prikaz na koji je salon navikao.
///
/// Stoji u provideru, ne u `State` ekrana, iz istog razloga kao [izabraniRadnikProvider]:
/// izbor preživi rotaciju i prelaz preko breakpointa.
final kalendarPrikazProvider =
    NotifierProvider<KalendarPrikazNotifier, KalendarPrikaz>(
      KalendarPrikazNotifier.new,
    );

class KalendarPrikazNotifier extends Notifier<KalendarPrikaz> {
  @override
  KalendarPrikaz build() => KalendarPrikaz.dan;

  void postavi(KalendarPrikaz prikaz) => state = prikaz;
}

/// Termini sedmice u kojoj je izabrani dan.
///
/// **Ključ je ponedjeljak, ne izabrani dan.** Provider gleda `select` na početak sedmice,
/// pa prelaz sa srijede na četvrtak u istoj sedmici ne pravi novi upit.
///
/// Filtrira se samo radnik **iz uloge** (`adminRadnikIdProvider`), kao u danu — tuđe
/// termine radniku ionako ne vraća politika. Izbor vlasnika („Emir") filtrira Dart u
/// [kalendarSedmicaProvider], da klik na čip ne čeka mrežu.
final kalendarTerminiSedmiceProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return const [];

      final pocetak = ref.watch(kalendarDatumProvider.select(pocetakSedmice));
      return ref
          .watch(staffAppointmentRepositoryProvider)
          .forRange(
            salonId: salonId,
            from: pocetak,
            to: DateTime(pocetak.year, pocetak.month, pocetak.day + 6),
            employeeId: ref.watch(adminRadnikIdProvider),
          );
    });

/// Blokade sedmice u kojoj je izabrani dan. Ključ je ponedjeljak, kao kod termina.
final kalendarBlokadeSedmiceProvider =
    FutureProvider.autoDispose<List<BlockedSlot>>((ref) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return const [];

      final pocetak = ref.watch(kalendarDatumProvider.select(pocetakSedmice));
      return ref
          .watch(blockedSlotRepositoryProvider)
          .forRange(
            salonId: salonId,
            from: pocetak,
            to: DateTime(pocetak.year, pocetak.month, pocetak.day + 6),
          );
    });

/// Sastavljena sedmica — ono što sedmični prikaz crta.
///
/// Čeka sva tri čitanja zajedno, iz istog razloga kao [kalendarDanProvider]: sedmica
/// sastavljena prije radnog vremena nacrtala bi svaki dan kao neradni.
///
/// **Radnik iz uloge pobjeđuje izbor iz čipova.** Radnik ne vidi čipove, ali
/// [izabraniRadnikProvider] preživi odjavu vlasnika na istom uređaju; bez ovog pravila bi
/// radnik dobio kolonu filtriranu po kolegi — praznu, jer tuđe termine ne vidi.
final kalendarSedmicaProvider = FutureProvider.autoDispose<KalendarSedmica>((
  ref,
) async {
  final dan = ref.watch(kalendarDatumProvider);

  final (termini, radnoVrijeme, blokade) = await (
    ref.watch(kalendarTerminiSedmiceProvider.future),
    ref.watch(kalendarRadnoVrijemeProvider.future),
    ref.watch(kalendarBlokadeSedmiceProvider.future),
  ).wait;

  return izgradiSedmicu(
    dan: dan,
    termini: termini,
    radnoVrijeme: radnoVrijeme,
    blokade: blokade,
    radnikId:
        ref.watch(adminRadnikIdProvider) ?? ref.watch(izabraniRadnikProvider),
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
    ..invalidate(kalendarTerminiSedmiceProvider)
    ..invalidate(kalendarBlokadeSedmiceProvider)
    ..invalidate(kalendarRadnoVrijemeProvider)
    ..invalidate(adminEmployeesProvider)
    ..invalidate(adminServicesProvider);
}
