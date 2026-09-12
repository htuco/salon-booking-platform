import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Jedan red u [SpecCard].
@immutable
class SpecRow {
  const SpecRow({required this.label, this.value, this.trailing});

  /// Lijeva strana — "Usluga", "Status".
  final String label;

  /// Desna strana kao tekst. Koristi se kad nema [trailing].
  final String? value;

  /// Desna strana kao widget — badge, kvačica, chevron.
  final Widget? trailing;
}

/// Grupa redova sa hairline razdjelnicima — `SPEC.md` §Recurring components, "Spec card".
///
/// `1px` granica oko cjeline, redovi razdvojeni tanjom linijom, minimalna visina reda 60,
/// padding 18. Koristi se za sažetak termina (korak 4 i success ekran) i za svaki drugi
/// spisak "labela → vrijednost".
///
/// Bez sjenke i bez zaobljenja: dubina u ovom sistemu dolazi iz granica, ne iz elevacije
/// (`SPEC.md`: "Shadows — none; depth comes from hairline borders").
class SpecCard extends StatelessWidget {
  const SpecCard({required this.rows, this.header, super.key});

  /// Sadržaj iznad prvog reda — npr. veliko vrijeme termina u serifu.
  final Widget? header;

  final List<SpecRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: header,
            ),
            if (rows.isNotEmpty) Divider(height: 1, color: scheme.outline),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outline),
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (rows[i].trailing != null)
                    rows[i].trailing!
                  else if (rows[i].value != null)
                    Flexible(
                      child: Text(
                        rows[i].value!,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
