import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Naslovljena sekcija Početne — `prototype/ui/` `01-pocetna.png`.
///
/// Naslov je **serif** i velik: Cjenovnik, Majstori, Galerija i Recenzije su u handoffu
/// jednako teški kao naslov ekrana, i po tome se sekcije razlikuju od svega ostalog na
/// stranici. `titleLarge` (Archivo 21/600) bi ih sveo na podnaslove i ekran bi izgubio
/// ritam koji ga drži.
///
/// Naslov uvijek dolazi izvana, jer se svaki naslov na ovom ekranu razlikuje po
/// vertikali ili po jeziku — "Naš tim" kod barbera je "Naši doktori" kod stomatologa
/// (`docs/02 §3`). Widget koji bi sam pisao naslov bi to zaključao.
class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.child,
    this.trailing,
    this.action,
    super.key,
  });

  final String title;
  final Widget child;

  /// Link desno **u istom redu** sa naslovom ("Sve slike ›"). Handoff ga drži tu, ne
  /// ispod sadržaja: sekcija se tako može preskočiti bez skrolanja kroz nju.
  final Widget? trailing;

  /// Akcija ispod sadržaja, punom širinom ("Prikaži svih 8 usluga").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        bottom: AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
