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

/// Korak 4 — sažetak i slanje (`prototype/ui/SPEC.md` 5f).
///
/// ## Prijava se traži ovdje, i nigdje ranije
///
/// `docs/06 §1.1`: cijeli flow je javan do ovog trenutka. Guard na `/book/*` bi značio da
/// korisnik mora imati nalog da bi vidio cijene — odluka koja se ne otvara. Zato ovaj
/// ekran ima dva CTA stanja: bez identiteta vodi na prijavu, sa identitetom šalje zahtjev.
///
/// **Broj telefona se ne traži** (`docs/06 §3.1`) — push zamjenjuje i poziv i SMS. Polje
/// za telefon ovdje je greška u razumijevanju flowa, ne propust. `prototype/ui/SPEC.md` 5f
/// crta "phone sign-in"; gdje se SPEC i `docs/06` ne slažu oko *flowa*, docs je jači —
/// SPEC ostaje izvor istine za oblik.
///
/// ## `409` je ishod, ne kvar
///
/// Slot može otići između prikaza i potvrde. Tada se ne prikazuje generička greška: poruka
/// kaže šta se desilo, lista slotova se invalidira (u `BookingSubmitNotifier`) i korisnik
/// se vraća na korak 3 sa **osvježenom** listom i zadržanim danom.
class DetailsStepScreen extends ConsumerStatefulWidget {
  const DetailsStepScreen({super.key});

  @override
  ConsumerState<DetailsStepScreen> createState() => _DetailsStepScreenState();
}

class _DetailsStepScreenState extends ConsumerState<DetailsStepScreen> {
  late final TextEditingController _napomena = TextEditingController(
    text: ref.read(bookingFlowProvider).note ?? '',
  );

  @override
  void dispose() {
    _napomena.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);
    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);
    final customerId = ref.watch(bookingCustomerIdProvider);
    final slanje = ref.watch(bookingSubmitProvider);

    final prijavljen = customerId != null;

    return BookingStepScaffold(
      step: BookingStep.details,
      title: l10n.bookingSummaryTitle,
      subtitle: prijavljen ? null : l10n.bookingLoginRequired,
      cta: AppButton(
        label: prijavljen ? l10n.bookingSubmit : l10n.bookingLoginCta,
        loading: slanje.isLoading,
        onPressed: prijavljen
            ? _posalji
            : () => context.go(ClientRoute.login.path),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _Sazetak(flow: flow, dateOnly: dateOnly),
          const SizedBox(height: AppSpacing.xl),
          Text(vertical.terms.noteLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _napomena,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.bookingNoteOptional),
            // Napomena se pamti pri svakoj promjeni, ne na CTA: korisnik koji se vrati
            // korak nazad da provjeri termin ne smije izgubiti ono što je napisao.
            onChanged: (tekst) =>
                ref.read(bookingFlowProvider.notifier).setNote(tekst),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Zahtjev, ne rezervacija (`docs/01 §18`). Ovo stoji **prije** slanja, da
          // očekivanje bude postavljeno prije pritiska, a ne tek na success ekranu.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.bookingSuccessBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _posalji() async {
    final l10n = AppLocalizations.of(context);
    // Oba se uzimaju **prije** `await`-a: nakon njega je `context` možda već otišao sa
    // ekrana (uspjeh navigira), a `ScaffoldMessenger.of` bi tada gađao mrtav element.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final uspjeh = await ref.read(bookingSubmitProvider.notifier).submit();
    if (!mounted) return;

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
    // ostavljaju korisnika na sažetku — tamo je dugme koje može pritisnuti ponovo.
    if (greska is ConflictError) {
      router.go(BookingStep.slot.path);
    }
  }
}

/// Šta je korisnik izabrao — zadnja prilika da to vidi prije slanja.
class _Sazetak extends ConsumerWidget {
  const _Sazetak({required this.flow, required this.dateOnly});

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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Red(
            labela: vertical.terms.serviceSingular,
            vrijednost: usluga?.name ?? '—',
            dodatak: usluga == null
                ? null
                : [
                    formatDuration(usluga.durationMinutes),
                    if (vertical.features.prices) formatPrice(usluga.price),
                  ].join(' · '),
          ),
          const Divider(height: AppSpacing.xl),
          _Red(
            labela: vertical.terms.staffSingular,
            // "Bilo ko od nas" je izbor, ne izostanak izbora — zato ista labela, a ne
            // prazno polje (v. `BookingFlowState.employeeChosen`).
            vrijednost: radnik?.name ?? l10n.bookingAnyStaff,
          ),
          const Divider(height: AppSpacing.xl),
          _Red(
            labela: vertical.terms.appointmentSingular,
            vrijednost: datum == null
                ? '—'
                : formatDateWithWeekday(l10n, datum),
            dodatak: dateOnly
                ? l10n.bookingDateOnlyNote
                : flow.startTime?.format(),
          ),
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

class _Red extends StatelessWidget {
  const _Red({required this.labela, required this.vrijednost, this.dodatak});

  final String labela;
  final String vrijednost;
  final String? dodatak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            labela,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                vrijednost,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              ),
              if (dodatak != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dodatak!,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
