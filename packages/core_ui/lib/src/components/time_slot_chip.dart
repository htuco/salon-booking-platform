import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Chip slobodnog termina — `SPEC.md` §Recurring components, "Time slot".
///
/// Namjerno chip, a ne dropdown: `docs/02 §14` izričito zabranjuje dropdown sa trideset
/// vremena. Korisnik bira vrijeme pogledom po mreži, ne skrolanjem kroz listu.
///
/// Visina je 58 px, znatno iznad minimalne dodirne mete, jer se po mreži termina bira brzo
/// i prstom u pokretu. Izabrani chip je **invertovan** (ispuna u boji teksta, tekst u boji
/// podloge), ne obojen brendom: mreža od dvadeset brand-obojenih polja proguta CTA ispod
/// sebe.
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
        ? scheme.onSurface
        : zauzet
        ? scheme.surfaceContainerHighest
        : Colors.transparent;

    final tekst = selected
        ? scheme.surface
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
        borderRadius: BorderRadius.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            constraints: const BoxConstraints(
              // `SPEC.md`: 58–64 px. Iznad donje granice dodirne mete iz `docs/02 §14`.
              minHeight: AppSize.timeSlot,
              minWidth: AppSize.touchTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
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
