import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vertical_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'booking_flow_provider.dart';
import 'booking_flow_state.dart';
import 'widgets/booking_step_scaffold.dart';

/// Korak 2 — kod koga dolazite (`prototype/ui/screenshots/04-korak2-majstor.png`).
///
/// Lista je **presjek** radnika salona i veza `employee_services` za izabranu uslugu —
/// `employee_service.dart` postoji upravo zbog toga. To nije availability logika: ko radi
/// koju uslugu je katalog, a ne raspored. Ko je slobodan **kada** pita se u koraku 3, i to
/// bazu.
///
/// "Bilo ko od nas" stoji **prvi** kad vertikala ne traži izbor osoblja
/// (`requireStaffChoice`) — kod frizera je to najčešći izbor, a kod ordinacije ga nema.
/// Prolazi korak sa `employeeId = null`, što je legitiman izbor, ne izostanak izbora
/// (v. `BookingFlowState.employeeChosen`). U handoffu taj red nosi `?` u okviru za
/// fotografiju, jer okvir ne smije ostati prazan — raspored bi poskočio kad stignu prave
/// slike.
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
      title: l10n.bookingPickStaff,
      subtitle: traziIzbor
          ? vertical.terms.staffPlural
          : l10n.bookingAnyStaffHintLine,
      cta: AppButton(
        label: l10n.bookingNext,
        onPressed: flow.employeeChosen
            ? () => context.go(BookingStep.slot.path)
            : null,
      ),
      child: Builder(
        builder: (context) {
          if (greska) {
            return EmptyState(
              message: l10n.bookingServicesUnavailable,
              icon: LucideIcons.cloudOff,
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
              icon: LucideIcons.userX,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            children: [
              if (!traziIzbor) ...[
                SelectableRow(
                  title: l10n.bookingAnyStaff,
                  subtitle: l10n.bookingAnyStaffHint,
                  placeholder: const _Upitnik(),
                  selected: flow.employeeChosen && flow.employeeId == null,
                  onTap: () => ref
                      .read(bookingFlowProvider.notifier)
                      .chooseAnyEmployee(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final employee in zaUslugu) ...[
                SelectableRow(
                  title: employee.name,
                  subtitle: employee.role.isEmpty ? null : employee.role,
                  imageUrl: employee.imageUrl,
                  placeholder: _Inicijal(ime: employee.name),
                  selected: flow.employeeId == employee.id,
                  onTap: () => ref
                      .read(bookingFlowProvider.notifier)
                      .chooseEmployee(employee.id),
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

/// `?` u okviru za "bilo ko od nas" — handoff, red 1 na koraku 2.
class _Upitnik extends StatelessWidget {
  const _Upitnik();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '?',
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Prvo slovo imena dok prave fotografije ne stignu.
class _Inicijal extends StatelessWidget {
  const _Inicijal({required this.ime});

  final String ime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slovo = ime.trim().isEmpty
        ? '?'
        : ime.trim().characters.first.toUpperCase();

    return Text(
      slovo,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Kostur extends StatelessWidget {
  const _Kostur();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const SkeletonLoader(height: 104),
    );
  }
}
