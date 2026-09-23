/// Uređivač salonske sekcije pravila — bottom sheet, isti oblik kao `3q`.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'settings_providers.dart';

/// Otvara uređivač sekcije — nove ([sekcija] `null`) ili postojeće.
///
/// [sortOrder] se prosljeđuje samo za novu sekciju; postojeća zadržava svoj, jer bi
/// promjena pozicije pri običnoj izmjeni teksta pomjerila sekciju u dokumentu koji je
/// klijent već pročitao.
Future<void> prikaziUredjivacSekcije(
  BuildContext context,
  WidgetRef ref, {
  PolicySection? sekcija,
  int sortOrder = 10,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _UredjivacSekcije(sekcija: sekcija, sortOrder: sortOrder),
);

class _UredjivacSekcije extends ConsumerStatefulWidget {
  const _UredjivacSekcije({required this.sekcija, required this.sortOrder});

  final PolicySection? sekcija;
  final int sortOrder;

  @override
  ConsumerState<_UredjivacSekcije> createState() => _UredjivacSekcijeState();
}

class _UredjivacSekcijeState extends ConsumerState<_UredjivacSekcije> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _naslov;
  late final TextEditingController _tijelo;

  bool _snimam = false;
  String? _greska;

  @override
  void initState() {
    super.initState();
    _naslov = TextEditingController(text: widget.sekcija?.title ?? '');
    _tijelo = TextEditingController(text: widget.sekcija?.body ?? '');
  }

  @override
  void dispose() {
    _naslov.dispose();
    _tijelo.dispose();
    super.dispose();
  }

  Future<void> _sacuvaj() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _snimam = true;
      _greska = null;
    });

    try {
      await ref
          .read(settingsActionsProvider)
          .sacuvajSekciju(
            sekcijaId: widget.sekcija?.id,
            sortOrder: widget.sekcija?.sortOrder ?? widget.sortOrder,
            naslov: _naslov.text,
            tijelo: _tijelo.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = porukaGreske(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Sekcija se ne može sačuvati.';
      });
    }
  }

  Future<void> _obrisi() async {
    final sekcija = widget.sekcija;
    if (sekcija == null) return;

    setState(() {
      _snimam = true;
      _greska = null;
    });
    try {
      await ref.read(settingsActionsProvider).obrisiSekciju(sekcija.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Sekcija se ne može obrisati.';
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
                  widget.sekcija == null ? 'Nova sekcija' : 'Uredi sekciju',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  'Prikazuje se u aplikaciji na „Pravila korištenja".',
                  style: TextStyle(color: context.adminColors.textMuted),
                ),
                const SizedBox(height: AdminSpacing.xl),
                TextFormField(
                  controller: _naslov,
                  decoration: const InputDecoration(labelText: 'Naslov'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Naslov je obavezan.'
                      : null,
                ),
                const SizedBox(height: AdminSpacing.md),
                // **Broj sekcije se ne unosi.** Računa ga ekran iz pozicije u spojenoj
                // listi (ADR-0009) — upisan broj bi se razišao sa prikazanim čim se doda
                // sekcija iznad. Zato ni „v. tačku 3" ne treba pisati u tijelo.
                TextFormField(
                  controller: _tijelo,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Tekst',
                    helperText:
                        'Prazan red razdvaja pasuse. '
                        '{minCancelHours}, {phone} i {email} se popune same.',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Tekst je obavezan.'
                      : null,
                ),
                if (_greska case final greska?) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  Text(
                    greska,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AdminSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _snimam ? null : _sacuvaj,
                    child: Text(_snimam ? 'Čuvanje…' : 'Sačuvaj'),
                  ),
                ),
                if (widget.sekcija != null) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _snimam ? null : _obrisi,
                      style: TextButton.styleFrom(
                        foregroundColor: context.adminColors.destructive,
                      ),
                      child: const Text('Obriši sekciju'),
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
