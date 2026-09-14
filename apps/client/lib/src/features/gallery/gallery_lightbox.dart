import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';

/// Lightbox galerije — `SPEC.md` 5q, `17-lightbox-galerije.png`.
///
/// Preko cijelog ekrana, brojač „4 / 18" u sredini, ✕ lijevo, traka sličica na dnu.
/// **Nije ruta nego overlay** (`showDialog` sa punim ekranom): handoff ga zove „overlay",
/// a i ponašanje traži isto — zatvaranje vraća na istu poziciju skrola u mreži, što push
/// ruta ne garantuje.
///
/// ## Zašto je ovo napisano prije mreže
///
/// Lightbox diktira kako se slike učitavaju. Mreža traži sličice, lightbox punu veličinu
/// istog URL-a; da je mreža nastala prva, ćelije bi kеširale 110px verziju i otvaranje bi
/// svaku fotografiju skidalo drugi put. `PhotoFrame` zato ograničava dekodiranje na
/// veličinu ćelije, a ovdje se ista slika traži bez tog ograničenja — jedan disk kes, dvije
/// namjene.
///
/// ## Bez dijeljenja
///
/// Handoff u zaglavlju crta i ⤴ (share). DoD taska 20 ga ne nabraja, a dijeljenje traži
/// `share_plus` i konfiguraciju po platformi — paket se ne dodaje usput. Dugme zato ne
/// postoji: prazno dugme koje ništa ne radi je gore od dugmeta kojeg nema.
class GalleryLightbox extends StatefulWidget {
  const GalleryLightbox({
    required this.urls,
    required this.initialIndex,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  /// Otvara lightbox preko cijelog ekrana.
  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
  }) {
    if (urls.isEmpty) return Future.value();

    return showDialog<void>(
      context: context,
      // Bez zatamnjenja ispod: ekran je ionako pun. `barrierColor` bi se vidio samo
      // kroz ivice animacije i tamo bi izgledao kao greška u crtanju.
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) =>
          GalleryLightbox(urls: urls, initialIndex: initialIndex),
    );
  }

  @override
  State<GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<GalleryLightbox> {
  late final PageController _pageController;
  late final ScrollController _trakaController;
  late int _index;

  /// Strana sličice u traci na dnu. 64px je iznad minimalne dodirne mete od 44px iz
  /// `SPEC.md`, pa traka ostaje upotrebljiva i kao navigacija, ne samo kao pregled.
  static const double _slicica = 64;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _index);
    _trakaController = ScrollController();
    // Traka mora otvoriti na aktivnoj sličici, ne na prvoj. Handoff crta „4 / 18" iznad
    // trake u kojoj je **prva** sličica uokvirena — to je nedosljednost nacrta, a ne
    // ponašanje: okvir označava sliku koja se gleda.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centrirajTraku());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _trakaController.dispose();
    super.dispose();
  }

  void _centrirajTraku() {
    if (!_trakaController.hasClients) return;
    final cilj = _index * (_slicica + AppSpacing.sm);
    _trakaController.animateTo(
      cilj.clamp(0, _trakaController.position.maxScrollExtent),
      duration: AppDuration.fast,
      curve: Curves.easeOut,
    );
  }

  void _naIndeks(int noviIndeks) {
    setState(() => _index = noviIndeks);
    _centrirajTraku();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ukupno = widget.urls.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Zaglavlje(
              brojac: l10n.galleryCounter(_index + 1, ukupno),
              zatvoriLabela: l10n.galleryClose,
              onZatvori: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: ukupno,
                onPageChanged: _naIndeks,
                itemBuilder: (context, i) => Semantics(
                  label: l10n.galleryPhotoLabel(i + 1, ukupno),
                  image: true,
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    // `contain`, ne `cover`: ovo je pregled fotografije, a ne ćelija
                    // mreže — odsjecanje ivica ovdje krije upravo ono što se gleda.
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    placeholder: (context, url) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            if (ukupno > 1)
              _TrakaSlicica(
                urls: widget.urls,
                aktivni: _index,
                controller: _trakaController,
                strana: _slicica,
                onIzbor: (i) {
                  _naIndeks(i);
                  _pageController.jumpToPage(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje({
    required this.brojac,
    required this.zatvoriLabela,
    required this.onZatvori,
  });

  final String brojac;
  final String zatvoriLabela;
  final VoidCallback onZatvori;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // 48×48 dodirna meta — `SPEC.md` traži ≥44px svugdje, a ✕ je jedini izlaz
          // sa ovog ekrana na uređaju bez geste nazad.
          Semantics(
            button: true,
            label: zatvoriLabela,
            child: InkWell(
              onTap: onZatvori,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: const Icon(LucideIcons.x, size: 22),
              ),
            ),
          ),
          Expanded(
            child: Text(
              brojac,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          // Prazan prostor širine dugmeta, da brojač ostane stvarno centriran.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TrakaSlicica extends StatelessWidget {
  const _TrakaSlicica({
    required this.urls,
    required this.aktivni,
    required this.controller,
    required this.strana,
    required this.onIzbor,
  });

  final List<String> urls;
  final int aktivni;
  final ScrollController controller;
  final double strana;
  final void Function(int index) onIzbor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: strana + AppSpacing.xl,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: urls.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => onIzbor(i),
          child: Container(
            decoration: BoxDecoration(
              // Aktivna sličica se razlikuje **debljinom i bojom okvira**, ne skaliranjem:
              // traka u kojoj jedna sličica raste pomjera sve ostale pri svakom listanju.
              border: Border.all(
                color: i == aktivni ? scheme.onSurface : scheme.outline,
                width: i == aktivni ? 2 : 1,
              ),
            ),
            child: PhotoFrame(imageUrl: urls[i], size: strana),
          ),
        ),
      ),
    );
  }
}
