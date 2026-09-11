import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Naslovljena sekcija home ekrana.
///
/// Naslov uvijek dolazi izvana, jer se svaki naslov na ovom ekranu razlikuje po
/// vertikali ili po jeziku — "Naš tim" kod barbera je "Naši doktori" kod stomatologa
/// (`docs/02 §3`). Widget koji bi sam pisao naslov bi to zaključao.
class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.child,
    this.action,
    super.key,
  });

  final String title;
  final Widget child;

  /// Opcioni link ispod sekcije ("Pogledaj sve usluge →").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          child,
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}
