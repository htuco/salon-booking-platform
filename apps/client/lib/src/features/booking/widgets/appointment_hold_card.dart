import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters.dart';
import '../../../core/vertical_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../booking_flow_provider.dart';
import '../date_labels.dart';
import '../../../core/prikaz_cijena.dart';

/// „Čuvamo vam — 14:30, srijeda 20.05. — Fade šišanje kod Emira".
///
/// Vrijeme je najveći element na ekranu i stoji u serifu: to je jedini podatak zbog kojeg
/// korisnik na zadnjem koraku zastane prije nego što se prijavi
/// (`prototype/ui/screenshots/06-korak4-prijava.png`).
///
/// ## Zašto je izvučena iz `details_step_screen.dart`
///
/// Prijava (`/auth/login`) je **dio istog koraka** — handoff nema zaseban login ekran —
/// pa kartica mora stajati i tamo. Uz to nosi posljedicu koja nije kozmetička: ona je
/// jedini slušalac `bookingFlowProvider`-a na login ekranu, a taj provider je
/// `autoDispose`. Bez nje bi odlazak na prijavu obrisao izbor i korisnik bi se vratio na
/// prazan sažetak — zamka koju task 13 imenuje. Dokazuje se u `login_screen_test.dart`.
///
/// Čita stanje sama, umjesto da ga prima kao parametar, upravo zbog toga: pozivalac koji
/// bi joj proslijedio `BookingFlowState` bio bi taj koji sluša, i login ekran bi opet
/// morao pamtiti da to uradi.
class AppointmentHoldCard extends ConsumerWidget {
  const AppointmentHoldCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);

    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);

    final services = ref.watch(servicesProvider).valueOrNull;
    final employees = ref.watch(employeesProvider).valueOrNull;

    final usluga = _nadji(services, flow.serviceId, (s) => s.id);
    final radnik = _nadji(employees, flow.employeeId, (e) => e.id);
    final datum = flow.date;

    final opis = [
      if (usluga != null) usluga.name,
      if (radnik != null)
        '${vertical.terms.staffSingular.toLowerCase()}: ${radnik.name}'
      else
        l10n.bookingAnyStaff.toLowerCase(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bookingHoldingFor, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (!dateOnly && flow.startTime != null) ...[
                Text(
                  flow.startTime!.format(),
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  datum == null ? '—' : formatDateWithWeekday(l10n, datum),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (dateOnly) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.bookingDateOnlyNote, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(opis, style: theme.textTheme.bodyMedium),
          if (usluga != null && ref.watch(prikaziCijeneProvider)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatDurationLong(usluga.durationMinutes)} · '
              '${formatPrice(usluga.price)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  /// Nađi po `id`-u, bez `firstWhere` koji baca kad nema pogotka.
  T? _nadji<T>(List<T>? lista, String? id, String Function(T) idOf) {
    if (lista == null || id == null) return null;
    for (final stavka in lista) {
      if (idOf(stavka) == id) return stavka;
    }
    return null;
  }
}
