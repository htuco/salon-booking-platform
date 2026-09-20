/// Statusna pilula — ista oznaka na dashboardu, u listi i u detalju termina.
///
/// **Boja nije jedini nosilac informacije** — uz nju uvijek ide tekst. Vlasnik koji ne
/// razlikuje zelenu od narandžaste mora moći pročitati status (WCAG 1.4.1; `SPEC.md`:
/// „Statusi moraju imati tekstualnu oznaku").
///
/// Stoji u svom fajlu od taska 30, jer je ista oznaka zatrebala na tri ekrana. Kopija po
/// ekranu bi značila tri mjesta na kojima se mijenja ton kad se doda status.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'appointments_providers.dart';

class AppointmentStatusPill extends StatelessWidget {
  const AppointmentStatusPill({
    required this.status,
    this.uToku = false,
    super.key,
  });

  final AppointmentStatus status;

  /// Termin koji **upravo traje** — puna akcentna pilula sa „U toku" (`3b`, `3k`).
  ///
  /// Nije status iz baze nego stanje sata: `confirmed` termin čije je vrijeme počelo a nije
  /// prošlo. U bazi mu se ništa ne mijenja, pa se ne dodaje u `AppointmentStatus` — enum
  /// opisuje red, a ovo opisuje trenutak u kojem se red gleda.
  final bool uToku;

  @override
  Widget build(BuildContext context) {
    final statusi = context.statusColors;

    if (uToku) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: context.adminColors.accent,
          borderRadius: BorderRadius.circular(AdminRadius.pill),
        ),
        child: Text(
          kOznakaUToku,
          style: AdminText.statusLabel.copyWith(
            color: context.adminColors.onAccent,
          ),
        ),
      );
    }

    // Parovi dolaze iz teme, ne iz `ColorScheme`-a. Ranija verzija je uzimala
    // `primaryContainer` za potvrđen termin, pa je „potvrđeno" bilo plavo — handoff ga
    // crta zeleno, a plava je u ovom sistemu akcent, ne status.
    //
    // Mapa stoji uz `statusOznaka`, ne ovdje: kalendar crta iste tonove u bloku i u
    // legendi, a dvije kopije `switch`-a se raziđu prvi put kad se doda status.
    final ton = statusTon(statusi, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: ton.background,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(
        // Jednina uz jedan termin („Potvrđeno"), za razliku od `statusLabela`, koja
        // imenuje grupu redova u filteru („Potvrđeni").
        statusOznaka(status),
        style: AdminText.statusLabel.copyWith(color: ton.foreground),
      ),
    );
  }
}
