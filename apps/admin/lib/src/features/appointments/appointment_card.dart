/// Termin kao kartica — mobilni oblik iz `3k` (raspored) i `3m` (zahtjevi).
///
/// Vrijeme je **prvo i mono**: vlasnik skenira raspored po satu, ne po imenu. Ime je drugo
/// i najkrupnije, a usluga, majstor i cijena stoje u jednom sivom redu ispod njega, kako ih
/// canvas i slaže — `Muško šišanje · Emir · 15 KM`.
///
/// Kartica **ne zna** odakle podaci: ime usluge i majstora joj se prosljeđuju, jer ih
/// `appointments` red nosi samo kao `id`. Da ih traži sama, svaka kartica u listi bi
/// pokrenula svoj upit.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/theme/theme.dart';
import 'status_pill.dart';

/// Podaci koje kartica ne može izvesti iz samog termina.
class TerminOpis {
  const TerminOpis({this.usluga, this.majstor, this.cijena});

  final String? usluga;
  final String? majstor;
  final double? cijena;

  /// `Muško šišanje · Emir · 15 KM`, bez praznih dijelova.
  ///
  /// Termin bez radnika je **predviđeno stanje** (`employee_id` je nullable — klijent je
  /// izabrao „bilo ko"), pa se prazan dio izostavlja umjesto da se crta razmak između dvije
  /// tačke.
  String get red => [
    if (usluga case final u? when u.isNotEmpty) u,
    if (majstor case final m? when m.isNotEmpty) m,
    if (cijena case final c?) iznosKm(c),
  ].join(' · ');
}

/// Da li termin **upravo traje**.
///
/// Samo potvrđen termin može biti u toku: zahtjev koji čeka nije počeo, jer salon još nije
/// rekao da hoće.
bool terminUToku(Appointment termin, DateTime sada) {
  if (termin.status != AppointmentStatus.confirmed) return false;
  if (termin.date.year != sada.year ||
      termin.date.month != sada.month ||
      termin.date.day != sada.day) {
    return false;
  }

  final minuta = sada.hour * 60 + sada.minute;
  return minuta >= termin.startTime.minutesFromMidnight &&
      minuta < termin.endTime.minutesFromMidnight;
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    required this.termin,
    this.opis = const TerminOpis(),
    this.uToku = false,
    this.datum,
    this.onTap,
    this.podnozje,
    super.key,
  });

  final Appointment termin;
  final TerminOpis opis;
  final bool uToku;

  /// Datum uz vrijeme, za listu koja nije jednodnevna (zahtjevi gledaju 60 dana unaprijed).
  final String? datum;

  final VoidCallback? onTap;

  /// Akcije ispod kartice — `3m` ih crta u samoj kartici zahtjeva.
  final Widget? podnozje;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otkazan =
        termin.status == AppointmentStatus.cancelled ||
        termin.status == AppointmentStatus.noShow;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        child: DecoratedBox(
          // Termin koji traje nosi akcentnu liniju uz lijevu ivicu (`3k`). Linija je uz
          // pilulu, ne umjesto nje — boja sama ne smije nositi značenje.
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: uToku
                    ? context.adminColors.accent
                    : context.adminColors.surface,
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // `Flexible`, ne goli `Text`: uz datum („sutra · 10:00") i dugu
                    // statusnu oznaku red je na 402 px izlazio 48 px van kartice.
                    Flexible(
                      child: Text(
                        datum == null
                            ? vrijemeHhMm(termin.startTime)
                            : '$datum · ${vrijemeHhMm(termin.startTime)}',
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.timeLarge.copyWith(
                          color: context.adminColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.sm),
                    AppointmentStatusPill(status: termin.status, uToku: uToku),
                  ],
                ),
                const SizedBox(height: AdminSpacing.sm),
                Text(
                  termin.customerName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    // Otkazan termin se **ne briše iz liste** nego se stišava: vlasnik mora
                    // vidjeti da je slot bio zauzet pa oslobođen.
                    decoration: otkazan ? TextDecoration.lineThrough : null,
                    color: otkazan ? context.adminColors.textMuted : null,
                  ),
                ),
                if (opis.red.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    opis.red,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ],
                // Napomena je jedini slobodan tekst koji klijent pošalje i često nosi ono
                // što vlasnik mora znati prije termina (alergija, dijete, kašnjenje).
                if (termin.customerNote case final napomena?
                    when napomena.isNotEmpty) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  Text(
                    napomena,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.adminColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (podnozje case final akcije?) ...[
                  const SizedBox(height: AdminSpacing.md),
                  akcije,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opis termina iz kataloga salona.
///
/// [saCijenom] je `false` tamo gdje cijena nije ono što se gleda — u kartici zahtjeva
/// vlasnik odlučuje o vremenu i majstoru, a iznos uz odluku „potvrdi/odbij" izgleda kao da
/// je novac kriterij.
TerminOpis opisTermina(
  Appointment termin, {
  required Map<String, Service> usluge,
  required Map<String, Employee> radnici,
  bool saCijenom = true,
}) {
  final usluga = usluge[termin.serviceId];
  final radnik = termin.employeeId == null ? null : radnici[termin.employeeId];

  return TerminOpis(
    usluga: termin.serviceName ?? usluga?.name,
    majstor: termin.employeeName ?? radnik?.name,
    cijena: saCijenom ? (termin.servicePrice ?? usluga?.price) : null,
  );
}
