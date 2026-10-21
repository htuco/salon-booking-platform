import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/load_error.dart';
import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/date_labels.dart';
import 'waitlist_providers.dart';

/// „Lista čekanja" iznad predstojećih termina (task 68), svaki upis sa svojim rasponom (task 91).
///
/// Push o oslobođenom mjestu vodi ovdje (`send-push` šalje `route: /appointments`), pa
/// upis ima „Zakaži": booking sa tom uslugom, gdje korisnik bira dan i vrijeme iz liste koju
/// računa baza. Bez upisa sekcija se ne crta — prazna lista čekanja nije vijest.
///
/// **Greška nije prazno stanje** (`LoadError`): upit koji padne crta naslov sekcije i
/// „Pokušaj ponovo", umjesto da sakrije upise za koje korisnik zna da postoje.
class WaitlistSection extends ConsumerWidget {
  const WaitlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stanje = ref.watch(myWaitlistProvider);

    // Greška se crta i kad je stara lista još u kešu: ponovni pokušaj koji opet padne ne
    // smije tiho vratiti stare kartice kao da su istina.
    if (stanje.hasError && !stanje.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.waitlistSectionTitle, style: theme.textTheme.titleMedium),
            LoadError(
              error: stanje.error!,
              onRetry: () => ref.invalidate(myWaitlistProvider),
            ),
          ],
        ),
      );
    }

    final upisi = stanje.valueOrNull ?? const [];
    if (upisi.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.waitlistSectionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final upis in upisi) ...[
            _Upis(upis: upis),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _Upis extends ConsumerWidget {
  const _Upis({required this.upis});

  final WaitlistEntry upis;

  Future<void> _odjavi(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final akcija = waitlistActionProvider(upis.id);
    if (await ref.read(akcija.notifier).leave(upis.id)) return;

    // Rečenica baze ako je dala svoju; inače poruka o odjavi, ne o upisu.
    final greska = ref.read(akcija).error;
    final poruka = greska is ApiError ? greska.displayMessage : null;
    messenger.showSnackBar(
      SnackBar(content: Text(poruka ?? l10n.waitlistLeaveFailed)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final radi = ref.watch(waitlistActionProvider(upis.id)).isLoading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // Ista hairline kartica kao termin, ali bez vremena i statusa: upis nije termin.
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Raspon od jednog dana je dan, kao u tasku 68; duži raspon je „Od 21.10. do
          // 30.10." (task 91). Početak je danas ili kasnije: baza prošle dane ne vraća.
          Text(
            upis.dateFrom == upis.dateTo
                ? formatDateWithWeekday(l10n, upis.dateTo)
                : l10n.waitlistRange(
                    formatDayMonth(upis.dateFrom),
                    formatDayMonth(upis.dateTo),
                  ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [upis.serviceName, ?upis.employeeName].join(' · '),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.waitlistBook,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(
                    Uri(
                      path: ClientRoute.bookService.path,
                      queryParameters: {'serviceId': upis.serviceId},
                    ).toString(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: l10n.waitlistRemove,
                  variant: AppButtonVariant.outline,
                  loading: radi,
                  onPressed: () => _odjavi(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
