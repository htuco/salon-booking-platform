import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Jedan red kontakta: ikona, tekst i akcija koja ga otvara.
///
/// Akcija je `VoidCallback` koji daje ekran, a ne URI koji bi ovaj widget sam otvarao:
/// widget koji zove `url_launcher` se ne može testirati bez mockovanja platformskog
/// kanala, a ekran može proslijediti bilo šta.
class ContactRow extends StatelessWidget {
  const ContactRow({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// `null` — red je samo informacija (adresa bez mapa), bez dodirne mete.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final sadrzaj = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    if (onTap == null) return sadrzaj;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        // Red kontakta mora ostati dodirna meta od 44 px i kad je tekst jednoredan
        // (`docs/02 §14`).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
          child: sadrzaj,
        ),
      ),
    );
  }
}

/// Okvir oko liste kontakt redova — isti izgled kao kartica radnog vremena.
class ContactCard extends StatelessWidget {
  const ContactCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: scheme.outline),
      ),
      child: Column(children: children),
    );
  }
}
