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

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    icon: LucideIcons.house300,
  ),
  AdminDestination(
    route: AdminRoute.calendar,
    label: 'Kalendar',
    icon: LucideIcons.calendar300,
  ),
  AdminDestination(
    route: AdminRoute.requests,
    label: 'Zahtjevi',
    icon: LucideIcons.messageSquare300,
    brojac: pendingCountProvider,
  ),
  AdminDestination(
    route: AdminRoute.clients,
    label: 'Klijenti',
    icon: LucideIcons.users300,
  ),
  AdminDestination(
    route: AdminRoute.services,
    label: 'Usluge',
    icon: LucideIcons.scissors300,
  ),
  AdminDestination(
    route: AdminRoute.employees,
    label: 'Osoblje',
    icon: LucideIcons.idCard300,
  ),
  AdminDestination(
    route: AdminRoute.workingHours,
    label: 'Radno vrijeme',
    icon: LucideIcons.clock300,
  ),
  AdminDestination(
    route: AdminRoute.settings,
    label: 'Postavke',
    icon: LucideIcons.settings300,
  ),
];

/// Adresa „Zahtjeva" — korijen istoimene grane.
///
/// Stoji kao imenovana konstanta jer je troše navigacija, kartica zahtjeva na Danas i
/// test. Stara adresa (`/appointments?status=pending`) se preusmjerava ovamo.
final String kZahtjeviPutanja = AdminRoute.requests.path;

/// Stavka sidebara za trenutnu putanju — sidebar ima osam stavki na četiri grane.
///
/// Najduži prefiks pobjeđuje, pa `/more/clients/...` označi Klijente, a ne Još. „Svi
/// termini" (`/more/appointments`) nemaju svoju stavku i označe Zahtjeve, kao i prije
/// grana. Profil je u podnožju sidebara, ne u listi.
AdminRoute? rutaSidebara(String putanja) {
  bool ispod(AdminRoute r) =>
      putanja == r.path || putanja.startsWith('${r.path}/');
  if (ispod(AdminRoute.profile)) return AdminRoute.profile;
  if (ispod(AdminRoute.appointments)) return AdminRoute.requests;
  AdminRoute? najbolja;
  for (final cilj in kAdminDestinations) {
    if (!ispod(cilj.route)) continue;
    if (najbolja == null || cilj.route.path.length > najbolja.path.length) {
      najbolja = cilj.route;
    }
  }
  return najbolja;
}

/// Koliko stavki sa vrha liste ide u donju navigaciju telefona.
///
/// Tri, pa četvrta ćelija bude „Još" — canvas `3k` i `3t`.
const int kAdminPrimarneCelije = 3;

/// Navigacija za ulogu prijavljenog — [kAdminDestinations], za radnika filtrirana (task 47).
///
/// **Filter, ne druga lista.** Radnik dobija podskup iste liste po `kRuteRadnika`, istim
/// redom, pa sidebar, donja navigacija i „Još" ostaju tri pogleda na jedno. Ćelija koja
/// vodi u zabranu je gora od ćelije koje nema — zato modul ispada, a ne ostaje zaključan.
List<AdminDestination> adminDestinationsZa(StaffMember? clan) =>
    clan != null && clan.isEmployee
    ? kAdminDestinations
          .where((c) => kRuteRadnika.contains(c.route))
          .toList(growable: false)
    : kAdminDestinations;

/// [adminDestinationsZa] prijavljenog člana — ono što ljuske crtaju.
final adminNavigacijaProvider = Provider<List<AdminDestination>>(
  (ref) => adminDestinationsZa(ref.watch(currentStaffProvider).valueOrNull),
);

/// Stavke koje telefon nosi kao ćelije.
List<AdminDestination> adminPrimarne(List<AdminDestination> navigacija) =>
    navigacija.take(kAdminPrimarneCelije).toList(growable: false);

/// Stavke koje telefon skriva iza „Još" — rep iste liste, ne druga lista.
List<AdminDestination> adminSporedne(List<AdminDestination> navigacija) =>
    navigacija.skip(kAdminPrimarneCelije).toList(growable: false);

/// Četvrta ćelija telefona. Nije modul nego ulaz u [adminSporedne].
const AdminDestination kAdminJos = AdminDestination(
  route: AdminRoute.more,
  label: 'Još',
  icon: LucideIcons.ellipsis300,
);
