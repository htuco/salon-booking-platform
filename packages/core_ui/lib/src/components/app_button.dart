import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/status_colors.dart';

/// Varijante dugmeta iz `docs/02 §16`.
enum AppButtonVariant {
  /// Primarni CTA — brand boja kao pozadina, `onPrimary` izračunat.
  primary,

  /// Sekundarna akcija — brand boja kao ispuna, niži naglasak.
  secondary,

  /// Tercijarna akcija — samo obrub.
  outline,

  /// Destruktivno (otkaži termin). Statusna boja, ne brand — otkazivanje mora
  /// izgledati isto u svakom salonu.
  danger,
}

/// Dugme koje uvijek ima dovoljnu dodirnu metu i čitljiv tekst.
///
/// Ne prima `Color`. Kad bi primalo, prvi ekran u žurbi bi proslijedio literal i brand
/// boja bi prestala da važi baš tamo gdje se najviše vidi.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expanded = true,
    this.loading = false,
    super.key,
  });

  final String label;

  /// `null` znači onemogućeno. Uz `loading: true` se ignoriše — dugme koje čeka odgovor
  /// ne smije primiti drugi tap (dvostruka rezervacija istog termina).
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Primarni CTA je full-width po `docs/02 §14`; u redu sa drugim dugmadima ne.
  final bool expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = context.statusColors;
    final jeCta = variant == AppButtonVariant.primary;

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // Boja iz konteksta dugmeta, ne fiksna — na zlatnoj pozadini bijeli
              // indikator nestane isto kao i bijeli tekst.
              color: _foreground(scheme, status),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final onTap = loading ? null : onPressed;
    final visina = jeCta ? AppSize.ctaHeight : AppSize.buttonHeight;

    final dugme = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.secondary => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _background(scheme, status),
          foregroundColor: _foreground(scheme, status),
          minimumSize: Size(0, visina),
        ),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: status.danger,
          foregroundColor: status.onDanger,
          minimumSize: Size(0, visina),
        ),
        child: child,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: Size(0, visina)),
        child: child,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: dugme) : dugme;
  }

  Color _background(ColorScheme scheme, AppStatusColors status) =>
      switch (variant) {
        AppButtonVariant.primary => scheme.primary,
        AppButtonVariant.secondary => scheme.secondary,
        AppButtonVariant.danger => status.danger,
        AppButtonVariant.outline => Colors.transparent,
      };

  Color _foreground(ColorScheme scheme, AppStatusColors status) =>
      switch (variant) {
        AppButtonVariant.primary => scheme.onPrimary,
        AppButtonVariant.secondary => scheme.onSecondary,
        AppButtonVariant.danger => status.onDanger,
        AppButtonVariant.outline => scheme.onSurface,
      };
}
