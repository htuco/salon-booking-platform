import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_submit_provider.dart';
import 'date_labels.dart';

/// Ekran nakon slanja (`prototype/ui/SPEC.md` 5g).
///
/// **Ne kaže da je termin potvrđen, jer nije.** `book_appointment` uvijek pravi `pending`
/// red — i kad salon radi u `auto` modu, potvrdu dodjeljuje baza, ne ovaj poziv
/// (`docs/01 §18`). Lažno "Potvrđeno!" ovdje je najskuplja moguća greška u proizvodu:
/// korisnik dođe u salon koji ga ne očekuje.
///
/// Konfete slave **poslan zahtjev**, ne potvrdu. Traju jednom i kratko — `AppDuration`
/// drži gornju granicu na 300 ms za prelaze, a animacija koja se vrti u krug pretvara
/// ekran u čekaonicu.
class BookingSuccessScreen extends ConsumerStatefulWidget {
  const BookingSuccessScreen({super.key});

  @override
  ConsumerState<BookingSuccessScreen> createState() =>
      _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends ConsumerState<BookingSuccessScreen> {
  late final ConfettiController _konfete = ConfettiController(
    duration: const Duration(milliseconds: 800),
  )..play();

  @override
  void dispose() {
    _konfete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);
    final appointment = ref.watch(lastBookingProvider);

    final sadrzaj = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.bookingSuccessTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Status je `pending` i tako i piše. `StatusBadge` je ovdje ispravan izbor:
        // status termina je isti u svakom salonu, pa je i boja namjerno brand-neutralna
        // (za razliku od živog statusa na homeu, gdje je fiksna plava preko zlatnog
        // brenda bila greška iz taska 10).
        StatusBadge(label: l10n.bookingStatusPending, tone: StatusTone.warning),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.bookingSuccessBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (appointment != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            '${vertical.terms.appointmentSingular}: '
            '${formatDateWithWeekday(l10n, appointment.date)} · '
            '${appointment.startTime.format()}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: l10n.bookingBackHome,
          onPressed: () {
            // Flow i zapamćeni termin se čiste **na izlasku**, ne pri otvaranju ovog
            // ekrana: `pop` na uređaju bi inače vratio korisnika na prazan sažetak.
            ref.read(bookingFlowProvider.notifier).reset();
            ref.read(lastBookingProvider.notifier).clear();
            context.go(ClientRoute.home.path);
          },
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: sadrzaj
                    .animate()
                    .fadeIn(duration: AppDuration.slow)
                    .slideY(begin: 0.08, end: 0, duration: AppDuration.slow),
              ),
            ),
            ConfettiWidget(
              confettiController: _konfete,
              blastDirection: math.pi / 2,
              shouldLoop: false,
              numberOfParticles: 12,
              gravity: 0.3,
              // Boje iz teme, ne iz palete paketa: konfete u tuđim bojama preko zlatnog
              // brenda izgledaju kao greška u temi, a ne kao slavlje.
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.tertiary,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
