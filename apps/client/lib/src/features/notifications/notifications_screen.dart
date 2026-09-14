import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// `/notifications` — „Obavijesti" (`SPEC.md` 5j, `10-obavijesti.png`).
///
/// **Samo prazno stanje, i to je odluka a ne nedovršen ekran.**
///
/// Handoff crta listu potvrda, podsjetnika i objava salona, sa razlikovanjem nepročitanog.
/// Ta lista **nema odakle doći**: `notification_logs` postoji, ali jedina politika nad njom
/// je `staff_notification_logs` (`using(private.is_admin(salon_id))`) — klijent tu ne vidi
/// nijedan red. Klijentska politika, push tokeni i slanje dolaze sa taskom 25;
/// `send-push` i `send-reminders` su danas samo `README`.
///
/// Zamka iz task fajla nudi izlaz — „lista obavijesti bez servera je lokalna historija
/// pusheva" — ali i to pretpostavlja da pushevi postoje, a ne postoje.
///
/// Zato ekran ide **sada i prazan**: ćelija trake postoji od taska 18 i do sada je vodila
/// na razvojni `PlaceholderScreen`, što je gore od iskrenog praznog ekrana. Tekst kaže šta
/// korisnik može očekivati i nudi izlaz na „Moji termini", gdje status zahtjeva stvarno
/// stoji. Kad task 25 donese listu, mijenja se **samo tijelo** — ni ruta ni ulaz.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                0,
              ),
              child: Text(
                l10n.notificationsTitle,
                style: theme.textTheme.displaySmall,
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: LucideIcons.bell,
                message: l10n.notificationsEmpty,
                actionLabel: l10n.notificationsEmptyAction,
                onAction: () => context.go(ClientRoute.appointments.path),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
