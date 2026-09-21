import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointments_providers.dart';
import '../calendar/calendar_providers.dart';
import 'employees_providers.dart';

const _days = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

/// Ponavljajuci raspored iz working_hours, bez izmisljene sedmicne evidencije.
String employeeShift(List<WorkingHour> hours, String employeeId, int day) {
  final shift = workingHoursFor(hours, dayOfWeek: day, employeeId: employeeId);
  if (shift == null || shift.isClosed) return 'Slobodno';
  return '${shift.startTime.format()}–${shift.endTime.format()}';
}

class AdminEmployeesScreen extends ConsumerWidget {
  const AdminEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);
    final employees = ref.watch(adminEmployeesProvider);
    return AdminScaffold(
      title: 'Osoblje',
      aktivna: AdminRoute.employees,
      actions: desktop
          ? [
              FilledButton(
                onPressed: () => _edit(context),
                child: const Text('+ Dodaj radnika'),
              ),
            ]
          : null,
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj radnika'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminEmployeeLinksProvider);
          ref.invalidate(kalendarRadnoVrijemeProvider);
          ref.invalidate(adminEmployeesProvider);
          await ref.read(adminEmployeesProvider.future);
        },
        child: employees.when(
          loading: () => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(28),
                child: LinearProgressIndicator(),
              ),
            ],
          ),
          error: (_, _) => ListView(
            children: [
              const SizedBox(height: 80),
              const Center(child: Text('Osoblje se ne može učitati.')),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(adminEmployeesProvider),
                  child: const Text('Pokušaj ponovo'),
                ),
              ),
            ],
          ),
          data: (rows) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AdminShell.gutterOf(context),
              24,
              AdminShell.gutterOf(context),
              100,
            ),
            children: [
              Text(
                'Osoblje i smjene',
                style: desktop
                    ? AdminText.display
                    : Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${rows.where((e) => e.isActive).length} aktivnih radnika · sedmični raspored',
                style: TextStyle(color: context.adminColors.textSecondary),
              ),
              const SizedBox(height: 24),
              if (rows.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Text('Još nema radnika.'),
                        TextButton(
                          onPressed: () => _edit(context),
                          child: const Text('Dodaj prvog radnika'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final columns = (constraints.maxWidth / (280 * scale))
                        .floor()
                        .clamp(1, 3);
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final employee in rows)
                          SizedBox(
                            width:
                                (constraints.maxWidth - 16 * (columns - 1)) /
                                columns,
                            child: _EmployeeCard(employee: employee),
                          ),
                      ],
                    );
                  },
                )
              else ...[
                for (final employee in rows) ...[
                  _EmployeeCard(employee: employee),
                  const SizedBox(height: 12),
                ],
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Raspored smjena',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Redovni raspored po danima. Pauze i blokade provjerite u kalendaru.',
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => _Shifts(
                    employees: rows.where((e) => e.isActive).toList(),
                    desktop:
                        constraints.maxWidth >=
                        900 * MediaQuery.textScalerOf(context).scale(12) / 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeCard extends ConsumerWidget {
  const _EmployeeCard({required this.employee});
  final Employee employee;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(adminEmployeeLinksProvider);
    final services = ref.watch(adminServicesProvider);
    final ids =
        links.valueOrNull
            ?.where((l) => l.employeeId == employee.id)
            .map((l) => l.serviceId)
            .toSet() ??
        <String>{};
    final names = services.valueOrNull
        ?.where((s) => ids.contains(s.id))
        .map((s) => '${s.name}${s.isActive ? '' : ' (neaktivna)'}')
        .join(', ');
    return Card(
      child: InkWell(
        onTap: () => _edit(context, employee),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(employee: employee),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (employee.role.isNotEmpty) Text(employee.role),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                employee.isActive ? 'Aktivan' : 'Neaktivan',
                style: TextStyle(
                  color: employee.isActive
                      ? context.adminColors.textSecondary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              if (employee.experienceYears != null)
                Text('Staž: ${employee.experienceYears} god.'),
              const SizedBox(height: 8),
              Text(
                links.hasError || services.hasError
                    ? 'Usluge nisu učitane.'
                    : links.isLoading || services.isLoading
                    ? 'Učitavanje usluga…'
                    : names == null || names.isEmpty
                    ? 'Bez dodijeljenih usluga'
                    : names,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee});
  final Employee employee;
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 28,
      child: Text(employee.name.isEmpty ? '?' : employee.name.characters.first),
    );
    if (employee.imageUrl == null || employee.imageUrl!.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        employee.imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _Shifts extends ConsumerWidget {
  const _Shifts({required this.employees, required this.desktop});
  final List<Employee> employees;
  final bool desktop;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(kalendarRadnoVrijemeProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Column(
          children: [
            const Text('Raspored se ne može učitati.'),
            TextButton(
              onPressed: () => ref.invalidate(kalendarRadnoVrijemeProvider),
              child: const Text('Ponovi učitavanje rasporeda'),
            ),
          ],
        ),
        data: (hours) => desktop
            ? Card(
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {0: FlexColumnWidth(1.4)},
                  children: [
                    TableRow(
                      children: [
                        for (final label in ['Radnik', ..._days])
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final e in employees)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(e.name),
                          ),
                          for (var day = 1; day <= 7; day++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 14,
                              ),
                              child: Text(
                                employeeShift(hours, e.id, day),
                                style: AdminText.dataInline,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (final e in employees)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            for (var day = 1; day <= 7; day++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_days[day - 1]),
                                    Text(
                                      employeeShift(hours, e.id, day),
                                      style: AdminText.time,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );
}

Future<void> _edit(BuildContext context, [Employee? employee]) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmployeeEditor(employee: employee),
    );

class _EmployeeEditor extends ConsumerStatefulWidget {
  const _EmployeeEditor({this.employee});
  final Employee? employee;
  @override
  ConsumerState<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends ConsumerState<_EmployeeEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.employee?.name);
  late final _role = TextEditingController(text: widget.employee?.role);
  late final _bio = TextEditingController(text: widget.employee?.bio);
  late final _years = TextEditingController(
    text: widget.employee?.experienceYears?.toString(),
  );
  late final _image = TextEditingController(text: widget.employee?.imageUrl);
  Set<String>? _selected;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _role, _bio, _years, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _selected == null || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeActionsProvider)
          .save(
            widget.employee,
            EmployeeInput(
              name: _name.text.trim(),
              role: _role.text.trim(),
              bio: _bio.text.trim(),
              experienceYears: int.tryParse(_years.text.trim()),
              imageUrl: _image.text.trim(),
              serviceIds: _selected!.toList(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiError ? e.message : 'Promjena se ne može sačuvati.';
        });
      }
    }
  }

  Future<void> _toggle() async {
    final employee = widget.employee!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          employee.isActive ? 'Deaktivirati radnika?' : 'Aktivirati radnika?',
        ),
        content: Text(
          employee.isActive
              ? 'Radnik više neće biti ponuđen za nove rezervacije. Postojeći termini ostaju zakazani; pregledajte ih u kalendaru.'
              : 'Radnik će ponovo biti dostupan za rezervacije prema rasporedu i dodijeljenim uslugama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Potvrdi'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeActionsProvider)
          .setActive(employee, !employee.isActive);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiError ? e.message : 'Status se ne može promijeniti.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(adminServicesProvider);
    final links = ref.watch(adminEmployeeLinksProvider);
    if (_selected == null &&
        (widget.employee == null ||
            (links.hasValue && !links.isLoading && !links.hasError))) {
      _selected = {
        for (final l in links.valueOrNull ?? <EmployeeService>[])
          if (l.employeeId == widget.employee?.id) l.serviceId,
      };
    }
    final ready =
        !services.isLoading &&
        (widget.employee == null || !links.isLoading) &&
        services.hasValue &&
        _selected != null &&
        !services.hasError &&
        (widget.employee == null || !links.hasError);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.employee == null ? 'Novi radnik' : 'Uredi radnika',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ime'),
                    maxLength: 120,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ime je obavezno.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _role,
                    decoration: const InputDecoration(labelText: 'Titula'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    decoration: const InputDecoration(labelText: 'Biografija'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Godine staža (opcionalno)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      return n == null || n < 0 || n > 80
                          ? 'Unesite od 0 do 80 godina.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _image,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL fotografije (opcionalno)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final uri = Uri.tryParse(v.trim());
                      return uri == null ||
                              uri.scheme != 'https' ||
                              uri.host.isEmpty
                          ? 'Unesite HTTPS adresu fotografije.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Usluge koje radnik pruža',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!ready) ...[
                    if (services.hasError || links.hasError)
                      TextButton(
                        onPressed: () {
                          ref.invalidate(adminServicesProvider);
                          ref.invalidate(adminEmployeeLinksProvider);
                        },
                        child: const Text(
                          'Usluge nisu učitane. Pokušaj ponovo.',
                        ),
                      )
                    else
                      const LinearProgressIndicator(),
                  ] else ...[
                    if (services.value!.isEmpty)
                      const Text(
                        'Cjenovnik je prazan. Usluge možete dodijeliti kasnije.',
                      ),
                    for (final s in services.value!)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${s.name}${s.isActive ? '' : ' (neaktivna)'}',
                        ),
                        value: _selected!.contains(s.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected!.add(s.id);
                          } else {
                            _selected!.remove(s.id);
                          }
                        }),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: ready && !_saving ? _save : null,
                      child: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
                    ),
                  ),
                  if (widget.employee != null)
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _toggle,
                        child: Text(
                          widget.employee!.isActive
                              ? 'Deaktiviraj radnika'
                              : 'Ponovo aktiviraj radnika',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
