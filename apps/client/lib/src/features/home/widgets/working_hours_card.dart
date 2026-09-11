import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../salon_schedule.dart';

/// Lista radnog vremena po danima.
///
/// Prima gotove parove (dan, vrijeme) umjesto `ScheduleDay` modela sa `LocalTime`-om,
/// jer i ime dana i riječ "Zatvoreno" dolaze iz `.arb`-a — widget koji bi ih sam pisao
/// bi zaključao jezik.
class WorkingHoursCard extends StatelessWidget {
  const WorkingHoursCard({required this.rows, super.key});

  final List<WorkingHoursRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    row.day,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // Danasnji dan je podebljan, jer je to jedini red koji korisnik
                      // zaista trazi kad otvori ovu sekciju.
                      fontWeight: row.isToday ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Text(
                  row.hours,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: row.isClosed ? scheme.onSurfaceVariant : null,
                    fontWeight: row.isToday ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Jedan red liste, sa već prevedenim tekstom.
class WorkingHoursRow {
  const WorkingHoursRow({
    required this.day,
    required this.hours,
    required this.isClosed,
    required this.isToday,
  });

  final String day;
  final String hours;
  final bool isClosed;
  final bool isToday;
}

/// `ScheduleDay` → red spreman za prikaz. Prevod dana i riječi "Zatvoreno" daje pozivalac.
WorkingHoursRow rowFor(
  ScheduleDay day, {
  required String label,
  required String closedLabel,
  required bool isToday,
}) => WorkingHoursRow(
  day: label,
  hours: day.isClosed
      ? closedLabel
      : '${day.hour!.startTime.format()} – ${day.hour!.endTime.format()}',
  isClosed: day.isClosed,
  isToday: isToday,
);
