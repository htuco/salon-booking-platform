import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/admin_destinations.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';

/// `3t` — „Još": moduli koje donja navigacija ne nosi kao ćeliju.
///
/// **Lista nije prepisana nego je rep navigacije** ([adminSporedne]). Modul dodan u
/// `kAdminDestinations` se ovdje pojavi sam; da je ovdje druga lista, novi modul bi na
/// telefonu ostao nedostupan, a na desktopu radio — razlika koja se ne vidi na širini na
/// kojoj se piše kod.
///
/// Canvas uz ove redove crta i grupe „Zakazivanje", „Obavijesti" i „Račun" sa konkretnim
/// postavkama (ručna potvrda, podsjetnici, pristup i uloge). To su postavke lokacije i
/// pišu se u tasku 36; ovdje bi bile prazne kontrole koje obećavaju funkciju.
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = AdminShell.gutterOf(context);

    return AdminScaffold(
      title: 'Još',
      aktivna: AdminRoute.more,
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: gutter,
          vertical: AdminSpacing.lg,
        ),
        children: [
          Text('Upravljanje', style: AdminText.eyebrow),
          const SizedBox(height: AdminSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final cilj in adminSporedne)
                  _Red(
                    cilj: cilj,
                    // Separator ide između redova, ne ispod zadnjeg: linija na dnu
                    // kartice udvaja njen obrub.
                    zadnji: cilj == adminSporedne.last,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AdminSpacing.xxl),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Odjavi se'),
              textColor: context.adminColors.destructive,
              iconColor: context.adminColors.destructive,
              onTap: () => odjavi(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _Red extends StatelessWidget {
  const _Red({required this.cilj, required this.zadnji});

  final AdminDestination cilj;
  final bool zadnji;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(cilj.icon),
          title: Text(cilj.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(cilj.putanja),
        ),
        if (!zadnji)
          Divider(
            height: AdminSize.hairline,
            thickness: AdminSize.hairline,
            color: context.adminColors.separator,
          ),
      ],
    );
  }
}
