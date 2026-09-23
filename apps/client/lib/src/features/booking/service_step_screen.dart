import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 1 — izbor usluge (`prototype/ui/screenshots/03-korak1-usluga.png`).
///
/// **Izbor ne vodi odmah dalje.** Tap označava red, a korak se zaključuje dugmetom
/// "Dalje" na dnu — `SPEC.md`, Interactions: "CTA is disabled until the step's required
/// choice exists". Automatski prelaz bi značio da korisnik koji je pogriješio red mora
/// nazad da se ispravi, i da poređenje dvije usluge traži dva prolaza kroz flow.
///
/// **Čita `?serviceId=` iz rute.** Home ekran vodi na `/book/service?serviceId=<id>` kad
/// se tapne kartica usluge (task 10); bez čitanja tog parametra preselekcija tiho ne radi
/// i korisnik bira istu uslugu dvaput, a ekran pri tome izgleda ispravno.
///
/// Naslov je **doslovno iz handoffa** — "Izaberite uslugu". Barber aplikacija je 1:1 sa
/// `prototype/ui/`; ostale vertikale dobijaju svoj dizajn i svoj copy, pa se akuzativ
/// ("tretman", "pregled") ne rješava ovdje nego tamo.
class ServiceStepScreen extends ConsumerStatefulWidget {
  const ServiceStepScreen({this.preselectedServiceId, super.key});

  /// `serviceId` iz query parametra, ako ga je home proslijedio.
  final String? preselectedServiceId;

  @override
  ConsumerState<ServiceStepScreen> createState() => _ServiceStepScreenState();
}

class _ServiceStepScreenState extends ConsumerState<ServiceStepScreen> {
  @override
  void initState() {
    super.initState();

    final preselektovana = widget.preselectedServiceId;
    if (preselektovana == null || preselektovana.isEmpty) return;

    // Nakon prvog framea: `initState` je prerano za promjenu providera koji slušaju
    // widgeti ovog stabla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).chooseService(preselektovana);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vertical = verticalOf(ref);
    final services = ref.watch(servicesProvider);
    final izabrana = ref.watch(bookingFlowProvider).serviceId;

    return BookingStepScaffold(
      step: BookingStep.service,
      title: l10n.bookingPickServiceTitle,
      subtitle: l10n.bookingPickOneHint,
      // Labela ostaje "Dalje" i kad je dugme onemoguceno — handoff mijenja tekst samo na
      // koraku sa terminima, gdje izbor nije ocigledan iz sadrzaja ekrana. Ovdje bi
      // promjena teksta samo ponovila naslov.
      cta: AppButton(
        label: l10n.bookingNext,
        onPressed: izabrana == null
            ? null
            : () => context.go(BookingStep.employee.path),
      ),
      child: switch (services) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          message: l10n.bookingNoServices,
          icon: LucideIcons.calendarX,
          actionLabel: l10n.bookingNoServicesAction,
          onAction: () => context.go(ClientRoute.home.path),
        ),
        AsyncData(:final value) => _Lista(
          services: value,
          izabranaId: izabrana,
          prikaziCijene: vertical.features.prices,
          onIzbor: (service) =>
              ref.read(bookingFlowProvider.notifier).chooseService(service.id),
        ),
        AsyncError() => EmptyState(
          message: l10n.bookingServicesUnavailable,
          icon: LucideIcons.cloudOff,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(servicesProvider),
        ),
        _ => const _Kostur(),
      },
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.services,
    required this.izabranaId,
    required this.prikaziCijene,
    required this.onIzbor,
  });

  final List<Service> services;
  final String? izabranaId;
  final bool prikaziCijene;
  final ValueChanged<Service> onIzbor;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final service = services[index];
        return SelectableRow(
          title: service.name,
          subtitle: formatDurationLong(service.durationMinutes),
          // Prazan okvir kad fotografije nema je **predviđeno stanje**, ne rupa: salon
          // bez slika mora raditi od prvog dana (task 22). `PhotoFrame` ga crta sam.
          imageUrl: service.imageUrl,
          trailingText: prikaziCijene ? formatPrice(service.price) : null,
          selected: service.id == izabranaId,
          onTap: () => onIzbor(service),
        );
      },
    );
  }
}

class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const SkeletonLoader(height: 104),
    );
  }
}
