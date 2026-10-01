/// Odbijanje zahtjeva sa razlogom — `6l`.
///
/// **Bez „Poništi".** Odbijanje se upisuje odmah: `reject` otkazuje termin, a otkazan termin
/// se ne vraća u život (`set_appointment_status`, `PT409`). Zato pita prije, a ne poslije.
///
/// **Natpis kaže „čuva se uz termin", ne „klijent ga vidi".** Handoff piše da klijent vidi
/// razlog u obavijesti, ali ni push tekst ni klijentska aplikacija `cancel_reason` danas ne
/// čitaju. Natpis koji obećava nešto što se ne desi je gori od tišeg natpisa.
library;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/admin_verzal.dart';

/// Razlozi iz `6l`. Rečenice su bez roda i bez padeža imena — „Odabrana osoba", ne
/// „Majstor nije dostupan": rječnik vertikale nema rod, a stilistica bi dobila muški oblik.
const List<String> kRazloziOdbijanja = [
  'Termin je u međuvremenu zauzet',
  'Odabrana osoba ne radi u to vrijeme',
  'Usluga se ne radi u tom terminu',
  'Drugo',
];

/// Vraća razlog (može biti prazan) ili `null` kad je vlasnik odustao.
Future<String?> pitajOdbijanje(BuildContext context, {required String opis}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _OdbijDijalog(opis: opis),
    );

class _OdbijDijalog extends StatefulWidget {
  const _OdbijDijalog({required this.opis});

  final String opis;

  @override
  State<_OdbijDijalog> createState() => _OdbijDijalogState();
}

class _OdbijDijalogState extends State<_OdbijDijalog> {
  // Kontroler živi u stanju dijaloga, ne oko `showDialog` — v. `_RazlogDijalog`.
  final _poruka = TextEditingController();
  int _izabran = 0;

  @override
  void dispose() {
    _poruka.dispose();
    super.dispose();
  }

  String get _razlog {
    final osnova = _izabran == kRazloziOdbijanja.length - 1
        ? null
        : kRazloziOdbijanja[_izabran];
    final dodatak = _poruka.text.trim();
    return [?osnova, if (dodatak.isNotEmpty) dodatak].join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;

    return AlertDialog(
      title: const Text('Odbiti zahtjev?'),
      content: SizedBox(
        width: 452,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.opis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: boje.textSecondary,
              ),
            ),
            const SizedBox(height: AdminSpacing.xl),
            Text(
              'Razlog — čuva se uz termin',
              style: theme.textTheme.labelSmall?.copyWith(
                color: boje.textSecondary,
              ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            for (final (i, razlog) in kRazloziOdbijanja.indexed)
              _Izbor(
                tekst: razlog,
                izabran: i == _izabran,
                onTap: () => setState(() => _izabran = i),
              ),
            const SizedBox(height: AdminSpacing.md),
            TextField(
              controller: _poruka,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Bilješka (nije obavezno)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_razlog),
          style: FilledButton.styleFrom(
            backgroundColor: boje.destructive,
            foregroundColor: boje.onDestructive,
            textStyle: AdminText.actionLabel,
          ),
          child: const AdminVerzal('Odbij zahtjev'),
        ),
      ],
    );
  }
}

/// Jedan red izbora: krug i tekst, cijeli red je meta od 44 px.
///
/// Vlastiti krug umjesto `Radio`: `groupValue`/`onChanged` na `Radio` su od Fluttera 3.35
/// zastarjeli u korist `RadioGroup`, a krug iz `6l` (5,5 px ispune) ionako nije Materialov.
class _Izbor extends StatelessWidget {
  const _Izbor({
    required this.tekst,
    required this.izabran,
    required this.onTap,
  });

  final String tekst;
  final bool izabran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: izabran,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminRadius.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AdminDuration.fast,
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: izabran ? boje.accent : boje.textMuted,
                    width: izabran ? 5.5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Text(
                  tekst,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
