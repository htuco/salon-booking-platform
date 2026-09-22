import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/spacing.dart';

/// Jedan red liste koja vodi dalje — labela lijevo, chevron desno.
/// `SPEC.md` §Recurring components („Spec card / list group"), `11-postavke.png` i
/// `14-o-aplikaciji.png`.
///
/// Doselio iz `apps/client/features/account/account_rows.dart` kad je dobio drugog
/// pozivaoca („O aplikaciji"), tačno kako je tamo i bilo zapisano da će biti. Dva stvarna
/// pozivaoca su rekla šta je zajedničko — oblik reda i grupe — a šta nije: brisanje naloga
/// je ostalo u aplikaciji, jer je destruktivna radnja, ne red liste.
///
/// ## Tri stanja, i razlika među njima je namjerna
///
/// - **`onTap` postoji** — chevron, `InkWell`, čvor tipa dugme za čitač ekrana.
/// - **`onTap` je `null`** — red nosi podatak, ne vodi nigdje („Jezik · Bosanski").
///   Nema chevron i ne prima fokus; red koji izgleda dodirno a ne reaguje je gori od
///   reda koji to ne glumi.
/// - **[disabled]** — red **jeste** link, ali trenutno ne vodi nigdje („Ocijenite
///   aplikaciju" dok app nije u prodavnici). Chevron ostaje, cjelina ide na 45%
///   prozirnosti (`SPEC.md` §Interactions: „disabled = 45% opacity"), dodir ne prolazi, a
///   čitač ekrana ga javlja kao onemogućeno dugme. Sakriti ga umjesto ovoga značilo bi da
///   se lista mijenja pod korisnikom kad app ode u store.
class LinkRow extends StatelessWidget {
  const LinkRow({
    required this.label,
    this.onTap,
    this.note,
    this.disabled = false,
    super.key,
  }) : assert(
         !disabled || onTap == null,
         'Onemogućen red ne smije nositi akciju — dodir na njega ne prolazi.',
       );

  final String label;

  /// Akcija reda. `null` znači da red nosi podatak (v. [disabled] za drugi slučaj).
  final VoidCallback? onTap;

  /// Druga linija ispod labele — kratko objašnjenje zašto red trenutno ne radi.
  ///
  /// Postoji zbog onemogućenog reda: prozirnost kaže *da* ne radi, ne i *zašto*.
  final String? note;

  /// Red je link koji čeka uslov koji još nije ispunjen.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dodirni = onTap != null;

    final sadrzaj = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                if (note != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(note!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (dodirni || disabled)
            Icon(
              LucideIcons.chevronRight,
              size: AppSize.iconInline,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    final okvir = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
      child: sadrzaj,
    );

    if (disabled) {
      return Semantics(
        button: true,
        enabled: false,
        // Prozirnost ide **oko** cijelog reda, ne na boju teksta: tako i chevron i
        // objašnjenje potamne zajedno, pa red ostaje jedna cjelina a ne tekst koji je
        // izblijedio pored ikone koja nije.
        child: Opacity(opacity: 0.45, child: okvir),
      );
    }

    if (!dodirni) return okvir;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: okvir),
      ),
    );
  }
}

/// Grupa redova u **jednom** okviru, sa hairline razdjelnicima između.
///
/// Handoff ih crta kao jednu kutiju, ne kao niz zasebnih kartica — više okvira bi se
/// čitalo kao više nepovezanih dugmadi. Razdjelnik ide **između**, nikad iznad prvog ni
/// ispod zadnjeg: tamo ga već crta obrub grupe, pa bi dupli potez bio deblji nego ostali.
class LinkRowGroup extends StatelessWidget {
  const LinkRowGroup({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: scheme.outline),
            rows[i],
          ],
        ],
      ),
    );
  }
}
