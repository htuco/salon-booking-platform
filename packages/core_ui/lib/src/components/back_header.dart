import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/spacing.dart';

/// Zaglavlje pushed ekrana — `←` i ime ekrana sa kojeg se došlo (`SPEC.md` §Bottom tab bar:
/// „pushed views with a back header (`←` 22px + 18px/600 label, min-height 48px)").
///
/// **Ovo nije `AppBar`.** Materialov `AppBar` daje mali sans naslov i platformski chevron;
/// handoff traži strelicu, ime **roditeljskog** ekrana pored nje, a naslov ekrana ide u
/// tijelo kao veliki serif. Ekran koji umjesto ovoga uzme `AppBar` izgleda kao da je došao
/// iz druge aplikacije — razlika se vidi tek na uređaju, pored ekrana koji to rade ispravno.
///
/// **Strelica i riječ su jedna dodirna meta.** Sama strelica je 22 px, ispod donje granice
/// iz `docs/02 §14`, i promaši se u hodu.
class BackHeader extends StatelessWidget {
  const BackHeader({
    required this.label,
    required this.onBack,
    this.trailing,
    super.key,
  });

  /// Ime ekrana **na koji se vraća** („Početna"), ne ekrana na kojem stojiš.
  final String label;

  final VoidCallback onBack;

  /// Desna strana reda — brojač koraka, akcija. Prazno na većini ekrana.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          onTap: onBack,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.arrowLeft, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Text(label, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
