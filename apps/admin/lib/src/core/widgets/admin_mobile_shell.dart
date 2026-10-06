/// Mobilni identitet i brze akcije zajednički svim glavnim ekranima.
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/appointments/appointments_providers.dart';
import '../../features/appointments/new_appointment_screen.dart';
import '../../features/calendar/calendar_providers.dart';
import '../../features/clients/clients_providers.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/profile/profilna_slika.dart';
import '../../features/services/usluga_editor.dart';
import '../../features/working_hours/working_hours_dialogs.dart';
import '../format/terminologija.dart';
import '../navigation/admin_destinations.dart';
import '../router/admin_router.dart';
import '../theme/theme.dart';
import 'admin_toast.dart';
import 'admin_wordmark.dart';
import 'pressable.dart';

/// Tamna traka na vrhu telefona: avatar korisnika, Melura znak i ime salona.
///
/// Stoji iznad `AppHeader`-a ekrana, u `AppShell`-u, pa je ista na svakom tabu. Uzima
/// gornji safe area; ikone status bara su zato svijetle.
class AdminMobileHeader extends ConsumerWidget {
  const AdminMobileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final staff = ref.watch(currentStaffProvider).valueOrNull;
    final salon = ref.watch(adminSalonProvider).valueOrNull;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: colors.sidebarBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminSpacing.lg,
              vertical: AdminSpacing.md,
            ),
            child: Row(
              children: [
                Pressable(
                  semanticLabel: 'Moj profil',
                  onTap: () => context.go(AdminRoute.profile.path),
                  child: ProfilAvatar(
                    url: staff?.photoUrl,
                    ime: staff?.name ?? '',
                    velicina: 36,
                    naTamnom: true,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Isti wordmark kao sidebar: Melura znak i verzal Barlow 600.
                      const AdminWordmark(velicinaZnaka: 24),
                      if (salon != null) ...[
                        const SizedBox(height: AdminSpacing.xs),
                        Text(
                          salon.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.sidebarMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                // Ravnoteža avataru lijevo, da wordmark stoji tačno u sredini.
                const SizedBox(width: AdminSize.touchTarget),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Donja navigacija
// ---------------------------------------------------------------------------

/// Visina reda tabova, bez safe area ispod.
const double _visinaTaba = 58;

/// Donja traka telefona: Danas · Kalendar · znak salona · Zahtjevi · Još.
///
/// Pet jednakih ćelija. Četiri taba su četiri grane routera, istim redom, pa je aktivni
/// tab **samo** [currentIndex] — nikad poređenje putanja. Znak salona u sredini nije
/// grana: zove [onQuickActions] i ne mijenja aktivni tab. Radnik ga ne dobija (task 47),
/// pa njegova traka ima četiri ćelije.
///
/// Traka ne siječe svoj sadržaj: znak izlazi 18 px iznad nje, a `Scaffold` crta
/// `bottomNavigationBar` poslije tijela, pa ga ništa ne prekriva.
class AdminDonjaNavigacija extends ConsumerWidget {
  const AdminDonjaNavigacija({
    required this.currentIndex,
    required this.onTap,
    required this.onQuickActions,
    super.key,
  });

  /// Indeks aktivne grane (`StatefulNavigationShell.currentIndex`).
  final int currentIndex;

  /// Dodir taba sa indeksom grane.
  final ValueChanged<int> onTap;

  /// Dodir znaka salona.
  final VoidCallback onQuickActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigacija = ref.watch(adminNavigacijaProvider);
    // Ista lista i za radnika: Danas, Kalendar, Zahtjevi, pa Još — red grana u routeru.
    final celije = [...adminPrimarne(navigacija), kAdminJos];

    final staff = ref.watch(currentStaffProvider).valueOrNull;
    final saZnakom = staff != null && staff.imaPristup && !staff.isEmployee;

    Widget tab(int i) => Expanded(
      child: _Tab(
        key: ValueKey('nav-${celije[i].route.name}'),
        cilj: celije[i],
        aktivan: i == currentIndex,
        onTap: () => onTap(i),
      ),
    );

    return Material(
      color: context.adminColors.sidebarBackground,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < celije.length; i++) ...[
                if (saZnakom && i == 2)
                  Expanded(child: _ZnakDugme(onTap: onQuickActions)),
                tab(i),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Obični tab: ikona i verzal labela, koralna crtica na vrhu kad je aktivan.
///
/// Bez pilule iza aktivnog — razliku nose boja i crtica. Cijela ćelija je meta dodira.
class _Tab extends ConsumerStatefulWidget {
  const _Tab({
    required this.cilj,
    required this.aktivan,
    required this.onTap,
    super.key,
  });

  final AdminDestination cilj;
  final bool aktivan;
  final VoidCallback onTap;

  @override
  ConsumerState<_Tab> createState() => _TabState();
}

class _TabState extends ConsumerState<_Tab> {
  bool _hover = false;
  bool _pritisnut = false;
  bool _fokus = false;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final cilj = widget.cilj;
    final broj = cilj.brojac == null
        ? 0
        : ref.watch(cilj.brojac!).valueOrNull ?? 0;
    final boja = widget.aktivan
        ? boje.sidebarAccentForeground
        : _hover
        ? boje.sidebarText
        : boje.sidebarMuted;
    // Okvir fokusa samo za tastaturu, kao `:focus-visible`.
    final fokusVidljiv =
        _fokus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    return Semantics(
      button: true,
      selected: widget.aktivan,
      label: broj > 0 ? '${cilj.label}, $broj' : cilj.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hover = h),
        onHighlightChanged: (p) => setState(() => _pritisnut = p),
        onFocusChange: (f) => setState(() => _fokus = f),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Opacity(
          opacity: _pritisnut ? 0.7 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: _visinaTaba),
            decoration: fokusVidljiv
                ? BoxDecoration(
                    border: Border.all(color: boje.action, width: 2),
                  )
                : null,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.aktivan)
                    Positioned(
                      key: const ValueKey('nav-indikator'),
                      top: 0,
                      left: constraints.maxWidth * 0.26,
                      right: constraints.maxWidth * 0.26,
                      height: 2,
                      child: ColoredBox(color: boje.action),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: _visinaTaba - 6,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cilj.icon, size: 22, color: boja),
                          const SizedBox(height: 5),
                          Text(
                            // verzal-ok: `Semantics` iznad nosi original.
                            cilj.label.toUpperCase(),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontFamily: 'Barlow',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              height: 1.2,
                              color: boja,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (broj > 0)
                    Positioned(
                      top: 6,
                      left: constraints.maxWidth / 2 + 6,
                      child: _Brojac(broj: broj),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Koralni brojač sa tamnim rubom, da izgleda kao izrez iz trake.
class _Brojac extends StatelessWidget {
  const _Brojac({required this.broj});

  final int broj;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: boje.action,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
        border: Border.all(color: boje.sidebarBackground, width: 2),
      ),
      child: Text(
        broj > 99 ? '99+' : '$broj',
        style: TextStyle(
          fontFamily: 'Barlow',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1,
          color: boje.onAction,
        ),
      ),
    );
  }
}

/// Srednja ćelija: znak salona izdignut 18 px iznad trake, sa plusom, bez labele.
class _ZnakDugme extends StatelessWidget {
  const _ZnakDugme({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Semantics(
      button: true,
      label: 'Novo – dodaj termin',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('nav-dodaj'),
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: SizedBox(
          height: _visinaTaba,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: -18,
                  child: DecoratedBox(
                    // Redoslijed je obrnut od CSS-a: Flutter crta prvu sjenu ispod.
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AdminRadius.small),
                      boxShadow: [
                        BoxShadow(
                          color: boje.sidebarBackground.withValues(alpha: 0.4),
                          offset: const Offset(0, 10),
                          blurRadius: 22,
                        ),
                        BoxShadow(color: boje.action, spreadRadius: 5.5),
                        BoxShadow(
                          color: boje.sidebarBackground,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const AdminZnakSalona(velicina: 56),
                  ),
                ),
                Positioned(
                  top: 22,
                  left: constraints.maxWidth / 2 + 14,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: boje.action,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: boje.sidebarBackground,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.plus600,
                        size: 10,
                        color: boje.sidebarBackground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo lokala u kvadratu sa blagim zaobljenjem; bez loga koralna pločica sa inicijalom.
///
/// Fallback ne izmišlja fotografiju lokala.
class AdminZnakSalona extends ConsumerWidget {
  const AdminZnakSalona({required this.velicina, super.key});

  final double velicina;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(adminSalonProvider).valueOrNull;
    final boje = context.adminColors;
    final ime = salon?.name.trim() ?? '';
    final logo = salon?.logoUrl;
    final fallback = ColoredBox(
      color: boje.action,
      child: Center(
        child: Text(
          ime.isEmpty ? '+' : ime.characters.first.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Barlow',
            fontSize: velicina * 24 / 56,
            fontWeight: FontWeight.w600,
            height: 1,
            color: boje.sidebarBackground,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadius.small),
      child: SizedBox(
        width: velicina,
        height: velicina,
        // Bijela podloga za logo sa providnim dijelovima, i na tamnoj temi.
        child: ColoredBox(
          color: boje.sidebarAccentForeground,
          child: logo != null && logo.isNotEmpty
              ? Image.network(
                  logo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel brzih akcija
// ---------------------------------------------------------------------------

enum _QuickAction { appointment, block, customer, employee, service }

/// „Šta dodajemo?" — lista iz `mobile-refresh`, prva akcija istaknuta.
///
/// Bez imena salona: panel otvara znak tog istog salona, pa bi ime bilo ponovljeno.
Future<void> showAdminQuickActions(
  BuildContext context,
  WidgetRef ref, {
  bool calendar = false,
}) async {
  final staff = ref.read(currentStaffProvider).valueOrNull;
  if (staff == null || !staff.imaPristup || staff.isEmployee) return;
  final boje = context.adminColors;
  final radnik = akuzativRadnika(radnikJednina(ref));
  final chosen = await showModalBottomSheet<_QuickAction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: boje.sidebarBackground.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AdminRadius.mobileSheet),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Šta dodajemo?',
                    style: Theme.of(sheetContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Zatvori',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Brze akcije',
              style: Theme.of(sheetContext).textTheme.bodySmall
                  ?.copyWith(color: boje.textSecondary),
            ),
            const SizedBox(height: AdminSpacing.xl),
            for (final (action, icon, title, subtitle) in [
              (
                _QuickAction.appointment,
                Icons.calendar_today_outlined,
                'Napravi termin',
                'Rezerviši vrijeme za klijenta',
              ),
              (
                _QuickAction.block,
                Icons.schedule_outlined,
                'Blokiraj vrijeme',
                'Pauza, odsustvo ili privatna obaveza',
              ),
              (
                _QuickAction.customer,
                Icons.person_outline,
                'Dodaj klijenta',
                'Sačuvaj kontakt novog klijenta',
              ),
              (
                _QuickAction.employee,
                Icons.group_outlined,
                'Dodaj $radnik',
                'Proširi tim svog lokala',
              ),
              (
                _QuickAction.service,
                Icons.content_cut_outlined,
                'Dodaj uslugu',
                'Dopuni ponudu salona',
              ),
            ])
              _BrzaAkcija(
                ikona: icon,
                naslov: title,
                opis: subtitle,
                istaknuta: action == _QuickAction.appointment,
                onTap: () => Navigator.pop(sheetContext, action),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || chosen == null) return;
  switch (chosen) {
    case _QuickAction.appointment:
      // Forma preko cijelog ekrana na root navigatoru; `pop` vraća u ovu granu.
      final dan = calendar ? ref.read(kalendarDatumProvider) : null;
      // `2026-10-06`, ne `DateTime.toString()` sa vremenom — adresa forme je vidljiva.
      final date = dan == null
          ? null
          : '${dan.year}-${dan.month.toString().padLeft(2, '0')}-'
                '${dan.day.toString().padLeft(2, '0')}';
      await context.push(
        Uri(
          path: AdminRoute.appointmentNew.path,
          queryParameters: date == null ? null : {'date': date},
        ).toString(),
      );
    case _QuickAction.block:
      await prikaziUredjivacBlokade(context, ref);
    case _QuickAction.customer:
      final customer = await showNewAdminCustomer(context, ref);
      if (customer != null && context.mounted) {
        ref.invalidate(adminKlijentiProvider);
        AdminToast.uspjeh(context, 'Klijent je sačuvan.');
      }
    case _QuickAction.employee:
      await showEmployeeEditor(context);
    case _QuickAction.service:
      await showServiceEditor(context, ref);
  }
}

/// Red panela brzih akcija: ikona u pločici, naslov i opis, strelica.
///
/// Prva akcija je istaknuta punom koralnom, ostale dijele hairline ispod.
class _BrzaAkcija extends StatelessWidget {
  const _BrzaAkcija({
    required this.ikona,
    required this.naslov,
    required this.opis,
    required this.istaknuta,
    required this.onTap,
  });

  final IconData ikona;
  final String naslov;
  final String opis;
  final bool istaknuta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;
    final boja = istaknuta ? boje.onAction : boje.ink;
    final radius = BorderRadius.circular(AdminRadius.mobileCard);
    return Padding(
      padding: EdgeInsets.only(bottom: istaknuta ? AdminSpacing.md : 0),
      child: Material(
        color: istaknuta ? boje.action : Colors.transparent,
        borderRadius: istaknuta ? radius : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: istaknuta ? radius : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 69),
            padding: EdgeInsets.symmetric(
              horizontal: istaknuta ? 13 : 0,
              vertical: AdminSpacing.md,
            ),
            decoration: istaknuta
                ? null
                : BoxDecoration(
                    border: Border(bottom: BorderSide(color: boje.separator)),
                  ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: istaknuta
                        ? boje.onAction.withValues(alpha: 0.12)
                        : boje.ground,
                    borderRadius: BorderRadius.circular(AdminRadius.mobileCard),
                  ),
                  child: Icon(ikona, size: 21, color: boja),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        naslov,
                        style: tekst.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: boja,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opis,
                        style: tekst.bodySmall?.copyWith(
                          color: istaknuta
                              ? boje.onAction.withValues(alpha: 0.8)
                              : boje.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: boja),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
