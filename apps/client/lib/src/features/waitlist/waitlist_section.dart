import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../booking/date_labels.dart';
import 'waitlist_providers.dart';

/// „Lista čekanja" iznad predstojećih termina (task 68).
///
/// Push o oslobođenom mjestu vodi ovdje (`send-push` šalje `route: /appointments`), pa
/// upis ima „Zakaži": booking sa tom uslugom, gdje korisnik bira dan i vrijeme iz liste koju
/// računa baza. Bez upisa sekcija se ne crta — prazna lista čekanja nije vijest.
class WaitlistSection extends ConsumerWidget {
  const WaitlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final upisi = ref.watch(myWaitlistProvider).valueOrNull ?? const [];
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

class _Upis extends ConsumerStatefulWidget {
  const _Upis({required this.upis});

  final WaitlistEntry upis;

  @override
  ConsumerState<_Upis> createState() => _UpisState();
}

class _UpisState extends ConsumerState<_Upis> {
  bool _radi = false;

  Future<void> _odjavi() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _radi = true);
    try {
      await ref.read(waitlistRepositoryProvider).leave(widget.upis.id);
      ref.invalidate(myWaitlistProvider);
    } on ApiError catch (greska) {
      messenger.showSnackBar(
        SnackBar(content: Text(greska.displayMessage ?? l10n.waitlistFailed)),
      );
    } finally {
      if (mounted) setState(() => _radi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final upis = widget.upis;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // Ista hairline kartica kao termin, ali bez vremena i statusa: upis nije termin.
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDateWithWeekday(l10n, upis.date),
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
                  loading: _radi,
                  onPressed: _odjavi,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
