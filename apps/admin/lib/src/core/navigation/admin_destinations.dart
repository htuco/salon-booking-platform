/// Navigacijski model admina — **jedna lista koju čitaju obje ljuske**.
///
/// Sidebar na 1440 i donja navigacija na 402 nisu dva stabla ekrana nego dva pogleda na
/// ovu listu. Da svaka ljuska nosi svoju, dodavanje modula bi tražilo dvije izmjene, a
/// zaboravljena druga se ne vidi na širini na kojoj se radi.
///
/// ## Odakle redoslijed i sastav
///
/// Izmjereno iz `prototype/admin/canvas/Salon OS Admin.dc.html`, ne prepisano iz `SPEC.md`:
///
/// - **Sidebar (`3b`) nosi osam stavki** — Danas, Kalendar, Zahtjevi, Klijenti, Usluge,
///   Osoblje, Radno vrijeme, Postavke.
/// - **Donja navigacija (`3k`, `3t`) nosi četiri** — Danas, Kalendar, Zahtjevi, Još.
///
/// Odatle podjela: **prve tri su [primarne] i idu u donju navigaciju, ostalih pet stoje iza
/// „Još" (`3t`)**. „Još" nije zasebna lista nego rep iste — [sporedne].
///
/// ## Šta namjerno nije ovdje
///
/// Sidebar u canvasu iznad navigacije crta „6 lokacija", birač lokacije `▾` i „‹ Nazad na
/// mrežu". To je prikaz `3a`, koji `SPEC.md` izričito ostavlja izvan sprinta: traži
/// multi-location RBAC, a crtež nije dozvola za client-side izbor salona
/// ([ADR-0003](../../../../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
/// Salon i dalje dolazi iz membershipa.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appointments/appointments_providers.dart';
import '../router/admin_router.dart';

/// Jedna stavka navigacije, ista za sidebar i za donju navigaciju.
@immutable
class AdminDestination {
  const AdminDestination({
    required this.route,
    required this.label,
    required this.icon,
    this.lokacija,
    this.brojac,
  });

  /// Ruta koju stavka predstavlja. Po njoj se bira **označena** stavka, poređenjem sa
  /// `aktivna` koju ekran prosljeđuje ljusci.
  final AdminRoute route;

  /// Labela iz canvasa, doslovno.
  final String label;

  final IconData icon;

  /// Odredište kad nije `route.path`.
  ///
  /// Postoji zbog **jedne** stavke: „Zahtjevi" vodi na `/appointments?status=pending`.
  /// Handoff nema ćeliju „Termini", a zasebna ruta za zahtjeve bi punu listu ostavila bez
  /// ijednog ulaza iz navigacije; ovako je to ista ruta, a filter traka na ekranu vraća na
  /// „sve".
  final String? lokacija;

  /// Brojač uz labelu, kad ga canvas crta.
  ///
  /// Dio je **ljuske**, ne ekrana: pilula sa `4` stoji i u sidebaru i u donjoj navigaciji,
  /// prije nego što se ijedan ekran otvori.
  final ProviderListenable<AsyncValue<int>>? brojac;

  /// Gdje stavka stvarno vodi.
  String get putanja => lokacija ?? route.path;
}

/// Puna navigacija — tačno osam stavki sidebara iz `3b`, tim redom.
///
/// `final`, a ne `const`, jer „Zahtjevi" nose [pendingCountProvider]: Riverpod provider
/// nije konstanta.
final List<AdminDestination> kAdminDestinations = [
  AdminDestination(
    route: AdminRoute.dashboard,
    label: 'Danas',
    icon: Icons.home_outlined,
  ),
  AdminDestination(
    route: AdminRoute.calendar,
    label: 'Kalendar',
    icon: Icons.calendar_today_outlined,
  ),
  AdminDestination(
    route: AdminRoute.appointments,
    label: 'Zahtjevi',
    icon: Icons.chat_bubble_outline,
    lokacija: kZahtjeviPutanja,
    brojac: pendingCountProvider,
  ),
  AdminDestination(
    route: AdminRoute.clients,
    label: 'Klijenti',
    icon: Icons.people_outline,
  ),
  AdminDestination(
    route: AdminRoute.services,
    label: 'Usluge',
    icon: Icons.content_cut_outlined,
  ),
  AdminDestination(
    route: AdminRoute.employees,
    label: 'Osoblje',
    icon: Icons.badge_outlined,
  ),
  AdminDestination(
    route: AdminRoute.workingHours,
    label: 'Radno vrijeme',
    icon: Icons.schedule_outlined,
  ),
  AdminDestination(
    route: AdminRoute.settings,
    label: 'Postavke',
    icon: Icons.settings_outlined,
  ),
];

/// Adresa „Zahtjeva" — filtrirana lista termina, ne zasebna ruta.
///
/// Stoji kao imenovana konstanta jer je troše tri mjesta: navigacija, kartica zahtjeva na
/// dashboardu i test. Sastavljena iz `AdminRoute.appointments.path` i
/// [AppointmentStatus.wireName], da promjena rute ili imena statusa ne ostavi ovdje
/// otkucan string koji i dalje kompajlira.
final String kZahtjeviPutanja =
    '${AdminRoute.appointments.path}'
    '?$kStatusUpit=${AppointmentStatus.pending.wireName}';

/// Koliko stavki sa vrha liste ide u donju navigaciju telefona.
///
/// Tri, pa četvrta ćelija bude „Još" — canvas `3k` i `3t`.
const int kAdminPrimarneCelije = 3;

/// Stavke koje telefon nosi kao ćelije.
List<AdminDestination> get adminPrimarne =>
    kAdminDestinations.take(kAdminPrimarneCelije).toList(growable: false);

/// Stavke koje telefon skriva iza „Još" — rep iste liste, ne druga lista.
List<AdminDestination> get adminSporedne =>
    kAdminDestinations.skip(kAdminPrimarneCelije).toList(growable: false);

/// Četvrta ćelija telefona. Nije modul nego ulaz u [adminSporedne].
const AdminDestination kAdminJos = AdminDestination(
  route: AdminRoute.more,
  label: 'Još',
  icon: Icons.more_horiz,
);
