import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/admin_destinations.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/app_header.dart';

/// „Još" na telefonu (mobile-refresh): ravna lista u grupama Poslovanje, Salon i Nalog.
///
/// **Redovi nisu prepisana lista nego rep navigacije** ([adminSporedne]). Salon dobija
/// radno vrijeme i postavke, a **sve ostalo** iz repa ide u Poslovanje — modul dodan u
/// `kAdminDestinations` se ovdje pojavi sam, umjesto da na telefonu ostane nedostupan.
/// „Svi termini" stoji prvi, jer tab Zahtjevi vodi samo na filter na čekanju.
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.watch(adminNavigacijaProvider);
    final staff = ref.watch(currentStaffProvider).valueOrNull;
    final secondary = adminSporedne(navigation);
    const salonske = [AdminRoute.workingHours, AdminRoute.settings];
    final salon = secondary.where((d) => salonske.contains(d.route)).toList();
    final poslovanje = secondary
        .where((d) => !salonske.contains(d.route))
        .toList();
    Widget row(
      String title,
      IconData icon,
      VoidCallback action, {
      String? subtitle,
    }) => Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 62,
          leading: Icon(
            icon,
            size: 21,
            color: context.adminColors.textSecondary,
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: action,
        ),
        Divider(height: 1, color: context.adminColors.separator),
      ],
    );
    Widget group(String label, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: AdminSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            semanticsLabel: label,
            style: AdminText.eyebrow.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          ...children,
        ],
      ),
    );
    return AdminScaffold(
      title: 'Još',
      header: AppHeader(title: 'Još'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          group('Poslovanje', [
            // Tab Zahtjevi otvara samo filter na čekanju; puna lista nema drugi ulaz.
            row(
              'Svi termini',
              Icons.event_note_outlined,
              () => context.push(AdminRoute.appointments.path),
            ),
            for (final destination in poslovanje)
              row(
                destination.label,
                destination.icon,
                () => context.go(destination.putanja),
              ),
          ]),
          if (salon.isNotEmpty)
            group('Salon', [
              for (final destination in salon)
                row(
                  destination.label,
                  destination.icon,
                  () => context.go(destination.putanja),
                ),
            ]),
          group('Nalog', [
            row(
              'Moj profil',
              Icons.person_outline,
              () => context.go(AdminRoute.profile.path),
              subtitle: staff?.name,
            ),
            row('Odjavi se', Icons.logout, () => odjavi(context, ref)),
          ]),
        ],
      ),
    );
  }
}
