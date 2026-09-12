import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 1 — izbor usluge (`prototype/ui/SPEC.md` 5c).
///
/// **Čita `?serviceId=` iz rute.** Home ekran vodi na `/book/service?serviceId=<id>` kad
/// se tapne kartica usluge (task 10); bez čitanja tog parametra preselekcija tiho ne radi
/// i korisnik bira istu uslugu dvaput, a ekran pri tome izgleda ispravno.
///
/// Preselekcija se radi jednom, u `initState`, a ne u `build`: mijenjanje providera tokom
/// gradnje widgeta je greška koju Riverpod prijavi tek u runtime-u.
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
      title: vertical.terms.servicePlural,
      subtitle: l10n.bookingPickOne,
      child: switch (services) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          message: l10n.bookingEmptyList,
          icon: Icons.event_busy,
        ),
        AsyncData(:final value) => _Lista(
          services: value,
          izabranaId: izabrana,
          prikaziCijene: vertical.features.prices,
          onIzbor: (service) {
            ref.read(bookingFlowProvider.notifier).chooseService(service.id);
            context.go(BookingStep.employee.path);
          },
        ),
        AsyncError() => _Greska(
          message: l10n.bookingServicesUnavailable,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(servicesProvider),
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
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceCard(
          name: service.name,
          duration: formatDuration(service.durationMinutes),
          price: prikaziCijene ? formatPrice(service.price) : null,
          description: service.description.isEmpty ? null : service.description,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => SkeletonLoader.card(),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      message: message,
      icon: Icons.cloud_off,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}
