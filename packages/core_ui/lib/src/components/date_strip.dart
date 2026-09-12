import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Jedan dan u [DateStrip].
///
/// Nosi **gotove stringove i identifikator**, ne datum: `core_ui` ne uvozi `core_domain`
/// (`core_ui.dart`, pravilo 3), pa ne zna ni šta je `LocalDate` ni kako se dan piše na
/// bosanskom. Ekran pravi listu, traka je crta.
@immutable
class DateStripDay {
  const DateStripDay({
    required this.id,
    required this.weekdayLabel,
    required this.dayLabel,
    this.available = true,
  });

  /// Ono čime ekran prepoznaje dan pri povratku — u klijentu je to `LocalDate.format()`.
  final String id;

  /// Kratko ime dana ("Pon").
  final String weekdayLabel;

  /// Broj dana u mjesecu ("14").
  final String dayLabel;

  /// Ima li dan ijedan slobodan termin.
  ///
  /// Pun dan **ostaje u traci**, prigušen i bez tapa. Izbacivanje punih dana pomjeri
  /// raspored pod prstom i ostavi korisnika bez odgovora na pitanje "a šta je sa
  /// srijedom" — vidi se da postoji i da je zauzeta.
  final bool available;
}

/// Traka datuma — vodoravni izbor dana za korak sa terminima (`prototype/ui/SPEC.md` 5e).
///
/// Traka, a ne mjesečni kalendar: salon se rezerviše za nekoliko dana unaprijed, pa mreža
/// od 35 polja troši cijeli ekran da pokaže dane koje `maxAdvanceBookingDays` ionako ne
/// dozvoljava. Kad raspon bude širi od trake, mjesec ide u zaseban ekran, ne umjesto ove.
///
/// **Dostupnost dana dolazi izvana.** Traka ne zna koji su dani slobodni i ne računa to —
/// availability je isključivo u bazi (`get_available_dates`, task 05).
class DateStrip extends StatelessWidget {
  const DateStrip({
    required this.days,
    required this.onSelect,
    this.selectedId,
    super.key,
  });

  final List<DateStripDay> days;

  /// `id` izabranog dana, ili `null` dok korisnik nije birao.
  final String? selectedId;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final dan = days[index];
          return _Dan(
            day: dan,
            selected: dan.id == selectedId,
            onTap: dan.available ? () => onSelect(dan.id) : null,
          );
        },
      ),
    );
  }
}

class _Dan extends StatelessWidget {
  const _Dan({required this.day, required this.selected, this.onTap});

  final DateStripDay day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zauzet = onTap == null;

    final tekst = selected
        ? scheme.onPrimary
        : zauzet
        // `onSurfaceVariant` je mjeren u temi i ostaje iznad AA praga; `withOpacity`
        // na istoj boji pada ispod i to se vidi tek na svijetloj paleti.
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return Semantics(
      button: !zauzet,
      selected: selected,
      enabled: !zauzet,
      label: '${day.weekdayLabel} ${day.dayLabel}',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.weekdayLabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: tekst),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  day.dayLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tekst,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
