import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../booking_flow_provider.dart';
import '../booking_flow_state.dart';

/// Zajednička kičma sva četiri koraka — nazad, "Korak N od 4", traka napretka, CTA.
///
/// Postoji da chrome koraka bude napisan jednom. Kad svaki ekran nosi svoj `AppBar` i svoj
/// CTA, razlike se nakupe tiho: treći korak dobije dugme 4 px niže, četvrti izgubi
/// `SafeArea` na dnu, i to se vidi tek na uređaju sa zarezom.
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
  final String title;
  final String? subtitle;

  /// Sadržaj koraka. Skrolanje je na njemu — liste su različite dužine, a traka datuma
  /// mora ostati fiksna dok se slotovi skrolaju.
  final Widget child;

  /// Dugme na dnu. `null` na koracima gdje izbor sam vodi dalje (usluga, radnik).
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => _nazad(context)),
        title: Text(
          l10n.bookingStepOf(step.index + 1, BookingStep.values.length),
          style: theme.textTheme.labelLarge,
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: StepProgressBar(
              totalSteps: BookingStep.values.length,
              currentStep: step.index + 1,
              semanticsLabel: l10n.bookingStepOf(
                step.index + 1,
                BookingStep.values.length,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: nedostaje != null
            ? EmptyState(
                message: l10n.bookingMissingStep,
                icon: Icons.arrow_back,
                actionLabel: l10n.bookingRestart,
                onAction: () => context.go(nedostaje.path),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
      ),
      bottomNavigationBar: dugme == null || nedostaje != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: dugme,
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
  /// Izbor se **ne briše** pri povratku: `docs/02 §14` traži da korak zapamti izbor, a
  /// brisanje pri svakom povratku bi značilo da korisnik koji provjerava cijenu usluge
  /// izgubi već izabran termin.
  void _nazad(BuildContext context) {
    final prethodni = step.index == 0
        ? null
        : BookingStep.values[step.index - 1];
    if (prethodni == null) {
      context.go(ClientRoute.home.path);
      return;
    }
    context.go(prethodni.path);
  }
}
