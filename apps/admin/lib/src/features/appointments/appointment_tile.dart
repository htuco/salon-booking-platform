import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'appointments_providers.dart';

/// Jedan termin u admin listi.
///
/// Vrijeme je **prvo i najkrupnije**: vlasnik skenira listu po satu, ne po imenu. Ime je
/// drugo, status treće — obrnut redoslijed od klijentske liste, gdje korisnik ima jedan
/// termin i zanima ga šta je, ne kada je u odnosu na ostale.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({required this.termin, super.key});

  final Appointment termin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otkazan = termin.status == AppointmentStatus.cancelled;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Vrijeme stoji u `leading`, ali kao **jedan red**, ne kao kolona od dva: `ListTile`
      // namece `leading` widgetu visinu reda, pa se druga linija prelijeva cim se poveca
      // tekstualna skala. Raspon `10:00–10:40` u jednom redu nosi istu informaciju i ne
      // ovisi o visini koju ne kontrolisemo.
      leading: SizedBox(
        width: 56,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _vrijeme(termin.startTime),
            // Vrijeme je **JetBrains Mono** — `SPEC.md` mu daje sate, datume i brojcani
            // podatak. Tabularne cifre nosi `AdminText.time` sam, pa se ovdje ne
            // ponavljaju.
            style: AdminText.time.copyWith(
              // Otkazan termin se **ne brise iz liste** nego se stisava: vlasnik mora
              // vidjeti da je slot bio zauzet pa oslobodjen.
              color: otkazan ? AdminColors.textMuted : AdminColors.ink,
            ),
          ),
        ),
      ),
      title: Text(
        termin.customerName,
        style: theme.textTheme.titleMedium?.copyWith(
          decoration: otkazan ? TextDecoration.lineThrough : null,
          color: otkazan ? AdminColors.textMuted : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            'do ${_vrijeme(termin.endTime)}',
            style: AdminText.dataInline.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (termin.customerPhone case final telefon?
              when telefon.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(telefon, style: theme.textTheme.bodySmall),
          ],
          // Napomena je jedini slobodan tekst koji klijent posalje i cesto nosi ono sto
          // vlasnik mora znati prije termina (alergija, dijete, kasnjenje).
          if (termin.customerNote case final napomena?
              when napomena.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    napomena,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: _StatusZnak(status: termin.status),
    );
  }

  /// `HH:MM` iz `LocalTime`, bez sekundi — sekunde u rasporedu ne znače ništa.
  static String _vrijeme(LocalTime vrijeme) =>
      '${vrijeme.hour.toString().padLeft(2, '0')}:'
      '${vrijeme.minute.toString().padLeft(2, '0')}';
}

/// Status kao obojena oznaka.
///
/// **Boja nije jedini nosilac informacije** — uz nju uvijek ide tekst. Vlasnik koji ne
/// razlikuje zelenu od narandžaste mora moći pročitati status (WCAG 1.4.1).
class _StatusZnak extends StatelessWidget {
  const _StatusZnak({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final statusi = context.statusColors;

    // Parovi dolaze iz teme, ne iz `ColorScheme`-a. Ranija verzija je uzimala
    // `primaryContainer` za potvrdjen termin, pa je „potvrdjeno" bilo plavo — handoff ga
    // crta zeleno, a plava je u ovom sistemu akcent, ne status.
    final ton = switch (status) {
      AppointmentStatus.pending => statusi.waiting,
      AppointmentStatus.confirmed => statusi.positive,
      AppointmentStatus.cancelled => statusi.negative,
      AppointmentStatus.completed => statusi.neutral,
      // „Nije se pojavio" nije otkazivanje: otkazao je neko, ovo se prosto desilo.
      AppointmentStatus.noShow => statusi.negativeQuiet,
      AppointmentStatus.unknown => statusi.neutral,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: ton.background,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(
        // Tekst je obavezan, ne dodatak uz boju (`SPEC.md`; WCAG 1.4.1).
        //
        // Labela je i dalje `statusLabela` — canvas pise „Potvrdjeno", a ovdje stoji
        // „Potvrdjeni", jer isti string sluzi i kao labela filtera. To je promjena copyja
        // i pripada tasku 30, ne ovom.
        statusLabela(status),
        style: AdminText.statusLabel.copyWith(color: ton.foreground),
      ),
    );
  }
}
