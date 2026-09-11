import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/status_colors.dart';

/// Namjena badgea — bira se **pojam**, ne boja.
///
/// Ekran nikad ne prosljeđuje `Color`. Da prosljeđuje, "potvrđeno" bi prije ili kasnije
/// bilo zeleno na jednom ekranu i brand boje na drugom.
enum StatusTone { success, warning, danger, info, blocked }

/// Badge stanja termina — pill sa statusnom bojom iz `docs/02 §16`.
///
/// Tekst dolazi izvana jer zavisi od vertikale i jezika; boja dolazi iz fiksne statusne
/// palete jer ne smije zavisiti ni od čega.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.tone, super.key});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final status = context.statusColors;
    final theme = Theme.of(context);

    final (pozadina, tekst) = switch (tone) {
      StatusTone.success => (status.success, status.onSuccess),
      StatusTone.warning => (status.warning, status.onWarning),
      StatusTone.danger => (status.danger, status.onDanger),
      StatusTone.info => (status.info, status.onInfo),
      StatusTone.blocked => (status.blocked, status.onBlocked),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: pozadina,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tekst,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
