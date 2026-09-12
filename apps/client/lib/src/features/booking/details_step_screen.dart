import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'booking_identity.dart';
import 'booking_submit_provider.dart';
import 'date_labels.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 4 — prijava (`prototype/ui/screenshots/06-korak4-prijava.png`).
///
/// ## Ovo je ekran prijave, ne ekran sažetka
///
/// Handoff ga zove "Još jedan korak": kartica **"Čuvamo vam 14:30"** koja drži izbor na
/// oku, pa tri načina prijave i pravna napomena. Nema polja za napomenu i **nema polja za
/// telefon** (`docs/06 §3.1` — push zamjenjuje i poziv i SMS).
///
/// `docs/06 §1.1`: cijeli flow je javan do ovog trenutka. Guard na `/book/*` bi značio da
/// korisnik mora imati nalog da bi vidio cijene — odluka koja se ne otvara.
///
/// ## Prijava još ne postoji
///
/// Supabase Auth dolazi u Sprintu 2. Do tada dugmad vode na `/auth/login`, koji je
/// placeholder, a `bookingCustomerIdProvider` je uvijek `null` u pravoj app-i. Kad
/// identitet postoji (test, demo), isti ekran šalje zahtjev — struktura poziva je već
/// ista, mijenja se samo ko je popunio `customerId`.
///
/// ## `409` je ishod, ne kvar
///
/// Slot može otići između prikaza i potvrde. Tada se ne prikazuje generička greška: poruka
/// kaže šta se desilo, lista slotova se invalidira (u `BookingSubmitNotifier`) i korisnik
/// se vraća na korak 3 sa **osvježenom** listom i zadržanim danom.
class DetailsStepScreen extends ConsumerWidget {
  const DetailsStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);
    final customerId = ref.watch(bookingCustomerIdProvider);
    final slanje = ref.watch(bookingSubmitProvider);

    final prijavljen = customerId != null;

    return BookingStepScaffold(
      step: BookingStep.details,
      title: l10n.bookingLastStepTitle,
      subtitle: l10n.bookingLastStepHint,
      // Kad je identitet poznat, zadnji korak je jedno dugme koje šalje zahtjev.
      // Dok nije, šalje se kroz prijavu — ista akcija, drugi put do nje.
      cta: prijavljen
          ? AppButton(
              label: l10n.bookingSubmit,
              loading: slanje.isLoading,
              onPressed: () => _posalji(context, ref),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          _KarticaTermina(flow: flow, dateOnly: dateOnly),
          if (!prijavljen) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Prijava(onTap: () => context.go(ClientRoute.login.path)),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.bookingLegalNotice, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Future<void> _posalji(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Oba se uzimaju **prije** `await`-a: nakon njega je `context` možda već otišao sa
    // ekrana (uspjeh navigira), a `ScaffoldMessenger.of` bi tada gađao mrtav element.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final uspjeh = await ref.read(bookingSubmitProvider.notifier).submit();

    if (uspjeh) {
      router.go(ClientRoute.bookSuccess.path);
      return;
    }

    final greska = ref.read(bookingSubmitProvider).error;
    final poruka = switch (greska) {
      ConflictError() => l10n.bookingConflict,
      NetworkError() => l10n.noConnection,
      _ => l10n.genericError,
    };

    messenger.showSnackBar(SnackBar(content: Text(poruka)));

    // Konflikt vraća na izbor termina, gdje je lista već invalidirana. Ostale greške
    // ostavljaju korisnika ovdje — tamo je dugme koje može pritisnuti ponovo.
    if (greska is ConflictError) {
      router.go(BookingStep.slot.path);
    }
  }
}

/// "Čuvamo vam — 14:30, srijeda 20.05. — Fade šišanje kod Emira".
///
/// Vrijeme je najveći element na ekranu i stoji u serifu: to je jedini podatak zbog kojeg
/// korisnik ovdje zastane prije nego što se prijavi.
class _KarticaTermina extends ConsumerWidget {
  const _KarticaTermina({required this.flow, required this.dateOnly});

  final BookingFlowState flow;
  final bool dateOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);

    final services = ref.watch(servicesProvider).valueOrNull;
    final employees = ref.watch(employeesProvider).valueOrNull;

    final usluga = _nadji(services, flow.serviceId, (s) => s.id);
    final radnik = _nadji(employees, flow.employeeId, (e) => e.id);
    final datum = flow.date;

    final opis = [
      if (usluga != null) usluga.name,
      if (radnik != null)
        '${vertical.terms.staffSingular.toLowerCase()}: ${radnik.name}'
      else
        l10n.bookingAnyStaff.toLowerCase(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bookingHoldingFor, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (!dateOnly && flow.startTime != null) ...[
                Text(
                  flow.startTime!.format(),
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  datum == null ? '—' : formatDateWithWeekday(l10n, datum),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (dateOnly) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.bookingDateOnlyNote, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(opis, style: theme.textTheme.bodyMedium),
          if (usluga != null && vertical.features.prices) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatDurationLong(usluga.durationMinutes)} · '
              '${formatPrice(usluga.price)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  /// Nađi po `id`-u, bez `firstWhere` koji baca kad nema pogotka.
  T? _nadji<T>(List<T>? lista, String? id, String Function(T) idOf) {
    if (lista == null || id == null) return null;
    for (final stavka in lista) {
      if (idOf(stavka) == id) return stavka;
    }
    return null;
  }
}

/// Tri načina prijave iz `docs/06 §1.2`, redoslijedom iz handoffa.
///
/// **Telefona nema i neće ga biti** (`docs/06 §3.1`). Apple je prvi jer je na iOS-u
/// obavezan kad postoji ijedan drugi social provider (`docs/06 §7.2`).
class _Prijava extends StatelessWidget {
  const _Prijava({required this.onTap});

  /// Do Sprinta 2 sva tri dugmeta vode na isti placeholder ekran prijave.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        AppButton(
          label: l10n.bookingContinueApple,
          icon: Icons.apple,
          onPressed: onTap,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.bookingContinueGoogle,
          variant: AppButtonVariant.outline,
          onPressed: onTap,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l10n.bookingContinueEmail,
          icon: Icons.alternate_email,
          variant: AppButtonVariant.outline,
          onPressed: onTap,
        ),
      ],
    );
  }
}
