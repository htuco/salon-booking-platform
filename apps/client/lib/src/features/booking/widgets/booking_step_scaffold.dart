import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../booking_flow_provider.dart';
import '../booking_flow_state.dart';

/// Zajednička kičma sva četiri koraka — `prototype/ui/screenshots/03…06`.
///
/// Zaglavlje je **"← Nazad" lijevo, "Korak N od 4" desno**, pa traka od četiri segmenta
/// preko pune širine. Nije `AppBar` sa centriranim naslovom: handoff traži riječ uz
/// strelicu (na dodir je to veća meta od same ikone), a naslov koraka je **serif naslov u
/// sadržaju**, ne u baru.
///
/// Postoji da chrome koraka bude napisan jednom. Kad svaki ekran nosi svoje zaglavlje,
/// razlike se nakupe tiho: treći korak dobije traku 4 px niže, četvrti izgubi `SafeArea`
/// na dnu, i to se vidi tek na uređaju sa zarezom.
///
/// **Guard je ovdje, ne u routeru.** `go_router` redirect bi morao čitati stanje flowa iz
/// providera pri svakoj promjeni rute i vraćati korisnika usred navigacije — a stanje je
/// `autoDispose` i u tom trenutku može biti prazno. Umjesto toga ekran koji je otvoren bez
/// prethodnog izbora (deep link na `/book/slot`) prikaže prazno stanje sa izlazom na prvi
/// nepopunjen korak. Korisnik vidi šta fali, umjesto da ga ekran nečujno premota.
class BookingStepScaffold extends ConsumerWidget {
  const BookingStepScaffold({
    required this.step,
    required this.title,
    required this.child,
    this.subtitle,
    this.cta,
    super.key,
  });

  final BookingStep step;

  /// Serif naslov koraka. Dolazi iz `vertical.terms` ili `.arb`-a, nikad kao literal.
  final String title;
  final String? subtitle;

  /// Sadržaj koraka. Skrolanje je na njemu — liste su različite dužine, a kalendar mora
  /// ostati na vrhu dok se slotovi skrolaju.
  final Widget child;

  /// Dugme na dnu, van skrola. `SPEC.md`: CTA je zalijepljen za dno i onemogućen dok
  /// izbor ne postoji.
  final Widget? cta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);

    final nedostaje = _prviNedostajuciPrije(flow, dateOnly);
    final dugme = cta;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Zaglavlje(
              step: step,
              backLabel: l10n.bookingBack,
              stepLabel: l10n.bookingStepOf(
                step.index + 1,
                BookingStep.values.length,
              ),
              onBack: () => _nazad(context),
            ),
            if (nedostaje != null)
              Expanded(
                child: EmptyState(
                  message: l10n.bookingMissingStep,
                  icon: Icons.arrow_back,
                  actionLabel: l10n.bookingRestart,
                  onAction: () => context.go(nedostaje.path),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.displaySmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(subtitle!, style: theme.textTheme.bodyLarge),
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
            if (dugme != null && nedostaje == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: dugme,
              ),
          ],
        ),
      ),
    );
  }

  /// Prvi nepopunjen korak **ispred** ovog, ili `null` kad je put do ovdje čist.
  ///
  /// Namjerno gleda samo korake prije trenutnog: korak koji je sam po sebi nepopunjen je
  /// normalno stanje — korisnik ga upravo popunjava.
  BookingStep? _prviNedostajuciPrije(BookingFlowState flow, bool dateOnly) {
    for (final prethodni in BookingStep.values) {
      if (prethodni.index >= step.index) return null;
      if (!flow.isStepComplete(prethodni, dateOnly: dateOnly)) return prethodni;
    }
    return null;
  }

  /// Nazad jedan korak, a sa prvog van flowa.
  ///
  /// Izbor se **ne briše** pri povratku: `SPEC.md` traži da korak zapamti izbor, a
  /// brisanje pri svakom povratku bi značilo da korisnik koji provjerava cijenu usluge
  /// izgubi već izabran termin.
  void _nazad(BuildContext context) {
    final prethodni = step.index == 0
        ? null
        : BookingStep.values[step.index - 1];
    context.go(prethodni?.path ?? ClientRoute.home.path);
  }
}

/// "← Nazad" lijevo, "Korak N od 4" desno, traka napretka ispod.
class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje({
    required this.step,
    required this.backLabel,
    required this.stepLabel,
    required this.onBack,
  });

  final BookingStep step;
  final String backLabel;
  final String stepLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Strelica i riječ su jedna meta. Sama strelica je 22 px — ispod donje
              // granice iz `docs/02 §14`, i promaši se u hodu.
              InkWell(
                onTap: onBack,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Text(backLabel, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                stepLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          StepProgressBar(
            totalSteps: BookingStep.values.length,
            currentStep: step.index + 1,
            semanticsLabel: stepLabel,
          ),
        ],
      ),
    );
  }
}
