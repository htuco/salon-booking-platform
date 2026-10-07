/// Akcije koje se mogu poništiti — potvrda, „Završeno" i „Nije došao" sa Danas ekrana.
///
/// ## Zašto se upis odgađa, a ne poništava
///
/// Handoff `6m` traži toast „Poništi" od 5 s. Postoje dva načina da se to napravi, i samo
/// jedan ne traži migraciju:
///
/// - **Upis odmah, pa vraćanje.** `set_appointment_status` ne prima `pending`, pa se potvrda
///   ne može vratiti na čekanje. Vraćanje `completed`/`no_show` na `confirmed` prolazi, ali
///   `visit_count` i `no_show_count` su već uvećani i niko ih ne umanjuje — statistika
///   klijenta bi lagala poslije svakog „Poništi".
/// - **Upis tek kad rok istekne.** Ekran odmah pokazuje novo stanje, a RPC ide za 5 s.
///   „Poništi" samo otkaže tajmer, pa baza i push nikad ne vide akciju.
///
/// Ovdje je drugi. Njegova slabost je prozor od 5 s u kojem akcija postoji samo u memoriji,
/// pa se sve što čeka **upisuje odmah** kad aplikacija ode u pozadinu ili se zatvara.
/// Notifier nije `autoDispose`: izlazak sa Danas ekrana ne smije baciti potvrdu.
library;

import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointments_providers.dart';

/// Koliko dugo „Poništi" važi — isto koliko uspješan toast stoji na ekranu.
const Duration kRokPonistavanja = Duration(seconds: 5);

/// Šta se sa terminom desi kad rok istekne.
enum OdgodjenaVrsta {
  potvrda(AppointmentStatus.confirmed),
  zavrseno(AppointmentStatus.completed),
  nijeDosao(AppointmentStatus.noShow);

  const OdgodjenaVrsta(this.status);

  /// Status koji ekran pokazuje dok akcija čeka.
  final AppointmentStatus status;
}

/// Jedna akcija koja čeka svoj rok.
@immutable
class OdgodjenaAkcija {
  const OdgodjenaAkcija({required this.termin, required this.vrsta});

  final Appointment termin;
  final OdgodjenaVrsta vrsta;
}

/// `appointmentId → akcija koja čeka`.
///
/// Ekran čita stanje da bi termin odmah pokazao kao potvrđen ili završen
/// ([primijeniOdgodjene]); baza ga vidi tek kad rok istekne.
class OdgodjeneAkcijeNotifier extends Notifier<Map<String, OdgodjenaAkcija>>
    with WidgetsBindingObserver {
  final Map<String, Timer> _tajmeri = {};
  final Map<String, void Function(ApiError)> _naGresku = {};

  @override
  Map<String, OdgodjenaAkcija> build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      izvrsiSve();
    });
    return const {};
  }

  /// Zakaže akciju; ponovno zakazivanje istog termina zamjenjuje prethodno.
  ///
  /// [naGresku] se zove kad RPC padne poslije roka — ekran tada više ne prikazuje red, pa
  /// bez poruke vlasnik ne bi znao da potvrda nije prošla.
  void zakazi(
    Appointment termin,
    OdgodjenaVrsta vrsta, {
    void Function(ApiError)? naGresku,
  }) {
    _tajmeri.remove(termin.id)?.cancel();
    if (naGresku != null) _naGresku[termin.id] = naGresku;
    state = {
      ...state,
      termin.id: OdgodjenaAkcija(termin: termin, vrsta: vrsta),
    };
    _tajmeri[termin.id] = Timer(kRokPonistavanja, () => _izvrsi(termin.id));
  }

  /// `false` kad je akcija već upisana — „Poništi" je stigao kasno.
  bool ponisti(String appointmentId) {
    final tajmer = _tajmeri.remove(appointmentId);
    if (tajmer == null) return false;
    tajmer.cancel();
    _naGresku.remove(appointmentId);
    state = {...state}..remove(appointmentId);
    return true;
  }

  /// Upiše sve što čeka, bez čekanja roka.
  void izvrsiSve() {
    for (final id in _tajmeri.keys.toList()) {
      _tajmeri.remove(id)?.cancel();
      unawaited(_izvrsi(id));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `hidden` je web tab u pozadini i desktop prozor koji se minimizira — tab zatvoren
    // poslije toga nikad ne dobije `detached`.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      izvrsiSve();
    }
  }

  Future<void> _izvrsi(String appointmentId) async {
    _tajmeri.remove(appointmentId);
    final akcija = state[appointmentId];
    if (akcija == null) return;
    final naGresku = _naGresku.remove(appointmentId);
    final akcije = ref.read(appointmentActionsProvider);

    try {
      await switch (akcija.vrsta) {
        OdgodjenaVrsta.potvrda => akcije.potvrdi(appointmentId),
        OdgodjenaVrsta.zavrseno => akcije.zavrsen(appointmentId),
        OdgodjenaVrsta.nijeDosao => akcije.nijeDosao(appointmentId),
      };
      // Prepis se skida tek kad liste stignu iz baze. Skinut odmah, red bi na trenutak
      // ponovo stajao kao zahtjev — stara lista ostaje dok se nova čita.
      await Future.wait<Object?>([
        ref.read(danasnjiTerminiProvider.future),
        ref.read(zahtjeviProvider.future),
      ]).catchError((_) => const <Object?>[]);
    } on ApiError catch (greska) {
      naGresku?.call(greska);
    } finally {
      if (state.containsKey(appointmentId)) {
        state = {...state}..remove(appointmentId);
      }
    }
  }
}

final odgodjeneAkcijeProvider =
    NotifierProvider<OdgodjeneAkcijeNotifier, Map<String, OdgodjenaAkcija>>(
      OdgodjeneAkcijeNotifier.new,
    );

/// Lista termina kako je ekran treba pokazati: sa statusom akcije koja čeka.
List<Appointment> primijeniOdgodjene(
  List<Appointment> termini,
  Map<String, OdgodjenaAkcija> odgodjene,
) {
  if (odgodjene.isEmpty) return termini;
  return [
    for (final termin in termini)
      if (odgodjene[termin.id] case final akcija?)
        termin.copyWith(status: akcija.vrsta.status)
      else
        termin,
  ];
}
