/// Pisanje radnog vremena koje dijele ekran „Radno vrijeme" i kalendar.
///
/// „Dodaj pauzu" postoji na dva mjesta, i oba moraju raditi istu stvar: isti dijalog, ista
/// provjera, isti upit o konfliktima i isti upis. Zato je ovo izvučeno iz ekrana, umjesto
/// da kalendar ponavlja pravila koja bi se razišla pri prvoj izmjeni.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/poruka_greske.dart';
import '../../core/widgets/admin_toast.dart';
import 'working_hours_dialogs.dart';
import 'working_hours_providers.dart';

/// Pauza je kolona dana: dani iz nove grupe dobijaju vrijeme, dani koji su ispali iz
/// stare ga gube.
List<WorkingHoursInput> primijeniPauzu(
  List<WorkingHoursInput> dani,
  Set<int> stariDani,
  IzmjenaPauze izmjena,
) => [
  for (final dan in dani)
    if (!izmjena.ukloni && izmjena.dani.contains(dan.dayOfWeek))
      dan.copyWith(breakStartTime: izmjena.od, breakEndTime: izmjena.do_)
    else if (stariDani.contains(dan.dayOfWeek))
      dan.copyWith(clearBreak: true)
    else
      dan,
];

/// Ono malo što ekran smije izračunati sam: staje li pauza u smjenu.
///
/// Ovo **nije** availability logika — to ostaje u bazi. Ovdje je samo da greška stigne
/// kao rečenica uz dan koji je kriv, umjesto kao sirovi `PT400` iz backenda. Baza istu
/// provjeru ponavlja i ostaje jedina koja obavezuje.
String? provjeriSedmicu(List<WorkingHoursInput> dani) {
  for (final dan in dani) {
    if (dan.isClosed) continue;
    final ime = kDaniSedmice[dan.dayOfWeek - 1];
    if (dan.endTime <= dan.startTime) {
      return '$ime: kraj radnog vremena mora biti poslije početka.';
    }
    if (dan.hasBreak &&
        (dan.breakStartTime! < dan.startTime ||
            dan.breakEndTime! > dan.endTime ||
            dan.breakEndTime! <= dan.breakStartTime!)) {
      return '$ime: pauza mora biti unutar radnog vremena.';
    }
  }
  return null;
}

/// Snima sedmicu tek kad vlasnik vidi šta ispada van novog vremena.
///
/// Redoslijed je namjeran: prvo pitanje bazi šta bi ispalo, pa dijalog, pa upis. Obrnut
/// redoslijed bi značio da vlasnik saznaje za posljedicu kad je već nastala.
///
/// Vraća `false` kad je vlasnik odustao u dijalogu konflikata; `ApiError` propušta.
Future<bool> snimiSedmicu(
  BuildContext context,
  WorkingHoursActions actions,
  List<WorkingHoursInput> dani,
) async {
  final konflikti = await actions.konflikti(dani);
  if (!context.mounted) return false;
  if (konflikti.isNotEmpty) {
    final nastavi = await prikaziKonflikte(context, konflikti);
    if (nastavi != true || !context.mounted) return false;
  }
  await actions.sacuvaj(dani);
  return true;
}

/// „Dodaj pauzu" iz kalendara — isti dijalog i isto snimanje kao na ekranu radnog vremena,
/// samo što se ovdje snima odmah, jer kalendar nema „Sačuvaj izmjene".
Future<void> dodajPauzuIzKalendara(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(workingHoursActionsProvider);
  try {
    final sedmica = weekFromWorkingHours(
      await ref.read(radnoVrijemeProvider.future),
    );
    if (!context.mounted) return;
    final izmjena = await prikaziUrediPauzu(
      context,
      sedmica: sedmica,
      snimaOdmah: true,
    );
    if (izmjena == null || !context.mounted) return;

    final nova = primijeniPauzu(sedmica, const {}, izmjena);
    final problem = provjeriSedmicu(nova);
    if (problem != null) {
      AdminToast.upozorenje(context, problem);
      return;
    }
    if (await snimiSedmicu(context, actions, nova) && context.mounted) {
      AdminToast.uspjeh(context, 'Pauza je sačuvana.');
    }
  } on ApiError catch (error) {
    if (context.mounted) AdminToast.greska(context, porukaGreske(error));
  } catch (_) {
    if (context.mounted) {
      AdminToast.greska(context, 'Pauza se ne može sačuvati.');
    }
  }
}
