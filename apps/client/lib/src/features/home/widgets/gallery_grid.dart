import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Galerija salona — tri kolone kvadratnih fotografija (`01-pocetna.png`).
///
/// Prikazuje najviše [maxPhotos] slika; ostatak dobija zaseban ekran (task 20). Početna
/// je izlog, ne album — mreža koja raste sa brojem slika bi kod salona sa pedeset
/// fotografija progurala Recenzije izvan dosega skrola.
///
/// **Sekciju sakriva ekran, ne ovaj widget.** Prazna lista ovdje daje praznu mrežu, i to
/// je namjerno: widget koji sam odlučuje da se ne prikaže je widget koji se ne može
/// testirati na prazno stanje.
class GalleryGrid extends StatelessWidget {
  const GalleryGrid({
    required this.urls,
    this.maxPhotos = 6,
    this.onTap,
    super.key,
  });

  final List<String> urls;
  final int maxPhotos;

  /// Otvaranje lightboxa (`SPEC.md` 5q) — ekran ga dobija u tasku 20. Dok je `null`,
  /// slike se ne tapaju i to je tačno stanje, a ne nedovršen tap.
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) {
    final prikazane = urls.take(maxPhotos).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final strana = (constraints.maxWidth - AppSpacing.sm * 2) / 3;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (index, url) in prikazane.indexed)
              GestureDetector(
                onTap: onTap == null ? null : () => onTap!(index),
                child: PhotoFrame(imageUrl: url, size: strana),
              ),
          ],
        );
      },
    );
  }
}
