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

/// Korak 3 — kada (`prototype/ui/SPEC.md` 5e).
///
/// ## Ovdje se ne računa ništa
///
/// Traka datuma prikazuje raspon koji dozvoljava `maxAdvanceBookingDays`, a **koji su od
/// tih dana slobodni kaže `get_available_dates`**. Mreža vremena je ono što je vratio
/// `get_available_slots`, bez ijednog filtera iznad toga: nema oduzimanja buffera, nema
/// izbacivanja prošlih vremena, nema `minAdvanceBookingHours` provjere. Sve je to već
/// primijenjeno u funkciji (task 05), i kad bi se ponovilo ovdje, ponovilo bi se pogrešno
/// prvi put kad se pravilo promijeni u migraciji.
///
/// ## Dva moda
///
/// `exact_slot` traži dan **i** vrijeme. `date_only` (`docs/05 §4.1`) traži samo dan —
/// vrijeme dodjeljuje salon, pa mreža vremena ne postoji i korak se završava izborom dana.
/// Razlika dolazi iz vertikale kroz `bookingDateOnlyProvider`, ne iz konstante: isti build
/// služi i frizera i ordinaciju.
class SlotStepScreen extends ConsumerWidget {
  const SlotStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      subtitle: dateOnly ? l10n.bookingDateOnlyNote : null,
      // Labela dugmeta govori šta fali dok fali, a šta radi kad ne fali — `SPEC.md`,
      // Interactions: "CTA is disabled until the step's required choice exists".
      // Onemogućeno dugme bez objašnjenja je najčešći način da korisnik zapne na koraku.
      cta: AppButton(
        label: spreman
            ? l10n.bookingContinue
            : dateOnly
            ? l10n.bookingPickDate
            : l10n.bookingPickTime,
        onPressed: spreman ? () => context.go(BookingStep.details.path) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrakaDatuma(
            dani: raspon,
            dostupni: dostupniDani,
            izabran: flow.date,
            onIzbor: (datum) =>
                ref.read(bookingFlowProvider.notifier).chooseDate(datum),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!dateOnly)
            Expanded(
              child: _Vremena(serviceId: serviceId, flow: flow),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

/// Traka dana. Dani bez slobodnog termina ostaju vidljivi, ali se ne mogu tapnuti.
class _TrakaDatuma extends ConsumerWidget {
  const _TrakaDatuma({
    required this.dani,
    required this.dostupni,
    required this.izabran,
    required this.onIzbor,
  });

  final List<LocalDate> dani;
  final AsyncValue<List<LocalDate>> dostupni;
  final LocalDate? izabran;
  final ValueChanged<LocalDate> onIzbor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (dostupni.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: SkeletonLoader(height: 76, radius: AppRadius.md),
      );
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

    return DateStrip(
      selectedId: izabran?.format(),
      onSelect: (id) => onIzbor(LocalDate.parse(id)),
      days: [
        for (final dan in dani)
          DateStripDay(
            id: dan.format(),
            weekdayLabel: weekdayShort(l10n, dan.weekday),
            dayLabel: dan.day.toString(),
            available: slobodni.contains(dan),
          ),
      ],
    );
  }
}

/// Mreža slobodnih vremena za izabrani dan.
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
      AsyncData(:final value) => _Mreza(
        // `distinctTimes` svodi redove na vremena: kad radnik nije izabran, funkcija
        // vrati isto vrijeme po svakom slobodnom radniku, pa bi korisnik bez ovoga
        // vidio "09:00" tri puta.
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
      _ => const _KosturVremena(),
    };
  }
}

class _Mreza extends StatelessWidget {
  const _Mreza({
    required this.vremena,
    required this.izabrano,
    required this.onIzbor,
  });

  final List<LocalTime> vremena;
  final LocalTime? izabrano;
  final ValueChanged<LocalTime> onIzbor;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // Četiri po redu na 390 px (`docs/02 §14`), a na širem ekranu više — bez fiksnog
        // broja kolona, koji na tabletu razvuče chip preko pola ekrana.
        maxCrossAxisExtent: 96,
        mainAxisExtent: AppSize.touchTarget,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
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
    );
  }
}

class _KosturVremena extends StatelessWidget {
  const _KosturVremena();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisExtent: AppSize.touchTarget,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: 8,
      itemBuilder: (_, _) => const SkeletonLoader(height: AppSize.touchTarget),
    );
  }
}
