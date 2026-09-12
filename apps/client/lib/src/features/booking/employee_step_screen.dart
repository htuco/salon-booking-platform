import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 2 — kod koga dolazite (`prototype/ui/SPEC.md` 5d).
///
/// Lista je **presjek** radnika salona i veza `employee_services` za izabranu uslugu —
/// `employee_service.dart` postoji upravo zbog toga. To nije availability logika: ko radi
/// koju uslugu je katalog, a ne raspored. Ko je slobodan **kada** pita se u koraku 3, i to
/// bazu.
///
/// "Bilo ko od nas" stoji **prvi** kad vertikala ne traži izbor osoblja
/// (`requireStaffChoice`) — kod frizera je to najčešći izbor, a kod ordinacije ga nema.
/// Prolazi korak sa `employeeId = null`, što je legitiman izbor, ne izostanak izbora
/// (v. `BookingFlowState.employeeChosen`).
class EmployeeStepScreen extends ConsumerWidget {
  const EmployeeStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vertical = verticalOf(ref);
    final flow = ref.watch(bookingFlowProvider);
    final employees = ref.watch(employeesProvider);
    final links = ref.watch(employeeServiceLinksProvider);
    final traziIzbor = ref.watch(bookingRequiresStaffChoiceProvider);

    final ucitava = employees.isLoading || links.isLoading;
    final greska = employees.hasError || links.hasError;

    return BookingStepScaffold(
      step: BookingStep.employee,
      title: vertical.terms.staffPlural,
      subtitle: l10n.bookingPickStaff,
      child: Builder(
        builder: (context) {
          if (greska) {
            return EmptyState(
              message: l10n.bookingServicesUnavailable,
              icon: Icons.cloud_off,
              actionLabel: l10n.retry,
              onAction: () {
                ref
                  ..invalidate(employeesProvider)
                  ..invalidate(employeeServiceLinksProvider);
              },
            );
          }
          if (ucitava) return const _Kostur();

          final zaUslugu = _radniciZaUslugu(
            employees: employees.valueOrNull ?? const <Employee>[],
            links: links.valueOrNull ?? const <EmployeeService>[],
            serviceId: flow.serviceId,
          );

          if (zaUslugu.isEmpty && traziIzbor) {
            return EmptyState(
              message: l10n.bookingEmptyList,
              icon: Icons.person_off,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              if (!traziIzbor) ...[
                _Radnik(
                  ime: l10n.bookingAnyStaff,
                  opis: l10n.bookingAnyStaffHint,
                  izabran: flow.employeeChosen && flow.employeeId == null,
                  onTap: () {
                    ref.read(bookingFlowProvider.notifier).chooseAnyEmployee();
                    context.go(BookingStep.slot.path);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final employee in zaUslugu) ...[
                _Radnik(
                  ime: employee.name,
                  opis: employee.role.isEmpty ? null : employee.role,
                  slika: employee.imageUrl,
                  izabran: flow.employeeId == employee.id,
                  onTap: () {
                    ref
                        .read(bookingFlowProvider.notifier)
                        .chooseEmployee(employee.id);
                    context.go(BookingStep.slot.path);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Radnici koji rade izabranu uslugu.
  ///
  /// Salon bez ijedne veze za tu uslugu je greška u podacima, ne prazan salon — tada se
  /// vraćaju svi radnici, jer je prazan spisak ovdje ćorsokak iz kojeg korisnik ne može
  /// dalje, a rezervacija bi ionako pala na re-validaciji u bazi.
  List<Employee> _radniciZaUslugu({
    required List<Employee> employees,
    required List<EmployeeService> links,
    required String? serviceId,
  }) {
    if (serviceId == null) return employees;

    final dozvoljeni = {
      for (final link in links)
        if (link.serviceId == serviceId) link.employeeId,
    };

    if (dozvoljeni.isEmpty) return employees;
    return [
      for (final employee in employees)
        if (dozvoljeni.contains(employee.id)) employee,
    ];
  }
}

/// Red radnika — avatar, ime, titula.
///
/// Ne `ServiceCard`: kartica usluge nosi cijenu i trajanje desno, pa bi ime radnika
/// stajalo u rasporedu napravljenom za brojeve kojih ovdje nema.
class _Radnik extends StatelessWidget {
  const _Radnik({
    required this.ime,
    required this.izabran,
    required this.onTap,
    this.opis,
    this.slika,
  });

  final String ime;
  final String? opis;
  final String? slika;
  final bool izabran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: izabran,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: izabran ? scheme.primary : scheme.outline,
                width: izabran ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: slika == null || slika!.isEmpty
                      ? null
                      : NetworkImage(slika!),
                  child: Text(
                    _inicijal(ime),
                    style: theme.textTheme.titleMedium?.copyWith(
                      // Inicijal stoji na `primaryContainer`, pa se i mjeri prema njemu —
                      // `onSurface` bi ovdje bio kontrast prema pogrešnoj pozadini.
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ime, style: theme.textTheme.titleMedium),
                      if (opis != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          opis!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _inicijal(String ime) =>
      ime.trim().isEmpty ? '?' : ime.trim().characters.first.toUpperCase();
}

class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const SkeletonLoader(height: 72),
    );
  }
}
