/// Ljuska admin aplikacije oko četiri grane routera.
///
/// **Jedna ljuska za sve ekrane.** Do koraka 1 je svaki ekran sam crtao sidebar ili
/// mobilno zaglavlje i traku kroz `AdminScaffold`; sa `StatefulShellRoute.indexedStack`
/// to bi značilo četiri kopije ljuske, po jednu u svakoj grani. Ovdje se crta jednom:
///
/// - telefon: [AdminMobileHeader] gore (znak, salon, korisnik), grana u sredini sa svojim
///   `AppHeader`-om, [AdminDonjaNavigacija] dole;
/// - desktop: [AdminSidebar] lijevo, grana desno (top bar ostaje ekranu, jer nosi njegov
///   naslov i akcije).
///
/// Forme na root navigatoru (npr. Novi termin) prekrivaju cijelu ljusku, pa se traka tad
/// ne vidi bez ikakvog uslova ovdje.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/admin_destinations.dart';
import '../core/widgets/admin_mobile_shell.dart';
import '../core/widgets/admin_scaffold.dart';

/// Indeks grane Danas — „kuća" na koju Android „nazad" vraća prije izlaza.
const int kGranaDanas = 0;

/// Indeks grane Kalendar — brze akcije tada predlažu izabrani dan.
const int kGranaKalendar = 1;

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    required this.lokacija,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Trenutna putanja — samo za oznaku u sidebaru, koji ima osam stavki na četiri grane.
  /// Donja traka je ne čita: njen aktivni tab je [StatefulNavigationShell.currentIndex].
  final String lokacija;

  /// Dodir taba. Ponovni dodir aktivnog vraća granu na njen korijen.
  void _naTab(int indeks) => navigationShell.goBranch(
    indeks,
    initialLocation: indeks == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indeks = navigationShell.currentIndex;

    final ljuska = AdminShell.jeDesktop(context)
        ? Scaffold(
            body: Row(
              children: [
                AdminSidebar(aktivna: rutaSidebara(lokacija)),
                Expanded(child: navigationShell),
              ],
            ),
          )
        : Scaffold(
            // Tastaturu rješava `Scaffold` ekrana u grani; dva `Scaffold`-a koja oba
            // skupljaju tijelo bi ga skupila dvaput.
            resizeToAvoidBottomInset: false,
            // Tamna traka sa znakom i korisnikom je ista na svakom tabu; ispod nje svaki
            // ekran crta svoj `AppHeader`, vezan za njegov scroll.
            body: Column(
              children: [
                const AdminMobileHeader(),
                Expanded(
                  // Tamna traka je već uzela gornji safe area.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: navigationShell,
                  ),
                ),
              ],
            ),
            // Traka se skloni dok je tastatura gore, da polje ne ostane ispod nje.
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : AdminDonjaNavigacija(
                    currentIndex: indeks,
                    onTap: _naTab,
                    onQuickActions: () => showAdminQuickActions(
                      context,
                      ref,
                      calendar: indeks == kGranaKalendar,
                    ),
                  ),
          );

    // Android „nazad": push-ani ekran u grani i otvoren sheet ili dijalog zatvara
    // njihov navigator prije nego što ovo uopšte dođe na red. Ovdje stiže samo kad je
    // grana na korijenu — tada se iz druge grane ide na Danas, a sa Danas se izlazi.
    return PopScope(
      canPop: indeks == kGranaDanas,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(kGranaDanas);
      },
      child: ljuska,
    );
  }
}
