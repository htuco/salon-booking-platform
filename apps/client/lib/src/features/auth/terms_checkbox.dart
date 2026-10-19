import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// „Prihvatam Uslove korištenja i Politiku privatnosti" — checkbox sa linkovima na oba
/// dokumenta (task 66, ADR-0029).
///
/// **Prazan po defaultu**, i bez njega dugme registracije nije aktivno — tu odluku nosi
/// roditelj kroz [value]. Isti widget stoji na registraciji i na „Dopuni profil", da dva
/// mjesta na kojima korisnik daje isti pristanak ne bi rekla dvije različite stvari.
///
/// Linkovi se otvaraju **iznad** forme (`push`), pa povratak sa dokumenta vraća korisnika
/// na formu sa svim unesenim poljima.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tekst = theme.textTheme.bodyMedium;
    final link = tekst?.copyWith(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    void prebaci() {
      if (enabled) onChanged(!value);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l10n.termsAcceptSemantics,
          child: Checkbox(
            key: const ValueKey('terms-checkbox'),
            value: value,
            // Radius 0 je platformski oblik (`prototype/ui`), i za checkbox.
            shape: const RoundedRectangleBorder(),
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Veznici su za oko, ne za čitač ekrana: cijelu rečenicu već nosi
                // checkbox, a „dugme Prihvatam" i „dugme i" bi bila dva lažna cilja.
                ExcludeSemantics(
                  child: GestureDetector(
                    onTap: prebaci,
                    child: Text('${l10n.termsAcceptPrefix} ', style: tekst),
                  ),
                ),
                _Link(
                  label: l10n.termsAcceptTerms,
                  style: link,
                  onTap: () => context.push(ClientRoute.terms.path),
                ),
                ExcludeSemantics(
                  child: GestureDetector(
                    onTap: prebaci,
                    child: Text(' ${l10n.termsAcceptAnd} ', style: tekst),
                  ),
                ),
                _Link(
                  label: l10n.termsAcceptPrivacy,
                  style: link,
                  onTap: () => context.push(ClientRoute.privacy.path),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Text(label, style: style),
    ),
  );
}
