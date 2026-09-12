import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'date_labels.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 3 — kada (`prototype/ui/screenshots/05-korak3-vrijeme.png`).
///
/// ## Ovdje se ne računa ništa
///
/// Kalendar prikazuje mjesec, a **koji su dani slobodni kaže `get_available_dates`**.
/// Mreža vremena je ono što je vratio `get_available_slots`, bez ijednog filtera iznad
/// toga: nema oduzimanja buffera, nema izbacivanja prošlih vremena, nema
/// `minAdvanceBookingHours` provjere. Sve je to već primijenjeno u funkciji (task 05), i
/// kad bi se ponovilo ovdje, ponovilo bi se pogrešno prvi put kad se pravilo promijeni u
/// migraciji.
///
/// Podjela na "Prijepodne" i "Poslijepodne" je **prikaz, ne pravilo** — granica je podne i
/// služi da mreža od dvadeset chipova ima dvije tačke oslonca.
///
/// ## Dva moda
///
/// `exact_slot` traži dan **i** vrijeme. `date_only` (`docs/05 §4.1`) traži samo dan —
/// vrijeme dodjeljuje salon, pa mreža vremena ne postoji i korak se završava izborom dana.
/// Razlika dolazi iz vertikale kroz `bookingDateOnlyProvider`, ne iz konstante: isti build
/// služi i frizera i ordinaciju.
class SlotStepScreen extends ConsumerStatefulWidget {
  const SlotStepScreen({super.key});

  @override
  ConsumerState<SlotStepScreen> createState() => _SlotStepScreenState();
}

class _SlotStepScreenState extends ConsumerState<SlotStepScreen> {
  /// Koji je mjesec prikazan. Pomjera ga korisnik strelicama; nije dio stanja flowa, jer
  /// listanje mjeseca nije izbor — izbor je dan.
  int _pomakMjeseci = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vertical = verticalOf(ref);
    final flow = ref.watch(bookingFlowProvider);
    final dateOnly = ref.watch(bookingDateOnlyProvider);
    final danas = ref.watch(bookingTodayProvider);

    final serviceId = flow.serviceId;
    // `BookingStepScaffold` već pokriva dolazak bez usluge praznim stanjem; ovdje samo
    // ne smije pući prije nego što ga prikaže.
    if (serviceId == null) {
      return BookingStepScaffold(
        step: BookingStep.slot,
        title: dateOnly ? l10n.bookingPickDate : l10n.bookingPickTime,
        child: const SizedBox.shrink(),
      );
    }

    final spreman = flow.isStepComplete(BookingStep.slot, dateOnly: dateOnly);
    final mjesec = monthOffsetFrom(danas, _pomakMjeseci);
    final raspon = daysFrom(danas, vertical.rules.maxAdvanceBookingDays);

    final dostupniDani = ref.watch(
      availableDatesProvider(
        DateRangeQuery(
          serviceId: serviceId,
          from: raspon.first,
          to: raspon.last,
          employeeId: flow.employeeId,
        ),
      ),
    );

    return BookingStepScaffold(
      step: BookingStep.slot,
      title: dateOnly ? l10n.bookingPickDate : l10n.bookingPickTime,
      subtitle: dateOnly ? l10n.bookingDateOnlyNote : l10n.bookingPickTimeHint,
      cta: AppButton(
        label: spreman
            ? l10n.bookingNext
            : dateOnly
            ? l10n.bookingPickDate
            : l10n.bookingPickTime,
        onPressed: spreman ? () => context.go(BookingStep.details.path) : null,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          _Kalendar(
            mjesec: mjesec,
            dostupni: dostupniDani,
            izabran: flow.date,
            // Unazad se ne ide ispod tekućeg mjeseca — prošli dani ionako nisu
            // dostupni, a prazan mjesec izgleda kao kvar.
            onPrethodni: _pomakMjeseci > 0
                ? () => setState(() => _pomakMjeseci--)
                : null,
            onSljedeci: () => setState(() => _pomakMjeseci++),
            onIzbor: (datum) =>
                ref.read(bookingFlowProvider.notifier).chooseDate(datum),
          ),
          if (!dateOnly) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Vremena(serviceId: serviceId, flow: flow),
          ],
        ],
      ),
    );
  }
}

/// Mjesečna mreža dana. Dani bez slobodnog termina ostaju vidljivi, ali se ne tapaju.
class _Kalendar extends ConsumerWidget {
  const _Kalendar({
    required this.mjesec,
    required this.dostupni,
    required this.izabran,
    required this.onIzbor,
    required this.onPrethodni,
    required this.onSljedeci,
  });

  final LocalDate mjesec;
  final AsyncValue<List<LocalDate>> dostupni;
  final LocalDate? izabran;
  final ValueChanged<LocalDate> onIzbor;
  final VoidCallback? onPrethodni;
  final VoidCallback onSljedeci;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (dostupni.isLoading) {
      return const SkeletonLoader(height: 320);
    }

    if (dostupni.hasError) {
      return EmptyState(
        message: l10n.bookingServicesUnavailable,
        icon: Icons.cloud_off,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(availableDatesProvider),
      );
    }

    final slobodni = (dostupni.valueOrNull ?? const <LocalDate>[]).toSet();
    if (slobodni.isEmpty) {
      return EmptyState(message: l10n.bookingNoDates, icon: Icons.event_busy);
    }

    final daniMjeseca = daysOfMonth(mjesec);

    return CalendarMonth(
      monthLabel: formatMonth(l10n, mjesec),
      weekdayLabels: weekdayInitials(l10n),
      // Prvi u mjesecu mora pasti na svoj dan u sedmici, inače mreža laže o datumu.
      leadingEmptyCells: daniMjeseca.first.weekday - DateTime.monday,
      selectedId: izabran?.format(),
      onSelect: (id) => onIzbor(LocalDate.parse(id)),
      onPreviousMonth: onPrethodni,
      onNextMonth: onSljedeci,
      days: [
        for (final dan in daniMjeseca)
          CalendarDay(
            id: dan.format(),
            label: dan.day.toString(),
            available: slobodni.contains(dan),
          ),
      ],
    );
  }
}

/// Slobodna vremena za izabrani dan, u dvije grupe.
class _Vremena extends ConsumerWidget {
  const _Vremena({required this.serviceId, required this.flow});

  final String serviceId;
  final BookingFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final datum = flow.date;

    if (datum == null) {
      return EmptyState(message: l10n.bookingPickDate, icon: Icons.event);
    }

    final upit = SlotQuery(
      serviceId: serviceId,
      date: datum,
      employeeId: flow.employeeId,
    );
    final slotovi = ref.watch(availableSlotsProvider(upit));

    return switch (slotovi) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        message: l10n.bookingDayFull,
        icon: Icons.event_busy,
      ),
      // `distinctTimes` svodi redove na vremena: kad radnik nije izabran, funkcija
      // vrati isto vrijeme po svakom slobodnom radniku, pa bi korisnik bez ovoga
      // vidio "09:00" tri puta.
      AsyncData(:final value) => _Grupe(
        vremena: value.distinctTimes,
        izabrano: flow.startTime,
        onIzbor: (vrijeme) => ref
            .read(bookingFlowProvider.notifier)
            .chooseSlot(date: datum, startTime: vrijeme),
      ),
      AsyncError() => EmptyState(
        message: l10n.bookingServicesUnavailable,
        icon: Icons.cloud_off,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(availableSlotsProvider(upit)),
      ),
      _ => const SkeletonLoader(height: 200),
    };
  }
}

/// "Prijepodne" i "Poslijepodne", svaka sa svojom mrežom chipova.
class _Grupe extends StatelessWidget {
  const _Grupe({
    required this.vremena,
    required this.izabrano,
    required this.onIzbor,
  });

  final List<LocalTime> vremena;
  final LocalTime? izabrano;
  final ValueChanged<LocalTime> onIzbor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prije = [
      for (final v in vremena)
        if (v.hour < 12) v,
    ];
    final poslije = [
      for (final v in vremena)
        if (v.hour >= 12) v,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prije.isNotEmpty)
          _Grupa(
            naslov: l10n.bookingMorning,
            vremena: prije,
            izabrano: izabrano,
            onIzbor: onIzbor,
          ),
        if (prije.isNotEmpty && poslije.isNotEmpty)
          const SizedBox(height: AppSpacing.xxl),
        if (poslije.isNotEmpty)
          _Grupa(
            naslov: l10n.bookingAfternoon,
            vremena: poslije,
            izabrano: izabrano,
            onIzbor: onIzbor,
          ),
      ],
    );
  }
}

class _Grupa extends StatelessWidget {
  const _Grupa({
    required this.naslov,
    required this.vremena,
    required this.izabrano,
    required this.onIzbor,
  });

  final String naslov;
  final List<LocalTime> vremena;
  final LocalTime? izabrano;
  final ValueChanged<LocalTime> onIzbor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(naslov, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            // Tri po redu na 402 px (`prototype/ui` 5e), a na širem ekranu više — bez
            // fiksnog broja kolona, koji na tabletu razvuče chip preko pola ekrana.
            maxCrossAxisExtent: 130,
            mainAxisExtent: AppSize.timeSlot,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: vremena.length,
          itemBuilder: (context, index) {
            final vrijeme = vremena[index];
            return TimeSlotChip(
              label: vrijeme.format(),
              selected: vrijeme == izabrano,
              onTap: () => onIzbor(vrijeme),
            );
          },
        ),
      ],
    );
  }
}
