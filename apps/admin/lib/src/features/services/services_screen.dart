/// Usluge i cjenovnik — `3f` na desktopu, `3p` lista i `3q` editor na telefonu.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/appointments_providers.dart';
import 'services_providers.dart';

class AdminServicesScreen extends ConsumerWidget {
  const AdminServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);
    void add() => showServiceEditor(context, ref);

    return AdminScaffold(
      title: 'Usluge',
      aktivna: AdminRoute.services,
      actions: desktop
          ? [FilledButton(onPressed: add, child: const Text('+ Nova usluga'))]
          : null,
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Nova usluga'),
            ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminServicesProvider.future),
        child: _ServicesBody(desktop: desktop),
      ),
    );
  }
}

class _ServicesBody extends ConsumerWidget {
  const _ServicesBody({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminServicesProvider);
    return state.when(
      loading: () => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        children: [
          const SizedBox(height: 160),
          Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: context.adminColors.textMuted,
          ),
          const SizedBox(height: AdminSpacing.md),
          const Center(child: Text('Cjenovnik se ne može učitati.')),
          const SizedBox(height: AdminSpacing.md),
          Center(
            child: OutlinedButton(
              onPressed: () => ref.invalidate(adminServicesProvider),
              child: const Text('Pokušaj ponovo'),
            ),
          ),
        ],
      ),
      data: (services) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          desktop ? AdminSpacing.gutterDesktop : AdminSpacing.gutterMobile,
        ),
        children: [
          Text(
            'Cjenovnik',
            style: desktop
                ? AdminText.display
                : Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 7),
          Text(
            'Trajanje određuje koliko mjesta usluga zauzme u kalendaru.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.adminColors.textSecondary),
          ),
          const SizedBox(height: AdminSpacing.xl),
          if (services.isEmpty)
            _Empty(onAdd: () => showServiceEditor(context, ref))
          else if (desktop)
            _DesktopTable(services: services)
          else
            for (final service in services) ...[
              _MobileCard(service: service),
              const SizedBox(height: AdminSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.content_cut_outlined, size: 42),
          const SizedBox(height: AdminSpacing.md),
          const Text('Cjenovnik je prazan.'),
          const SizedBox(height: AdminSpacing.md),
          FilledButton(
            onPressed: onAdd,
            child: const Text('Dodaj prvu uslugu'),
          ),
        ],
      ),
    ),
  );
}

class _DesktopTable extends ConsumerWidget {
  const _DesktopTable({required this.services});

  final List<Service> services;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        const _TableRow(header: true),
        for (final service in services)
          _TableRow(
            service: service,
            onTap: () => showServiceEditor(context, ref, service: service),
          ),
      ],
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({this.service, this.onTap, this.header = false});

  final Service? service;
  final VoidCallback? onTap;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final muted = context.adminColors.textMuted;
    final style = header
        ? AdminText.eyebrow.copyWith(color: muted)
        : Theme.of(context).textTheme.bodyMedium;
    final service = this.service;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: header ? 44 : 68),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.adminColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: header
                  ? Text('USLUGA', style: style)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          service!.name,
                          style: style?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (service.category.isNotEmpty)
                          Text(
                            service.category,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                      ],
                    ),
            ),
            Expanded(
              child: Text(
                header ? 'TRAJANJE' : '${service!.durationMinutes} min',
                style: style,
              ),
            ),
            Expanded(
              child: Text(
                header ? 'CIJENA' : iznosKm(service!.price),
                style: style,
              ),
            ),
            Expanded(
              child: header
                  ? Text('ONLINE', style: style)
                  : _ActivePill(active: service!.isActive),
            ),
            if (!header) Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class _MobileCard extends ConsumerWidget {
  const _MobileCard({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(AdminRadius.base),
      onTap: () => showServiceEditor(context, ref, service: service),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${service.durationMinutes} min · ${iznosKm(service.price)}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: context.adminColors.textSecondary),
                  ),
                  const SizedBox(height: AdminSpacing.sm),
                  _ActivePill(active: service.isActive),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.adminColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tone = active
        ? context.statusColors.positive
        : context.statusColors.neutral;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          active ? 'Aktivna' : 'Neaktivna',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

Future<void> showServiceEditor(
  BuildContext context,
  WidgetRef ref, {
  Service? service,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ServiceEditor(service: service),
);

class _ServiceEditor extends ConsumerStatefulWidget {
  const _ServiceEditor({this.service});

  final Service? service;

  @override
  ConsumerState<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends ConsumerState<_ServiceEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _name = TextEditingController(text: service?.name ?? '');
    _description = TextEditingController(text: service?.description ?? '');
    _category = TextEditingController(text: service?.category ?? '');
    _price = TextEditingController(
      text: service == null ? '' : service.price.toStringAsFixed(2),
    );
    _duration = TextEditingController(
      text: service?.durationMinutes.toString() ?? '',
    );
    _active = service?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(serviceActionsProvider);
      final result = await actions.save(
        widget.service,
        ServiceInput(
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: _category.text.trim(),
          price: normalizeServicePrice(_price.text)!,
          durationMinutes: int.parse(_duration.text),
        ),
      );
      if (result.isActive != _active) await actions.setActive(result, _active);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Promjena se ne može sačuvati.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        width: width >= AdminBreakpoint.desktop ? 520 : double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service == null ? 'Nova usluga' : 'Uredi uslugu',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AdminSpacing.xl),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Naziv'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Naziv je obavezan.'
                      : null,
                ),
                const SizedBox(height: AdminSpacing.md),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Kategorija'),
                ),
                const SizedBox(height: AdminSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Opis'),
                ),
                const SizedBox(height: AdminSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Trajanje (min)',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 1440
                              ? '1–1440 min'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cijena (KM)',
                        ),
                        validator: (v) => normalizeServicePrice(v ?? '') == null
                            ? 'Npr. 15,00'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AdminSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vidljivo u aplikaciji'),
                  subtitle: const Text('Klijenti mogu sami zakazati'),
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AdminSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Čuvanje…' : 'Sačuvaj'),
                  ),
                ),
                if (widget.service case final service?) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() {
                                _saving = true;
                                _error = null;
                              });
                              try {
                                await ref
                                    .read(serviceActionsProvider)
                                    .setActive(service, !service.isActive);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              } catch (_) {
                                setState(() {
                                  _saving = false;
                                  _error = 'Status se ne može promijeniti.';
                                });
                              }
                            },
                      child: Text(
                        service.isActive
                            ? 'Deaktiviraj uslugu'
                            : 'Ponovo aktiviraj uslugu',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
