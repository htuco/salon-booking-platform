import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/spacing.dart';
import 'photo_frame.dart';

/// Red koji se bira — usluga (korak 1) ili radnik (korak 2).
///
/// `SPEC.md` §Recurring components, "Service row": `gap 14px; padding 14px; 1px border`,
/// fotografija 76×76, naziv 20/600, podnaslov 16/400, iznos desno u serifu. Izabrani red
/// nosi **deblju granicu i blago posvijetljenu podlogu**, ne drugu boju — razlika koju
/// nosi samo boja nestaje za daltoniste i na jakom suncu.
///
/// Jedna komponenta za oba koraka, jer je oblik isti: okvir za sliku lijevo, dva reda
/// teksta u sredini, jedan element desno. Razlikuje se samo šta je taj element — cijena
/// kod usluge, kvačica kod radnika.
///
/// Ne uvozi `core_domain`: prima gotove stringove (`core_ui.dart`, pravilo 3). Formatiranje
/// cijene i trajanja zna ekran, koji jedini poznaje jezik i vertikalu.
class SelectableRow extends StatelessWidget {
  const SelectableRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.imageUrl,
    this.placeholder,
    this.selected = false,
    super.key,
  });

  final String title;

  /// Trajanje i cijena ("30 minuta"), titula radnika ("Barber · 9 godina").
  final String? subtitle;

  /// Iznos desno, u serifu ("15 KM"). `null` kad salon ne prikazuje cijene ili kad je red
  /// radnik — tamo desno ide kvačica kad je izabran.
  final String? trailingText;

  final String? imageUrl;

  /// Sadržaj okvira dok slike nema — inicijal radnika, `?` za "bilo ko od nas".
  final Widget? placeholder;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        // Izabrani red je **blago posvijetljena** ista podloga (`SPEC.md`:
        // `rgba(242,242,243,.10)`), izvedena iz teme umjesto fiksnog bijelog preliva —
        // inače bi na svijetloj paleti posvijetlio u nevidljivo.
        color: selected
            ? Color.alphaBlend(
                scheme.onSurface.withValues(alpha: 0.10),
                scheme.surface,
              )
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.all(AppSpacing.rowPadding),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                PhotoFrame(imageUrl: imageUrl, placeholder: placeholder),
                const SizedBox(width: AppSpacing.rowPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    trailingText!,
                    // Cijena je u serifu — u handoffu je to jedini brojčani naglasak u
                    // listi i nosi pola njenog ritma.
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                    ),
                  ),
                ] else if (selected) ...[
                  const SizedBox(width: AppSpacing.md),
                  _Kvacica(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kvadratni check desno na izabranom radniku (`04-korak2-majstor.png`).
class _Kvacica extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      color: scheme.onSurface,
      child: Icon(LucideIcons.check, size: 20, color: scheme.surface),
    );
  }
}
