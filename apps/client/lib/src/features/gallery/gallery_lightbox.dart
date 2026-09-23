import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';

/// Lightbox galerije — `SPEC.md` 5q, `17-lightbox-galerije.png`.
///
/// Preko cijelog ekrana, ✕ lijevo, brojač „4 / 18" desno, traka sličica na dnu.
///
/// ## Zašto `PageRoute`, a ne `showDialog`
///
/// Handoff ga zove „overlay", i prva verzija je bila `showDialog`. Ali `Hero` leti samo
/// između `PageRoute`-ova — dijalog je `PopupRoute` i let se tiho ne desi (FE-204). Ruta je
/// zato `PageRouteBuilder` na root navigatoru; mreža ispod ostaje montirana, pa pozicija
/// skrola preživi zatvaranje isto kao kod dijaloga.
///
/// ## Zatvaranje sa druge slike
///
/// Ušlo se sa slike 3, izašlo sa slike 7 — `Hero` slijeće na ćeliju 7. Ako ona nije na
/// ekranu, let nema odredište i poskoči. Zato lightbox na svaku promjenu slike javlja
/// indeks kroz [GalleryLightbox.onIndeks], a mreža skroluje ispod prije `pop`-a.
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
    this.onIndeks,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  /// Javlja indeks slike koja se gleda — mreža ispod po njemu drži ćeliju na ekranu.
  final ValueChanged<int>? onIndeks;

  /// 260 ms iz DoD-a FE-204. Između `AppDuration.normal` i `slow`: let preko cijelog
  /// ekrana je duži put od prelaza unutar ekrana, a tokena za njega nema.
  static const Duration trajanjeLeta = Duration(milliseconds: 260);

  /// `Hero` tag ćelije i stranice. Galerija nema ID po slici (ADR-0008), a ista slika
  /// može stajati dvaput u nizu — sam URL bi dao dva ista taga i Flutter baca grešku.
  /// Pozicija ga čini jedinstvenim, URL ga veže za sliku.
  static Object heroTag(int indeks, String url) => ('galerija', indeks, url);

  /// Otvara lightbox preko cijelog ekrana.
  static Future<void> show(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
    ValueChanged<int>? onIndeks,
  }) {
    if (urls.isEmpty) return Future.value();

    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        transitionDuration: trajanjeLeta,
        reverseTransitionDuration: trajanjeLeta,
        // Pozadina se pretapa dok slika leti — bez toga bi mreža nestala u prvom frameu
        // i let bi išao preko praznog ekrana.
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: GalleryLightbox(
            urls: urls,
            initialIndex: initialIndex,
            onIndeks: onIndeks,
          ),
        ),
      ),
    );
  }

  @override
  State<GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<GalleryLightbox> {
  late final PageController _pageController;
  late final ScrollController _trakaController;
  late int _index;

  /// Dok je slika uvećana, jednoprstno povlačenje pomjera sliku — ne lista i ne zatvara.
  /// Pinch-zoom tako ne otima gestu od swipea, ni swipe od zooma.
  bool _uvecano = false;

  /// Pomak slike pri povlačenju nadolje; preko praga se lightbox zatvara.
  double _povlacenje = 0;
  static const double _pragZatvaranja = 120;
  static const double _brzinaZatvaranja = 700;

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
    setState(() {
      _index = noviIndeks;
      _uvecano = false;
    });
    widget.onIndeks?.call(noviIndeks);
    _centrirajTraku();
  }

  void _zatvori() => Navigator.of(context).pop();

  void _povuci(DragUpdateDetails d) => setState(
    () => _povlacenje = (_povlacenje + d.delta.dy).clamp(0, double.infinity),
  );

  void _pusti(DragEndDetails d) {
    if (_povlacenje > _pragZatvaranja ||
        (d.primaryVelocity ?? 0) > _brzinaZatvaranja) {
      _zatvori();
    } else {
      setState(() => _povlacenje = 0);
    }
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
              onZatvori: _zatvori,
            ),
            Expanded(
              // Swipe dolje zatvara. Vertikalno povlačenje se ne sudara sa `PageView`-om,
              // koji hvata samo horizontalno; uvećana slika ga prepušta zoomu.
              child: GestureDetector(
                onVerticalDragUpdate: _uvecano ? null : _povuci,
                onVerticalDragEnd: _uvecano ? null : _pusti,
                child: Transform.translate(
                  offset: Offset(0, _povlacenje),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: ukupno,
                    onPageChanged: _naIndeks,
                    physics: _uvecano
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemBuilder: (context, i) => Semantics(
                      label: l10n.galleryPhotoLabel(i + 1, ukupno),
                      image: true,
                      child: _Zumirljiva(
                        // Samo aktivna stranica javlja zoom — susjedna u prelazu ne
                        // smije zaključati listanje.
                        onUvecano: (v) {
                          if (i == _index && v != _uvecano) {
                            setState(() => _uvecano = v);
                          }
                        },
                        child: Hero(
                          tag: GalleryLightbox.heroTag(i, widget.urls[i]),
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
                            placeholder: (context, url) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
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
                child: const Icon(LucideIcons.x, size: AppSize.iconAction),
              ),
            ),
          ),
          // Brojač u gornjem desnom uglu — DoD FE-204 (`3/12`); ✕ ostaje lijevo.
          const Spacer(),
          Text(brojac, style: theme.textTheme.titleMedium),
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

/// Pinch-zoom jedne stranice. Javlja kad slika pređe u uvećano stanje i nazad, da
/// lightbox zna kome pripada jednoprstna gesta; dvostruki tap vraća na 1×.
///
/// Na 1× ovdje **nema `InteractiveViewer`-a**: njegov scale recognizer prihvata i jedan
/// prst čim pređe slop, i tako otme horizontalni swipe `PageView`-u i vertikalni swipe
/// zatvaranja. Umjesto njega sluša [_DvaPrsta], koji jednoprstni pokret pušta dalje.
/// Tek uvećana slika dobija `InteractiveViewer`, a tada listanje ionako stoji.
class _Zumirljiva extends StatefulWidget {
  const _Zumirljiva({required this.onUvecano, required this.child});

  final ValueChanged<bool> onUvecano;
  final Widget child;

  @override
  State<_Zumirljiva> createState() => _ZumirljivaState();
}

class _ZumirljivaState extends State<_Zumirljiva> {
  final _transform = TransformationController();
  bool _uvecano = false;

  static const double _prag = 1.01;
  static const double _maxZoom = 4;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_javi);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_javi)
      ..dispose();
    super.dispose();
  }

  void _javi() {
    final uvecano = _transform.value.getMaxScaleOnAxis() > _prag;
    if (uvecano == _uvecano) return;
    setState(() => _uvecano = uvecano);
    widget.onUvecano(uvecano);
  }

  /// Pinch sa 1× — skalira oko tačke između prstiju, dok `InteractiveViewer` ne preuzme.
  void _pinch(ScaleUpdateDetails d) {
    final s = d.scale.clamp(1.0, _maxZoom);
    final f = d.localFocalPoint;
    _transform.value = Matrix4.identity()
      ..translateByDouble(f.dx, f.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-f.dx, -f.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    // Cijela stranica je površina za zoom, ne samo piksel slike: `contain` ostavlja
    // prazne trake, a slika koja se još učitava nema veličinu — prsti tamo ne bi
    // pogodili ništa.
    final sadrzaj = SizedBox.expand(child: widget.child);
    final Widget slika = _uvecano
        ? InteractiveViewer(
            transformationController: _transform,
            maxScale: _maxZoom,
            child: sadrzaj,
          )
        : RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _DvaPrsta: GestureRecognizerFactoryWithHandlers<_DvaPrsta>(
                _DvaPrsta.new,
                (r) => r.onUpdate = _pinch,
              ),
            },
            child: AnimatedBuilder(
              animation: _transform,
              builder: (context, child) =>
                  Transform(transform: _transform.value, child: child),
              child: sadrzaj,
            ),
          );

    return GestureDetector(
      onDoubleTap: () => _transform.value = Matrix4.identity(),
      child: slika,
    );
  }
}

/// Scale recognizer koji ne reaguje na jedan prst. Pokret jednog prsta mu se ne
/// prosljeđuje, pa ne pređe slop i ne prihvati gestu — arenu dobije `PageView` ili
/// swipe dolje. Drugi prst ga tek budi.
class _DvaPrsta extends ScaleGestureRecognizer {
  final Set<int> _prsti = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _prsti.add(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _prsti.remove(event.pointer);
    }
    if (event is PointerMoveEvent && _prsti.length < 2) return;
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _prsti.remove(pointer);
    super.rejectGesture(pointer);
  }
}
