import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';
import 'waitlist_providers.dart';

/// Pun dan u koraku 3 (task 68): umjesto mreže vremena, upis na listu čekanja.
///
/// Upis je za uslugu, dan i radnika **iz flowa** — „Bilo ko" je upis bez radnika. Upis ne
/// drži mjesto (ADR-0031), pa tekst to kaže, umjesto da obeća termin.
///
/// Neprijavljen korisnik ide na prijavu i vraća se ovdje (`?from=`); flow ostaje živ jer je
/// ovaj ekran i dalje na steku ispod prijave.
class WaitlistDayPanel extends ConsumerStatefulWidget {
  const WaitlistDayPanel({
    required this.serviceId,
    required this.date,
    this.employeeId,
    super.key,
  });

  final String serviceId;
  final LocalDate date;
  final String? employeeId;

  @override
  ConsumerState<WaitlistDayPanel> createState() => _WaitlistDayPanelState();
}

class _WaitlistDayPanelState extends ConsumerState<WaitlistDayPanel> {
  bool _radi = false;

  WaitlistEntry? _moj(List<WaitlistEntry> upisi) => upisi
      .where(
        (u) =>
            u.serviceId == widget.serviceId &&
            u.date == widget.date &&
            u.employeeId == widget.employeeId,
      )
      .firstOrNull;

  Future<void> _izvrsi(Future<void> Function() akcija) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _radi = true);
    try {
      await akcija();
      ref.invalidate(myWaitlistProvider);
      await ref.read(myWaitlistProvider.future);
    } on ApiError catch (greska) {
      // Rečenica baze (`PT400` pun dan, `PT429` tri upisa) ide na ekran; ostalo ne.
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
    final prijavljen = ref.watch(isSignedInProvider);
    final upisi = ref.watch(myWaitlistProvider);
    final moj = _moj(upisi.valueOrNull ?? const []);
    final repo = ref.read(waitlistRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            moj == null ? LucideIcons.calendarX : LucideIcons.bellRing,
            size: AppSize.iconEmptyState,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            moj == null ? l10n.waitlistDayFull : l10n.waitlistJoined,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (moj == null)
            AppButton(
              label: l10n.waitlistJoin,
              variant: AppButtonVariant.secondary,
              icon: LucideIcons.bell,
              loading: _radi || (prijavljen && upisi.isLoading),
              onPressed: !prijavljen
                  ? () => context.push(
                      Uri(
                        path: ClientRoute.login.path,
                        queryParameters: {'from': ClientRoute.bookSlot.path},
                      ).toString(),
                    )
                  : () => _izvrsi(
                      () => repo.join(
                        serviceId: widget.serviceId,
                        date: widget.date,
                        employeeId: widget.employeeId,
                      ),
                    ),
            )
          else
            AppButton(
              label: l10n.waitlistLeave,
              variant: AppButtonVariant.outline,
              loading: _radi,
              onPressed: () => _izvrsi(() => repo.leave(moj.id)),
            ),
        ],
      ),
    );
  }
}
