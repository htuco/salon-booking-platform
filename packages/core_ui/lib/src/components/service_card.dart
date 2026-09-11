import 'package:flutter/material.dart';

import '../theme/theme_factory.dart';
import '../tokens/spacing.dart';

/// Kartica usluge — stavka u katalogu i u prvom koraku bookinga.
///
/// Prima gotove stringove, ne `Service` model. Razlog je smjer zavisnosti iz
/// `conventions.md`: `core_ui` ne uvozi `core_domain`, pa se ista kartica koristi i u
/// admin aplikaciji, gdje cijena dolazi iz drugog konteksta. Formatiranje cijene i
/// trajanja je posao ekrana, koji jedini zna jezik i vertikalu.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.name,
    required this.duration,
    this.price,
    this.description,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final String name;

  /// Već formatirano ("45 min"), jer `core_ui` ne zna jezik.
  final String duration;

  /// `null` kad salon ne prikazuje cijene (`VerticalFeatures`).
  final String? price;
  final String? description;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = context.brandColors;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                // Izabrana kartica se razlikuje i debljinom, ne samo bojom: razlika
                // koju nosi samo boja nestaje za daltoniste i na jakom suncu.
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          description!,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(duration, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    price!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      // Cijena je jedino mjesto gdje brand boja nosi tekst — zato ide
                      // kroz `brandColors`, varijantu provjerenu na pozadini teme.
                      color: brand.primaryOnSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
