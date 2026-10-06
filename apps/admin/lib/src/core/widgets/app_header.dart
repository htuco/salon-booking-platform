/// Zaglavlje ekrana na telefonu — iOS navigation bar bez Material trake naslova.
///
/// **Konfiguracija, ne raspored.** Ekran opiše zaglavlje ([AppHeader]) i preda ga
/// `AdminScaffold`-u; [AppHeaderLayout] ga stavi iznad tijela. Tijelo ekrana ostaje kakvo
/// jeste — zaglavlje samo sluša njegov scroll.
///
/// **Korijen taba nema naslov.** Ime ekrana već piše na aktivnoj ćeliji donje trake, pa bi
/// naslov iznad sadržaja bio isti podatak dvaput. Traka korijena ostaje samo kad ima šta da
/// nosi (akcije, lijevi slot), a `bottom` uvijek. Detalj u grani ima inline naslov, jer ga
/// donja traka ne imenuje.
///
/// Pozadina je uvijek boja ekrana; hairline linija ispod se pali na prvih 8 px scrolla
/// tijela. Nikad elevation ni sjenka.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../router/admin_router.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// Visina inline trake bez safe area.
const double _visinaTrake = 44;

/// Visina `bottom` slota sa paddingom 16/8: kontrola je 32 visoka.
const double _visinaDna = 48;

/// Najduža labela „nazad" prije nego postane samo „Nazad".
const int _najduzaLabela = 12;

/// Akcija u zaglavlju: Lucide ikona, ime za čitač ekrana i opcionalni brojač.
class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Broj u koralnom krugu; `null` ili 0 se ne crta.
  final int? badge;
}

/// Tekstualna akcija desno („Sačuvaj") na ekranu u grani — uz automatski „nazad".
///
/// [onTap] `null` je onemogućeno stanje (45 %).
class HeaderTextAction {
  const HeaderTextAction({required this.label, required this.onTap, this.key});

  final String label;
  final VoidCallback? onTap;
  final Key? key;
}

/// Opis zaglavlja jednog ekrana.
class AppHeader {
  // Nije `const`: provjera broja akcija ne može u konstantni izraz.
  AppHeader({
    required this.title,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.tabRoot = true,
    this.onTitleTap,
    this.textAction,
  }) : assert(actions.length <= 2, 'Zaglavlje nosi najviše dvije akcije.'),
       assert(
         textAction == null || actions.isEmpty,
         'Tekstualna akcija stoji sama na desnoj strani.',
       ),
       otkazi = null,
       sacuvaj = null,
       sacuvajLabela = null;

  /// Zaglavlje forme preko cijelog ekrana: „Otkaži" lijevo, „Sačuvaj" desno.
  ///
  /// [onSave] `null` je forma koja još nije ispravna — dugme stoji na 45 %.
  const AppHeader.forma({
    required this.title,
    required VoidCallback onCancel,
    required VoidCallback? onSave,
    String saveLabel = 'Sačuvaj',
  }) : leading = null,
       actions = const [],
       bottom = null,
       tabRoot = false,
       onTitleTap = null,
       textAction = null,
       otkazi = onCancel,
       sacuvaj = onSave,
       sacuvajLabela = saveLabel;

  /// Inline naslov detalja; na korijenu taba se ne crta (v. [tabRoot]).
  final String title;

  /// Lijevi slot kad navigator nema kuda nazad. Kad ima, uvijek je „nazad".
  final Widget? leading;

  final List<HeaderAction> actions;

  /// Segmentirani prekidač ili pretraga ispod trake.
  final Widget? bottom;

  /// Korijen taba: bez naslova, ime ekrana nosi donja traka. Detalj: inline naslov.
  final bool tabRoot;

  /// Naslov je dugme (birač salona) — uz njega stoji strelica dolje.
  final VoidCallback? onTitleTap;

  /// „Sačuvaj" desno umjesto ikona.
  final HeaderTextAction? textAction;

  final VoidCallback? otkazi;
  final VoidCallback? sacuvaj;
  final String? sacuvajLabela;

  bool get jeForma => otkazi != null;

  /// Da li gornja traka ima šta da nosi. Korijen taba bez akcija je nema.
  bool get imaTraku =>
      !tabRoot || leading != null || actions.isNotEmpty || textAction != null;
}

/// Ekran sa [AppHeader]-om iznad tijela; linija ispod zaglavlja prati scroll tijela.
class AppHeaderLayout extends StatefulWidget {
  const AppHeaderLayout({required this.header, required this.body, super.key});

  final AppHeader header;
  final Widget body;

  @override
  State<AppHeaderLayout> createState() => _AppHeaderLayoutState();
}

class _AppHeaderLayoutState extends State<AppHeaderLayout> {
  /// 0 → 1 na prvih 8 px scrolla tijela.
  final _pomaknuto = ValueNotifier<double>(0);

  @override
  void dispose() {
    _pomaknuto.dispose();
    super.dispose();
  }

  bool _slusaj(ScrollNotification n) {
    // Samo vertikalna lista tijela; horizontalni red unutar nje ne pali liniju.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _pomaknuto.value = ((n.metrics.pixels - n.metrics.minScrollExtent) / 8)
        .clamp(0.0, 1.0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final boje = context.adminColors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Tamne ikone status bara: zaglavlje je uvijek svijetla podloga ekrana.
      value: SystemUiOverlayStyle.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: boje.ground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top),
                if (header.imaTraku)
                  SizedBox(
                    height: _visinaTrake,
                    child: _Traka(header: header),
                  ),
                if (header.bottom case final dno?)
                  SizedBox(
                    height: _visinaDna,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: dno,
                    ),
                  ),
                ValueListenableBuilder<double>(
                  valueListenable: _pomaknuto,
                  builder: (context, pomaknuto, _) => Opacity(
                    key: const ValueKey('app-header-linija'),
                    opacity: pomaknuto,
                    child: Container(height: 0.5, color: boje.separator),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _slusaj,
              // Tijelo je već ispod zaglavlja; gornji safe area je potrošen.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: widget.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline traka: lijevi slot, centriran naslov (samo detalj), akcije.
class _Traka extends StatelessWidget {
  const _Traka({required this.header});

  final AppHeader header;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final Widget lijevo;
    final Widget desno;

    if (header.jeForma) {
      lijevo = _TekstDugme(tekst: 'Otkaži', onTap: header.otkazi);
      desno = _TekstDugme(
        tekst: header.sacuvajLabela ?? 'Sačuvaj',
        onTap: header.sacuvaj,
        istaknut: true,
      );
    } else {
      lijevo = Navigator.of(context).canPop()
          ? _Nazad(labela: labelaNazad(context))
          : header.leading ?? const SizedBox.shrink();
      final tekst = header.textAction;
      desno = tekst != null
          ? _TekstDugme(
              key: tekst.key,
              tekst: tekst.label,
              onTap: tekst.onTap,
              istaknut: true,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, akcija) in header.actions.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _Ikona(akcija: akcija),
                ],
              ],
            );
    }

    final naslov = _Naslov(
      key: const ValueKey('app-header-inline'),
      header: header,
      style: barlow(size: 17, weight: 600, height: 1.2, color: boje.ink),
    );

    // Naslov je centriran na cijeloj širini, ne između slotova: lijevi i desni slot
    // nisu iste širine, a pomjeren naslov se vidi pri svakom prelazu.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!header.tabRoot)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: naslov,
            ),
          Align(alignment: Alignment.centerLeft, child: lijevo),
          Align(alignment: Alignment.centerRight, child: desno),
        ],
      ),
    );
  }
}

/// Naslov sa opcionalnim biračem: tekst i strelica dolje su jedno dugme.
class _Naslov extends StatelessWidget {
  const _Naslov({required this.header, required this.style, super.key});

  final AppHeader header;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tekst = Semantics(
      header: true,
      child: Text(
        header.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
    final onTap = header.onTitleTap;
    if (onTap == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Flexible(child: tekst)],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Pressable(
            onTap: onTap,
            minSize: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: tekst),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown300, size: 14, color: style.color),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// „‹ Kalendar" — strelica i ime ekrana na koji se vraća.
class _Nazad extends StatelessWidget {
  const _Nazad({required this.labela});

  final String labela;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Pressable(
      semanticLabel: 'Nazad na $labela',
      onTap: () => Navigator.of(context).maybePop(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.chevronLeft300, size: 22, color: boje.accent),
          Text(
            labela,
            maxLines: 1,
            style: barlow(size: 17, height: 1.2, color: boje.accent),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Ime ekrana ispod ovog u grani, ili „Nazad" kad je predugo ili nepoznato.
///
/// Ekran ispod je roditelj putanje: `/calendar/appointment/:id` se vraća na Kalendar,
/// `/more/clients` na Još. Push u grani uvijek ide na dijete, pa je to tačno.
String labelaNazad(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return 'Nazad';
  final segmenti = [...GoRouterState.of(context).uri.pathSegments];
  while (segmenti.length > 1) {
    segmenti.removeLast();
    final putanja = '/${segmenti.join('/')}';
    for (final ruta in AdminRoute.values) {
      if (ruta.path == putanja) {
        return ruta.title.length <= _najduzaLabela ? ruta.title : 'Nazad';
      }
    }
  }
  return 'Nazad';
}

class _TekstDugme extends StatelessWidget {
  const _TekstDugme({
    required this.tekst,
    required this.onTap,
    this.istaknut = false,
    super.key,
  });

  final String tekst;
  final VoidCallback? onTap;
  final bool istaknut;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Opacity(
      // Onemogućeno „Sačuvaj" dok forma nije ispravna.
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            tekst,
            maxLines: 1,
            style: barlow(
              size: 17,
              weight: istaknut ? 600 : 400,
              height: 1.2,
              // Plava `accent`, ne koralna: koralni tekst na svijetloj podlozi je 3:1.
              color: boje.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _Ikona extends StatelessWidget {
  const _Ikona({required this.akcija});

  final HeaderAction akcija;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final broj = akcija.badge ?? 0;
    return Pressable(
      semanticLabel: broj > 0
          ? '${akcija.semanticLabel}, $broj'
          : akcija.semanticLabel,
      onTap: akcija.onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(akcija.icon, size: 22, color: boje.ink),
            if (broj > 0)
              Positioned(
                top: 6,
                left: 24,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: boje.action,
                    borderRadius: BorderRadius.circular(AdminRadius.pill),
                    border: Border.all(color: boje.ground, width: 1.5),
                  ),
                  child: Text(
                    broj > 99 ? '99+' : '$broj',
                    style: barlow(
                      size: 10,
                      weight: 600,
                      height: 1,
                      color: boje.onAction,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segmentirani prekidač za `bottom` slot (Dan / Sedmica, Novi / Svi).
///
/// Bez Material `SegmentedButton`-a: izabrani segment je bijela ploča na sivoj podlozi,
/// kao iOS. Onemogućen segment stoji na 45 %.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: boje.separator.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                segment: segment,
                izabran: segment.value == selected,
                onTap: segment.enabled ? () => onChanged(segment.value) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class AppSegment<T> {
  const AppSegment({
    required this.value,
    required this.label,
    this.count,
    this.enabled = true,
    this.disabledHint,
  });

  final T value;
  final String label;

  /// Broj uz labelu („Novi 3"); 0 i `null` se ne pišu.
  final int? count;
  final bool enabled;

  /// Šta čitač ekrana kaže o onemogućenom segmentu („uskoro").
  final String? disabledHint;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.izabran,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool izabran;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final broj = segment.count ?? 0;
    final labela = broj > 0 ? '${segment.label} $broj' : segment.label;
    return Semantics(
      selected: izabran,
      button: true,
      enabled: segment.enabled,
      label: segment.enabled
          ? labela
          : '$labela, ${segment.disabledHint ?? 'nedostupno'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: segment.enabled ? 1 : 0.45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: izabran ? boje.surface : null,
              borderRadius: BorderRadius.circular(AdminRadius.small),
              border: izabran
                  ? Border.all(color: boje.separator, width: 0.5)
                  : null,
            ),
            child: Text(
              labela,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: barlow(
                size: 13,
                weight: izabran ? 600 : 500,
                height: 1.2,
                color: boje.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Birač salona: modalni sheet sa ručkom i kvačicom na aktivnom.
///
/// Admin danas dobija tačno jedan salon iz članstva (ADR-0016), pa ekran Danas
/// [AppHeader.onTitleTap] postavlja tek kad ih ima više — do tada strelice nema.
Future<String?> showSalonSwitcher(
  BuildContext context, {
  required List<({String id, String naziv})> saloni,
  required String aktivni,
}) {
  final boje = context.adminColors;
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    barrierColor: boje.sidebarBackground.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AdminRadius.mobileSheet),
      ),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final salon in saloni)
            Pressable(
              onTap: () => Navigator.pop(sheet, salon.id),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: boje.separator, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        salon.naziv,
                        style: barlow(size: 17, color: boje.ink),
                      ),
                    ),
                    if (salon.id == aktivni)
                      Icon(LucideIcons.check300, size: 22, color: boje.action),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
