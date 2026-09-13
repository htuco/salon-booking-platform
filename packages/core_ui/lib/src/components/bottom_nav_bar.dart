import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Jedna ćelija donje navigacije. Ikona i gotov tekst — `core_ui` ne zna jezik ni
/// vertikalu (v. `core_ui.dart`, pravilo 3), pa "Usluge" naspram "Tretmani" odlučuje ekran.
@immutable
class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;

  /// Tekst ispod ikone. Nikad se ne skraćuje u kodu — pet ćelija dijeli širinu ekrana,
  /// pa predugačka riječ ide u dva reda umjesto u tri tačke.
  final String label;
}

/// Donja navigacija — `prototype/ui/SPEC.md` §Bottom tab bar.
///
/// Handoff je zove **jedinom zajedničkom komponentom koju treba graditi prvu**, i to nije
/// stilska napomena: pet tab-level ekrana (5a, 5h, 5i, 5j, 5k) su nacrtani sa njom ispod
/// sebe, pa svaki od njih napisan bez nje dobije pogrešan donji razmak koji se poslije
/// vadi iz pet fajlova.
///
/// ## Zašto ne `NavigationBar`
///
/// Material `NavigationBar` nosi pilulu iza aktivne ikone, vlastitu visinu i prelaz od
/// 500 ms. Handoff traži suprotno: traka od 3 px na **vrhu** ćelije, uglato svuda
/// (`AppRadius.none`) i prelaz bez animacije. Presložiti `NavigationBarThemeData` da to
/// da znači boriti se sa podrazumijevanim vrijednostima pri svakoj nadogradnji Fluttera.
///
/// ## Boja je iz teme, ne iz handoffa
///
/// `SPEC.md` piše bijelu `#FFFFFF` za aktivnu ćeliju i `#9AA1A7` za neaktivnu. To je
/// paleta *jednog* brenda i jedne tamne teme. Ovdje aktivna ćelija ide u `onSurface`, a
/// neaktivna u `onSurfaceVariant` — iste uloge koje `elegant_beauty` popunjava tamnim
/// tekstom na svijetloj pozadini. Prepisan heks bi dao bijeli tekst na bijeloj traci, i
/// to bi se vidjelo tek na drugom tenantu.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  /// Ćelije slijeva nadesno. Redoslijed je odluka ekrana, ne komponente — u handoffu je
  /// Početna **u sredini** (`Usluge · Termini · Početna · Obavijesti · Postavke`).
  final List<AppBottomNavItem> items;

  /// Indeks aktivne ćelije. Van raspona se steže: traka je prikaz stanja rutiranja, a
  /// ekran koji je otvoren mimo ijednog taba ne smije srušiti navigaciju.
  final int currentIndex;

  /// Poziva se i kad se tapne **već aktivna** ćelija — tada tab vraća na svoj korijen
  /// (`StatefulShellRoute`, `goBranch(initialLocation: true)`).
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aktivni = items.isEmpty ? 0 : currentIndex.clamp(0, items.length - 1);

    return Container(
      decoration: BoxDecoration(
        // `surfaceDim` je traka, ne `surface`: u handoffu je tamnija od pozadine ekrana
        // (`#0B0C0D` naspram `#0F1012`), da se donji rub ekrana vidi i bez sjenke.
        color: scheme.surfaceDim,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        // Traka nosi puni donji safe area (26 px home indikatora u handoffu). Na uređaju
        // bez njega bi ćelije sjele na sam rub, pa ide minimum iz skale.
        minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            for (final (index, item) in items.indexed)
              Expanded(
                child: _Celija(
                  item: item,
                  aktivna: index == aktivni,
                  onTap: () => onSelect(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Celija extends StatelessWidget {
  const _Celija({
    required this.item,
    required this.aktivna,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool aktivna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final boja = aktivna ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: aktivna,
      child: InkWell(
        onTap: onTap,
        // Bez talasa i bez highlighta: sistem je uglat i bez sjenki, pa okrugli Material
        // talas preko kvadratne ćelije izgleda kao tuđa komponenta.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Stack(
          // **`topCenter`, ne podrazumijevani `topStart`.** `Column` je `MainAxisSize.min`,
          // pa je uzak koliko i njegov najširi potomak; `Stack` bi ga inače zalijepio uz
          // lijevu ivicu ćelije. Greška se ne vidi u widget testu — testni font crta svaki
          // znak kao kvadrat veličine fonta, pa labele ispadnu šire od ćelije i budu
          // "centrirane" slučajno. Na simulatoru je cijela traka bila pomjerena ulijevo.
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSize.navCellTopPadding,
                bottom: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: AppSize.navIcon,
                    color: boja,
                    // `SPEC.md`: stroke-width 1.5. Lucide u Flutteru je font ikona, pa
                    // debljina poteza dolazi iz težine glifa, ne iz parametra.
                  ),
                  const SizedBox(height: AppSize.navLabelGap),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: boja,
                      // `SPEC.md`: aktivna labela je weight 600. Archivo je varijabilan
                      // font, pa se osa mora gađati direktno — v. `typography.dart`.
                      fontWeight: aktivna ? FontWeight.w600 : FontWeight.w400,
                      fontVariations: [
                        FontVariation('wght', aktivna ? 600 : 400),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (aktivna)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // `SPEC.md`: traka je uvučena 16% s obje strane. Procenat, a ne
                    // fiksna vrijednost — pet ćelija dijeli širinu ekrana, pa bi ista
                    // uvlaka na 320 px i na tabletu dala dvije različite trake.
                    final uvlaka =
                        constraints.maxWidth * AppSize.navIndicatorInset;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(uvlaka, 0),
                      ),
                      child: Container(
                        height: AppSize.navIndicator,
                        color: scheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
