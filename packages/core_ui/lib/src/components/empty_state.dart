import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import 'app_button.dart';

/// Prazno stanje — poruka i, kad ima smisla, izlaz iz njega.
///
/// `docs/02 §14`: offline i prazan rezultat nikad nisu prazan ekran. Korisnik koji vidi
/// bijelu površinu zaključi da je app pokvarena, i to je zadnje što uradi u njoj.
///
/// Tekst se ne pravi ovdje. Poruka o praznom rezultatu zavisi od vertikale ("nema
/// slobodnih termina" nije isto što i "nema slobodnih pregleda"), pa je daje ekran iz
/// `vertical.terms`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData? icon;

  /// Dugme se prikazuje samo kad postoje i labela i akcija — dugme koje ne radi ništa
  /// je gore od nepostojanja dugmeta.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imaAkciju = actionLabel != null && onAction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSize.iconEmptyState,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (imaAkciju) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
