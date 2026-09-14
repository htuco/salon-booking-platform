import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'gallery_lightbox.dart';

/// `/gallery` — mreža fotografija salona (`SPEC.md` 5l, `12-galerija.png`).
///
/// **Pod-ekran bez tab bara.** Ruta zato stoji izvan `StatefulShellRoute`, uz booking flow
/// i `/account`, a ne kao podruta grane Početne — `/about` je podruta i **zadržava** traku
/// (5b), ovaj ekran je izričito nema (5l).
///
/// Slike dolaze iz `salons.gallery_urls`, iste liste koju Početna crta u izlogu od šest
/// ([ADR-0008](../../../../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md)).
/// Ovdje ih ide cijela lista — Početna je izlog, ovo je album.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  /// Tri kolone, `gap 8`, kvadrat — doslovno iz DoD-a i handoffa.
  static const int _kolona = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gallery = ref.watch(salonGalleryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryTitle)),
      body: SafeArea(
        child: gallery.when(
          loading: () => const _Kostur(),
          // Greška se crta kao prazno stanje, ne kao poruka o grešci: galerija je ukras,
          // a crveni okvir zbog neuspjelog ukrasa uznemiri više nego što informiše.
          error: (error, stack) => EmptyState(message: l10n.galleryEmpty),
          data: (urls) => urls.isEmpty
              // **Ekran postoji i kad slika nema.** Sekcija na Početnoj se u tom slučaju
              // sakriva, ali ruta je deep link i mora izdržati direktan dolazak.
              ? EmptyState(message: l10n.galleryEmpty)
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          AppSpacing.xl,
                        ),
                        child: Text(
                          l10n.gallerySubtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        0,
                        AppSpacing.gutter,
                        AppSpacing.xxl,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _kolona,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 1,
                            ),
                        itemCount: urls.length,
                        itemBuilder: (context, i) => Semantics(
                          button: true,
                          label: l10n.galleryPhotoLabel(i + 1, urls.length),
                          child: GestureDetector(
                            onTap: () => GalleryLightbox.show(
                              context,
                              urls: urls,
                              initialIndex: i,
                            ),
                            // `PhotoFrame` bez `size`-a bi crtao fiksni kvadrat; unutar
                            // grid ćelije veličinu diktira `gridDelegate`, pa slika ide
                            // preko `LayoutBuilder`-a.
                            child: LayoutBuilder(
                              builder: (context, constraints) => PhotoFrame(
                                imageUrl: urls[i],
                                size: constraints.maxWidth,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Skeleton u obliku mreže — devet ćelija, isti raspored kao pravi sadržaj.
class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: GalleryScreen._kolona,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemCount: 9,
      itemBuilder: (context, i) =>
          const SkeletonLoader(height: double.infinity),
    );
  }
}
