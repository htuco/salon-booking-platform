import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';

/// Okvir pet tab-level ekrana — `prototype/ui/SPEC.md` 5a, 5h, 5i, 5j, 5k.
///
/// Drži `AppBottomNav` iznad `StatefulShellRoute`-a, pa svaki tab ima **svoj stack**:
/// otvoriš detalj termina, pređeš na Početnu i vratiš se — detalj je i dalje tu. Jedan
/// zajednički `Navigator` bi tu istoriju brisao pri svakom prelasku, što se na telefonu
/// osjeti odmah.
///
/// Pod-ekrani sa back headerom (Galerija, Recenzije, O aplikaciji, Pravila, Lightbox) i
/// cijeli booking flow stoje **izvan** ovog shella, pa nemaju tab bar — tako traži
/// handoff, i tako se ne dešava da korisnik usred rezervacije odluta u drugi tab.
class ClientShell extends ConsumerWidget {
  const ClientShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final terms = verticalOf(ref).terms;

    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        onSelect: (index) => shell.goBranch(
          index,
          // Tap na **već aktivnu** ćeliju vraća tab na njegov korijen (`SPEC.md`).
          // Bez ovoga korisnik koji je zalutao u pod-ekran nema načina da se vrati
          // osim back dugmetom, a na Početnoj to znači izlazak iz aplikacije.
          initialLocation: index == shell.currentIndex,
        ),
        items: [
          // Ikone su iz handoffa i barberske su (makaze). To je namjerno i već
          // odlučeno u tasku 11: **barber je 1:1 sa handoffom**, ostale vertikale
          // dobijaju svoj dizajn. Tekst, za razliku od ikone, ide kroz terminologiju.
          AppBottomNavItem(
            icon: LucideIcons.scissors,
            label: terms.servicePlural,
          ),
          // `terms` nema plural termina — ima `appointmentSingular` ("Termin") i
          // `myAppointments` ("Moji termini"), a prvi je pogrešan oblik za listu, drugi
          // predugačak za ćeliju širine petine ekrana. Ide iz `.arb`-a, isto kao naslov
          // samog ekrana (`appointmentsTitle`). Za dentalnu vertikalu ("Pregledi") to
          // treba postati `appointmentPlural` u `VerticalTerms`.
          AppBottomNavItem(
            icon: LucideIcons.calendarDays,
            label: l10n.navAppointments,
          ),
          // Početna je namjerno u sredini (`SPEC.md`), ne prva.
          AppBottomNavItem(icon: LucideIcons.house, label: l10n.navHome),
          AppBottomNavItem(
            icon: LucideIcons.bell,
            label: l10n.navNotifications,
          ),
          AppBottomNavItem(
            icon: LucideIcons.slidersHorizontal,
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
