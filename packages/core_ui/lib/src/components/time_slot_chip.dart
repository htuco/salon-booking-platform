import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Chip slobodnog termina — grid 4 po redu na 390 px (`docs/02 §14`).
///
/// Namjerno chip, a ne dropdown: `docs/02 §14` izričito zabranjuje dropdown sa trideset
/// vremena. Korisnik bira vrijeme pogledom po mreži, ne skrolanjem kroz listu.
class TimeSlotChip extends StatelessWidget {
  const TimeSlotChip({
    required this.label,
    this.onTap,
    this.selected = false,
    super.key,
  });

  /// Već formatirano zidno vrijeme salona ("14:30"). `core_ui` ne konvertuje vrijeme —
  /// `LocalTime` iz `core_domain` postoji baš da bi zona ostala van igre.
  final String label;

  /// `null` = termin je zauzet. Chip ostaje vidljiv, jer prazna mreža ne kaže korisniku
  /// da je salon pun — kaže da app ne radi.
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zauzet = onTap == null;

    final pozadina = selected
        ? scheme.primary
        : zauzet
        ? scheme.surfaceContainerHighest
        : Colors.transparent;

    final tekst = selected
        ? scheme.onPrimary
        : zauzet
        // Zauzeto je prigušeno, ali i dalje iznad AA praga: `onSurfaceVariant` je
        // mjeren u temi, za razliku od `withOpacity(0.4)` koje pada ispod.
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Semantics(
      button: !zauzet,
      selected: selected,
      enabled: !zauzet,
      child: Material(
        color: pozadina,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            constraints: const BoxConstraints(
              // 44 px u oba smjera — donja granica dodirne mete iz `docs/02 §14`.
              minHeight: AppSize.touchTarget,
              minWidth: AppSize.touchTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tekst,
                decoration: zauzet ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
