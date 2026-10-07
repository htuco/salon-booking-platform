/// Provideri Danas ekrana.
///
/// **Ništa ovdje nema svoj upit nad terminima dana.** Ekran čita iste repozitorije kao lista
/// termina i kalendar (`danasnjiTerminiProvider`, `zahtjeviProvider`), pa „16 termina" ovdje
/// i 16 redova na listi ne mogu raziću. Dva nova upita postoje jer ih nijedan drugi ekran ne
/// postavlja: broj termina ove sedmice i sljedeći radni dan (`6h`).
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../appointments/appointments_providers.dart';
import '../appointments/odgodjene_akcije.dart';
import '../calendar/calendar_day.dart';
import 'danas.dart';
import 'dashboard_summary.dart';

export '../../core/sat.dart';

/// Današnji termini kako ih ekran pokazuje — sa akcijom koja čeka „Poništi".
final danasPrikazProvider = Provider<AsyncValue<List<Appointment>>>((ref) {
  final odgodjene = ref.watch(odgodjeneAkcijeProvider);
  return ref
      .watch(danasnjiTerminiProvider)
      .whenData((lista) => primijeniOdgodjene(lista, odgodjene));
});

/// Zahtjevi koji i dalje čekaju, po vremenu termina.
///
/// Zahtjev potvrđen prije 2 s nije više zahtjev, iako ga baza još ne zna kao potvrđen.
final zahtjeviPrikazProvider = Provider<AsyncValue<List<Appointment>>>((ref) {
  final odgodjene = ref.watch(odgodjeneAkcijeProvider);
  return ref
      .watch(zahtjeviProvider)
      .whenData(
        (lista) => zahtjeviPoTerminu([
          for (final zahtjev in lista)
            if (!odgodjene.containsKey(zahtjev.id)) zahtjev,
        ]),
      );
});

/// Raspored salona — salonski redovi i oni po radniku, jedno čitanje.
///
/// Zaseban od `kalendarRadnoVrijemeProvider`: onaj je `autoDispose` uz kalendar, a
/// dashboard ne smije zavisiti od toga da li je kalendar otvoren.
final dashboardRasporedProvider = FutureProvider<List<WorkingHour>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(workingHoursRepositoryProvider).forSalon(salonId);
});

/// Današnje blokade — u rasporedu su red, u rupama zauzeto.
///
/// Radnik vidi salonske i svoje (`employee_blocks`), vlasnik sve.
final dashboardBlokadeProvider = FutureProvider<List<BlockedSlot>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref
      .watch(blockedSlotRepositoryProvider)
      .forDay(salonId: salonId, day: DateTime.now());
});

/// Ko je danas u smjeni. Prazno dok raspored ili radnici ne stignu.
final dashboardSmjeneProvider = Provider<List<SmjenaDana>>((ref) {
  final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
  final radnici = ref.watch(radniciPoIdProvider);
  if (raspored == null || radnici.isEmpty) return const [];
  // Radniku se računa samo njegova smjena (task 47): tuđe smjene bez tuđih termina bi
  // rupe i zauzetost napunile kolegama koji izgledaju besposleni.
  final radnikId = ref.watch(adminRadnikIdProvider);
  final kljucevi = radnikId == null
      ? radnici.keys
      : radnici.keys.where((id) => id == radnikId);
  return smjeneDana(raspored, kljucevi, DateTime.now().weekday);
});

/// Termini ove sedmice (ponedjeljak–nedjelja) koji drže slot — „Ova sedmica".
final sedmicaProvider = FutureProvider<int>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return 0;
  final danas = DateTime.now();
  final ponedjeljak = DateTime(
    danas.year,
    danas.month,
    danas.day - (danas.weekday - 1),
  );
  final termini = await ref
      .watch(staffAppointmentRepositoryProvider)
      .forRange(
        salonId: salonId,
        from: ponedjeljak,
        to: ponedjeljak.add(const Duration(days: 6)),
        employeeId: ref.watch(adminRadnikIdProvider),
      );
  return termini.where(terminSeRacuna).length;
});

/// Sljedeći radni dan i koliko termina čeka na njega — `6h`.
final sljedeciRadniDanProvider =
    FutureProvider<({DateTime dan, LocalTime otvara, int termina})?>((
      ref,
    ) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return null;
      final raspored = await ref.watch(dashboardRasporedProvider.future);
      final sljedeci = sljedeciRadniDan(raspored, DateTime.now());
      if (sljedeci == null) return null;
      final termini = await ref
          .watch(staffAppointmentRepositoryProvider)
          .forDay(
            salonId: salonId,
            day: sljedeci.dan,
            employeeId: ref.watch(adminRadnikIdProvider),
          );
      return (
        dan: sljedeci.dan,
        otvara: sljedeci.otvara,
        termina: termini.where(terminSeRacuna).length,
      );
    });

/// Termin izabran klikom na red — kontekstni panel `6b` ga pokazuje.
class IzabraniTerminNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void izaberi(String? appointmentId) => state = appointmentId;
}

final izabraniTerminProvider =
    NotifierProvider<IzabraniTerminNotifier, String?>(
      IzabraniTerminNotifier.new,
    );

/// Filter rasporeda po radniku — `null` je „Svi" (samo vlasnik ga ima).
class FilterRadnikaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void postavi(String? radnikId) => state = radnikId;
}

final filterRadnikaProvider = NotifierProvider<FilterRadnikaNotifier, String?>(
  FilterRadnikaNotifier.new,
);

/// Prikaz „Ostatak dana" na desktopu — lista (`6a`) ili mreža kalendara (`3c`).
enum PrikazDana { lista, kalendar }

class PrikazDanaNotifier extends Notifier<PrikazDana> {
  @override
  PrikazDana build() => PrikazDana.kalendar;

  void postavi(PrikazDana prikaz) => state = prikaz;
}

final prikazDanaProvider = NotifierProvider<PrikazDanaNotifier, PrikazDana>(
  PrikazDanaNotifier.new,
);

/// Današnji dan kao mreža kalendara — iz **istih** podataka kao lista.
///
/// Ne čita `kalendarDanProvider`: on prati dan izabran na ekranu Kalendar, pa bi vlasnik
/// koji je tamo otišao na sutra na Danas vidio sutrašnju mrežu. Uz to ovako mreža nosi i
/// akciju koja čeka „Poništi" — potvrđen zahtjev u njoj odmah gubi isprekidan rub.
/// `null` dok bilo koje od četiri čitanja ne stigne, iz istog razloga kao u kalendaru: dan
/// bez radnog vremena bi svaku kolonu nacrtao kao neradnu.
final danasKalendarProvider = Provider<KalendarDan?>((ref) {
  final termini = ref.watch(danasPrikazProvider).valueOrNull;
  final radnici = ref.watch(adminEmployeesProvider).valueOrNull;
  final raspored = ref.watch(dashboardRasporedProvider).valueOrNull;
  final blokade = ref.watch(dashboardBlokadeProvider).valueOrNull;
  if (termini == null ||
      radnici == null ||
      raspored == null ||
      blokade == null) {
    return null;
  }
  final radnikId = ref.watch(adminRadnikIdProvider);
  return izgradiDan(
    dan: DateTime.now(),
    radnici: [
      for (final r in radnici)
        if (r.isActive && (radnikId == null || r.id == radnikId)) r,
    ],
    termini: termini,
    radnoVrijeme: raspored,
    blokade: blokade,
  );
});
