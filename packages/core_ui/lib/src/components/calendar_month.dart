import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/spacing.dart';

/// Jedan dan u [CalendarMonth].
///
/// Nosi **gotove stringove i identifikator**, ne datum: `core_ui` ne uvozi `core_domain`
/// (`core_ui.dart`, pravilo 3), pa ne zna ni šta je `LocalDate` ni kako se mjesec piše na
/// bosanskom. Ekran pravi mrežu, kalendar je crta.
@immutable
class CalendarDay {
  const CalendarDay({
    required this.id,
    required this.label,
    this.available = true,
  });

  /// Ono čime ekran prepoznaje dan — u klijentu je to `LocalDate.format()`.
  final String id;

  /// Broj dana u mjesecu ("14").
  final String label;

  /// Ima li dan ijedan slobodan termin.
  ///
  /// Nedostupan dan **ostaje vidljiv**, prigušen i bez tapa (`SPEC.md`: "past days
  /// non-interactive"). Prazno mjesto umjesto njega bi razbilo mrežu sedmice i korisnik bi
  /// izgubio orijentaciju u mjesecu.
  final bool available;
}

/// Mjesečni kalendar za izbor dana — `prototype/ui/SPEC.md` 5e.
///
/// Mreža 7 kolona sa ćelijom od 44 px (`SPEC.md`: "Calendar day — 44px square cell"),
/// zaglavlje sa imenom mjeseca u serifu i dvije kvadratne strelice za prethodni/sljedeći
/// mjesec.
///
/// **Dostupnost dana dolazi izvana.** Kalendar ne zna koji su dani slobodni i ne računa to
/// — availability je isključivo u bazi (`get_available_dates`, task 05). Ovdje se ne zna
/// ni šta je "prošli dan": i to je samo nedostupan dan.
class CalendarMonth extends StatelessWidget {
  const CalendarMonth({
    required this.monthLabel,
    required this.weekdayLabels,
    required this.days,
    required this.leadingEmptyCells,
    required this.onSelect,
    this.selectedId,
    this.onPreviousMonth,
    this.onNextMonth,
    super.key,
  });

  /// "Maj 2026" — sastavlja ga ekran, jer `core_ui` ne zna jezik.
  final String monthLabel;

  /// Sedam kratkih oznaka, od ponedjeljka: `['P', 'U', 'S', 'Č', 'P', 'S', 'N']`.
  final List<String> weekdayLabels;

  final List<CalendarDay> days;

  /// Koliko praznih ćelija ide prije prvog dana, da 1. u mjesecu padne na svoj dan u
  /// sedmici. Računa ekran — on jedini zna koji je to dan.
  final int leadingEmptyCells;

  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// `null` onemogućava strelicu — npr. unazad, kad je prikazan tekući mjesec.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(monthLabel, style: theme.textTheme.headlineSmall),
            ),
            _Strelica(icon: LucideIcons.chevronLeft, onTap: onPreviousMonth),
            const SizedBox(width: AppSpacing.sm),
            _Strelica(icon: LucideIcons.chevronRight, onTap: onNextMonth),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (final oznaka in weekdayLabels)
              Expanded(
                child: Text(
                  oznaka,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: AppSize.touchTarget,
          ),
          itemCount: leadingEmptyCells + days.length,
          itemBuilder: (context, index) {
            if (index < leadingEmptyCells) return const SizedBox.shrink();
            final dan = days[index - leadingEmptyCells];
            return _Dan(
              day: dan,
              selected: dan.id == selectedId,
              onTap: dan.available ? () => onSelect(dan.id) : null,
            );
          },
        ),
      ],
    );
  }
}

class _Strelica extends StatelessWidget {
  const _Strelica({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ugaseno = onTap == null;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: AppSize.touchTarget,
        height: AppSize.touchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
        child: Icon(
          icon,
          size: 20,
          color: ugaseno ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
    );
  }
}

class _Dan extends StatelessWidget {
  const _Dan({required this.day, required this.selected, this.onTap});

  final CalendarDay day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nedostupan = onTap == null;

    // Izabrani dan je **invertovan** (`SPEC.md`: "selected inverted"): ispuna u boji
    // teksta, tekst u boji podloge. Brand boja se ovdje namjerno ne koristi — dan je
    // izbor, ne akcija, a mreža od trideset brand-obojenih polja bi progutala CTA.
    final pozadina = selected ? scheme.onSurface : Colors.transparent;
    final tekst = selected
        ? scheme.surface
        : nedostupan
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Semantics(
      button: !nedostupan,
      selected: selected,
      enabled: !nedostupan,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pozadina,
            border: Border.all(color: scheme.outline),
          ),
          child: Text(
            day.label,
            style: theme.textTheme.labelMedium?.copyWith(color: tekst),
          ),
        ),
      ),
    );
  }
}
