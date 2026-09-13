import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Jedan red kontakta: labela lijevo, vrijednost desno, i akcija koja je otvara.
///
/// Oblik je „Spec card / list group" iz `SPEC.md` §Recurring components, onako kako ga
/// `02-o-nama.png` i crta: `Adresa — Trg Slobode 15`, `Telefon — +387 62 123 456`.
///
/// **Ranije je ovaj red bio ikona + tekst + chevron.** Tako ga je napisao task 10, kad je
/// kontakt stajao na Početnoj i nije imao handoff ekran; task 19 ga je doveo na „O nama",
/// gdje handoff traži par labela→vrijednost. Ikona je otišla jer je nosila isto što i
/// labela pored nje, samo neprevedeno.
///
/// Akcija je `VoidCallback` koji daje ekran, a ne URI koji bi ovaj widget sam otvarao:
/// widget koji zove `url_launcher` se ne može testirati bez mockovanja platformskog
/// kanala, a ekran može proslijediti bilo šta.
class ContactRow extends StatelessWidget {
  const ContactRow({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  /// Lijeva strana — „Adresa", „Telefon", „Instagram".
  final String label;

  /// Desna strana — ono što se čita i, kad se tapne, otvara.
  final String value;

  /// `null` — red je samo informacija, bez dodirne mete i bez chevrona.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final sadrzaj = ConstrainedBox(
      // Handoff: red spec kartice ima minimalnu visinu 60. To je ujedno iznad dodirne
      // mete od 44, pa red ostaje dohvatljiv i kad su labela i vrijednost jednoredne.
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return sadrzaj;

    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: sadrzaj,
      ),
    );
  }
}

/// Okvir oko liste kontakt redova — isti izgled kao kartica radnog vremena.
///
/// Redove razdvaja hairline, kako `SPEC.md` traži za grupu redova; posljednji red ga
/// nema, da se linija ne poklopi sa granicom kartice.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
            child,
          ],
        ],
      ),
    );
  }
}
