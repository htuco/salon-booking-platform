import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';

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
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              // Otkazan termin se **ne brise iz liste** nego se stisava: vlasnik mora
              // vidjeti da je slot bio zauzet pa oslobodjen.
              color: otkazan ? theme.disabledColor : null,
            ),
          ),
        ),
      ),
      title: Text(
        termin.customerName,
        style: theme.textTheme.titleMedium?.copyWith(
          decoration: otkazan ? TextDecoration.lineThrough : null,
          color: otkazan ? theme.disabledColor : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            'do ${_vrijeme(termin.endTime)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (pozadina, tekst) = switch (status) {
      AppointmentStatus.pending => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AppointmentStatus.confirmed => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AppointmentStatus.cancelled => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      AppointmentStatus.completed => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      AppointmentStatus.noShow => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      AppointmentStatus.unknown => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pozadina,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusLabela(status),
        style: theme.textTheme.labelSmall?.copyWith(color: tekst),
      ),
    );
  }
}
