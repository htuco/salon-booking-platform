import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../features/booking/date_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import 'appointment_labels.dart';
import 'appointments_provider.dart';

/// `/appointments` — „Moji termini", `prototype/ui/SPEC.md` **5h**.
///
/// Dva taba (Predstojeći / Prošli), kartica po terminu sa statusom, i otkazivanje kroz
/// modal **5p**. Success ekran iz taska 11 konačno ima gdje da vodi.
///
/// ## Granica između tabova nije u upitu
///
/// Repozitorij vraća sve termine; razvrstavanje radi `splitAppointments`, jer „prošlo"
/// zavisi od trenutka gledanja — v. `appointments_provider.dart`. Uz to **zatvoren termin
/// ide u „prošle" bez obzira na datum**: otkazan termin za sljedeću sedmicu nije nešto na
/// šta korisnik dolazi.
///
/// ## Rok za otkazivanje se ovdje samo prikazuje
///
/// Odlučuje `cancel_appointment` u bazi, iz `salon_settings.min_cancel_hours`. Ekran
/// unaprijed onemogući dugme da korisnik ne dobije grešku na nešto što se vidjelo da neće
/// proći — ali kad se njih dvoje raziđu, baza je u pravu i njena poruka izlazi na ekran.
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Realtime veza može biti suspendovana dok je aplikacija u pozadini. Povratak na
    // ekran zato uvijek ponovo čita iz baze, čak i ako FCM/Realtime događaj nije uhvaćen.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(myAppointmentsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prijavljen = ref.watch(isSignedInProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              // **Bez strelice nazad.** Od taska 18 je ovo korijen taba Termini, ne
              // pushed ekran — strelica bi vodila na Početnu, koja je susjedna ćelija
              // u traci ispod, i time tvrdila da postoji istorija koje nema.
              child: Text(
                l10n.appointmentsTitle,
                style: theme.textTheme.displaySmall,
              ),
            ),
            Expanded(
              child: prijavljen
                  ? const _Tabovi()
                  : _Prazno(
                      poruka: l10n.appointmentsSignedOut,
                      akcija: l10n.bookingContinueEmail,
                      onAkcija: () => context.go(ClientRoute.login.path),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabovi extends ConsumerWidget {
  const _Tabovi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final podjela = ref.watch(splitAppointmentsProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            // Hairline ispod cijele širine, kao i svuda u sistemu — ne Material indikator
            // sa zaobljenim rubom.
            dividerColor: theme.colorScheme.outline,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: l10n.appointmentsUpcoming),
              Tab(text: l10n.appointmentsPast),
            ],
          ),
          Expanded(
            child: switch (podjela) {
              // Skeleton, ne spinner — pravilo koje je postavio prvi ekran (task 10).
              AsyncLoading() => const Padding(
                padding: EdgeInsets.all(AppSpacing.gutter),
                child: Column(
                  children: [
                    SkeletonLoader(height: 120),
                    SizedBox(height: AppSpacing.md),
                    SkeletonLoader(height: 120),
                  ],
                ),
              ),
              AsyncError(:final error) => _Greska(error: error),
              AsyncValue(:final value?) => TabBarView(
                children: [
                  _Lista(
                    termini: value.upcoming,
                    prazno: l10n.appointmentsEmptyUpcoming,
                  ),
                  _Lista(
                    termini: value.past,
                    prazno: l10n.appointmentsEmptyPast,
                    zatvoreni: true,
                  ),
                ],
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({
    required this.termini,
    required this.prazno,
    this.zatvoreni = false,
  });

  final List<Appointment> termini;
  final String prazno;

  /// Tab „Prošli" ne nudi booking iz praznog stanja — prazno je tamo očekivano.
  final bool zatvoreni;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    Future<void> osvjezi() async {
      ref.invalidate(myAppointmentsProvider);
      await ref.read(myAppointmentsProvider.future);
    }

    if (termini.isEmpty) {
      return AppRefresh(
        onRefresh: osvjezi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: _Prazno(
                poruka: prazno,
                akcija: zatvoreni ? null : l10n.appointmentsBookCta,
                onAkcija: zatvoreni
                    ? null
                    : () => context.go(ClientRoute.bookService.path),
              ),
            ),
          ],
        ),
      );
    }

    return AppRefresh(
      onRefresh: osvjezi,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        itemCount: termini.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) => _Kartica(appointment: termini[i]),
      ),
    );
  }
}

/// Kartica termina — vrijeme je najveći element, kao i na koraku 4.
class _Kartica extends ConsumerWidget {
  const _Kartica({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vertical = verticalOf(ref);

    final usluge = ref.watch(servicesProvider).valueOrNull;
    final usluga = usluge
        ?.where((s) => s.id == appointment.serviceId)
        .firstOrNull;

    final now = ref.watch(appointmentsNowProvider);
    final rok = ref.watch(minCancelHoursProvider);
    final smijeOtkazati = canCancel(appointment, now: now, minCancelHours: rok);
    final otkazivanje = ref.watch(cancelAppointmentProvider(appointment.id));
    final napomena = cancelledByNote(l10n, appointment);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                appointment.startTime.format(),
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  formatDateWithWeekday(l10n, appointment.date),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  usluga?.name ?? '—',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              StatusBadge(
                label: statusLabel(l10n, appointment.status),
                tone: statusTone(appointment.status),
              ),
            ],
          ),
          if (usluga != null && vertical.features.prices) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatDurationLong(usluga.durationMinutes)} · '
              '${formatPrice(usluga.price)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (appointment.employeeName case final name?
              when name.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(name, style: theme.textTheme.bodyMedium),
          ],
          if (napomena != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(napomena, style: theme.textTheme.bodySmall),
          ],
          if (!appointment.status.isClosed) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.appointmentCancel,
              variant: AppButtonVariant.outline,
              loading: otkazivanje.isLoading,
              onPressed: smijeOtkazati ? () => _otkazi(context, ref) : null,
            ),
            if (!smijeOtkazati) ...[
              const SizedBox(height: AppSpacing.sm),
              // Onemogućeno dugme bez objašnjenja izgleda kao kvar. Rok dolazi iz
              // vertikale, pa piše tačan broj sati ovog salona.
              Text(
                l10n.appointmentCancelDeadline(rok),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _otkazi(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final potvrdio = await AppDialog.show(
      context,
      dialog: AppDialog(
        kicker: l10n.appointmentCancelKicker,
        title: l10n.appointmentCancelTitle,
        message: l10n.appointmentCancelBody,
        confirmLabel: l10n.appointmentCancelConfirm,
        cancelLabel: l10n.appointmentCancelKeep,
      ),
    );

    // `null` (dodir izvan dijaloga, sistemski „nazad") i `false` oba znače odustajanje.
    if (potvrdio != true) return;

    final uspjeh = await ref
        .read(cancelAppointmentProvider(appointment.id).notifier)
        .cancel();

    if (uspjeh) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.appointmentCancelled)),
      );
      return;
    }

    final greska = ref.read(cancelAppointmentProvider(appointment.id)).error;
    messenger.showSnackBar(SnackBar(content: Text(_poruka(l10n, greska))));
  }

  /// Poruka po tipu greške. Rok i završen termin traže različite akcije korisnika.
  String _poruka(AppLocalizations l10n, Object? greska) => switch (greska) {
    // `PT403` iz `cancel_appointment` stiže kao `NotFoundError` — `mapError` namjerno ne
    // razlikuje „zabranjeno" od „ne postoji" (v. `api_error.dart`). Na ovom ekranu
    // termin sigurno postoji, jer je upravo prikazan, pa je jedini preostali razlog rok.
    NotFoundError() => l10n.appointmentCancelTooLate,
    ConflictError() => l10n.genericError,
    NetworkError() => l10n.noConnection,
    _ => l10n.genericError,
  };
}

class _Prazno extends StatelessWidget {
  const _Prazno({required this.poruka, this.akcija, this.onAkcija});

  final String poruka;
  final String? akcija;
  final VoidCallback? onAkcija;

  @override
  Widget build(BuildContext context) => EmptyState(
    message: poruka,
    icon: LucideIcons.calendarDays,
    actionLabel: akcija,
    onAction: onAkcija,
  );
}

class _Greska extends StatelessWidget {
  const _Greska({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EmptyState(
      message: error is NetworkError ? l10n.noConnection : l10n.genericError,
      icon: LucideIcons.circleAlert,
    );
  }
}
