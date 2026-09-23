/// „Pristup" u Postavkama — ko ulazi u admin aplikaciju salona (task 45, ADR-0023).
///
/// Vlasnik poziva člana osoblja u tri dodira: „Pozovi", ime i uloga, „Kopiraj poruku".
/// Poruku pošalje kako god šalje sve ostalo. Ne kuca radnikov email i ne zna mu lozinku —
/// to radnik unese sam, na ekranu „Imam poziv".
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../appointments/appointments_providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_wordmark.dart';

/// Članovi osoblja salona.
final osobljePristupProvider = FutureProvider.autoDispose<List<StaffMember>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffAccessRepositoryProvider).members(salonId);
});

/// Pozivi koji još čekaju.
final poziviProvider = FutureProvider.autoDispose<List<StaffInvite>>((
  ref,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffAccessRepositoryProvider).pendingInvites(salonId);
});

/// Tekst koji vlasnik šalje radniku. Kod je jedini podatak koji radnik treba.
String porukaPoziva({
  required String ime,
  required String kod,
  required String salon,
  Uri? adresa,
}) {
  final link = adresa?.replace(
    path: '/pozivnica',
    queryParameters: {'kod': kod},
  );
  return [
    'Zdravo $ime, pozvani ste u admin aplikaciju salona $salon.',
    if (link != null)
      'Otvorite $link i napravite nalog.'
    else
      'Otvorite admin aplikaciju, dodirnite „Imam poziv" i unesite kod.',
    'Kod: $kod',
    'Poziv važi 7 dana.',
  ].join('\n');
}

String _uloga(String role) => labelaUloge(role) ?? role;

/// Sadržaj kartice — omotač (`_Kartica`) ostaje u `settings_screen.dart`.
class PristupSadrzaj extends ConsumerWidget {
  const PristupSadrzaj({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    final ja = ref.watch(currentStaffProvider).valueOrNull;
    final osoblje = ref.watch(osobljePristupProvider);
    final pozivi = ref.watch(poziviProvider).valueOrNull ?? const [];

    Widget red({
      required String naslov,
      required String opis,
      Widget? akcija,
    }) => Container(
      constraints: const BoxConstraints(minHeight: 62),
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: boje.ground,
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  naslov,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  opis,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: boje.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ?akcija,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        ...osoblje.when(
          loading: () => [const AdminSkeletonList(redova: 2)],
          error: (e, _) => [
            Text(
              porukaGreske(e, opsta: 'Osoblje se ne može učitati.'),
              style: TextStyle(color: boje.destructive),
            ),
          ],
          data: (lista) => [
            for (final clan in lista)
              red(
                naslov: clan.name,
                opis: [
                  _uloga(clan.role),
                  if (clan.id == ja?.id) 'vi' else clan.email,
                ].join(' · '),
                akcija: clan.id == ja?.id
                    ? null
                    : TextButton(
                        onPressed: () => _ukloni(context, ref, clan),
                        child: const Text('Ukloni'),
                      ),
              ),
          ],
        ),
        for (final p in pozivi)
          red(
            naslov: p.name,
            opis:
                '${_uloga(p.role)} · poziv čeka do '
                '${p.expiresAt.toLocal().day}.${p.expiresAt.toLocal().month}.',
            akcija: TextButton(
              onPressed: () => _povuci(context, ref, p),
              child: const Text('Povuci'),
            ),
          ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => prikaziNoviPoziv(context),
          child: const Text('+ Pozovi člana osoblja'),
        ),
      ],
    );
  }

  Future<void> _povuci(
    BuildContext context,
    WidgetRef ref,
    StaffInvite poziv,
  ) async {
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null) return;
    try {
      await ref
          .read(staffAccessRepositoryProvider)
          .revokeInvite(salonId: salonId, inviteId: poziv.id);
      ref.invalidate(poziviProvider);
    } on ApiError catch (e) {
      if (context.mounted) _poruka(context, porukaGreske(e));
    }
  }

  Future<void> _ukloni(
    BuildContext context,
    WidgetRef ref,
    StaffMember clan,
  ) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ukloniti ${clan.name}?'),
        content: const Text(
          'Pristup admin aplikaciji prestaje odmah. Termini i istorija ostaju.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );
    if (potvrda != true) return;
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null) return;
    try {
      await ref
          .read(staffAccessRepositoryProvider)
          .removeMember(salonId: salonId, userId: clan.id);
      ref.invalidate(osobljePristupProvider);
    } on ApiError catch (e) {
      if (context.mounted) _poruka(context, porukaGreske(e));
    }
  }
}

void _poruka(BuildContext context, String tekst) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tekst)));

Future<void> prikaziNoviPoziv(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _NoviPoziv());

class _NoviPoziv extends ConsumerStatefulWidget {
  const _NoviPoziv();

  @override
  ConsumerState<_NoviPoziv> createState() => _NoviPozivState();
}

class _NoviPozivState extends ConsumerState<_NoviPoziv> {
  final _ime = TextEditingController();
  String _uloga = 'employee';

  /// Za ulogu radnik: red iz Osoblja za koji je nalog (task 46). Ime se uzima od njega.
  Employee? _radnik;
  bool _saljem = false;
  String? _greska;
  StaffInviteCode? _kod;

  @override
  void dispose() {
    _ime.dispose();
    super.dispose();
  }

  String get _imeZaPoziv =>
      _uloga == 'employee' ? (_radnik?.name ?? '') : _ime.text.trim();

  Future<void> _napravi() async {
    if (_uloga == 'employee' && _radnik == null) {
      setState(() => _greska = 'Izaberite radnika.');
      return;
    }
    final ime = _imeZaPoziv;
    if (ime.isEmpty) {
      setState(() => _greska = 'Upišite ime.');
      return;
    }
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null) return;
    setState(() {
      _saljem = true;
      _greska = null;
    });
    try {
      final kod = await ref
          .read(staffAccessRepositoryProvider)
          .createInvite(
            salonId: salonId,
            role: _uloga,
            name: ime,
            employeeId: _uloga == 'employee' ? _radnik?.id : null,
          );
      ref.invalidate(poziviProvider);
      if (mounted) setState(() => _kod = kod);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _saljem = false;
          _greska = porukaGreske(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kod = _kod;
    return AlertDialog(
      title: Text(kod == null ? 'Pozovi člana osoblja' : 'Poziv je spreman'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: kod == null ? _forma(context) : _rezultat(context, kod),
      ),
      actions: kod == null
          ? [
              TextButton(
                onPressed: _saljem ? null : () => Navigator.of(context).pop(),
                child: const Text('Odustani'),
              ),
              FilledButton(
                onPressed: _saljem ? null : _napravi,
                child: const Text('Napravi poziv'),
              ),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Gotovo'),
              ),
            ],
    );
  }

  Widget _forma(BuildContext context) {
    final radnici = (ref.watch(adminEmployeesProvider).valueOrNull ?? const [])
        .where((r) => r.isActive)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'employee', label: Text('Radnik')),
            ButtonSegment(value: 'salon_admin', label: Text('Vlasnik')),
          ],
          selected: {_uloga},
          onSelectionChanged: (s) => setState(() {
            _uloga = s.first;
            _greska = null;
          }),
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          _uloga == 'employee' ? 'Radnik vidi i vodi samo svoje termine.' : 'Vlasnik ima pun pristup: termine, cjenovnik, osoblje i postavke.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.adminColors.textSecondary),
        ),
        const SizedBox(height: AdminSpacing.lg),
        if (_uloga == 'employee')
          // Nalog radnika se veže na red iz Osoblja, pa se bira, ne kuca — i ime dolazi
          // odatle. Tako termini dodijeljeni tom radniku postaju njegovi.
          DropdownButtonFormField<Employee>(
            initialValue: _radnik,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Koji radnik'),
            items: [
              for (final r in radnici)
                DropdownMenuItem(
                  value: r,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (r) => setState(() {
              _radnik = r;
              _greska = null;
            }),
          )
        else
          TextField(
            controller: _ime,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ime'),
            onSubmitted: (_) => _napravi(),
          ),
        if (_greska case final g?) ...[
          const SizedBox(height: AdminSpacing.md),
          Text(g, style: TextStyle(color: context.adminColors.destructive)),
        ],
      ],
    );
  }

  Widget _rezultat(BuildContext context, StaffInviteCode kod) {
    final salon = ref.read(adminSalonProvider).valueOrNull?.name ?? 'salona';
    final poruka = porukaPoziva(
      ime: _imeZaPoziv,
      kod: kod.code,
      salon: salon,
      // Na webu je adresa admina poznata, pa poruka nosi link koji otvara ekran poziva.
      adresa: Uri.base.hasScheme && Uri.base.scheme.startsWith('http')
          ? Uri.base.replace(path: '', query: '')
          : null,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pošaljite ovu poruku (Viber, WhatsApp, SMS). Kod se prikazuje samo sada — '
          'ako ga izgubite, povucite poziv i napravite novi.',
        ),
        const SizedBox(height: AdminSpacing.lg),
        SelectableText(
          kod.code,
          textAlign: TextAlign.center,
          style: AdminText.dataInline.copyWith(fontSize: 26, letterSpacing: 3),
        ),
        const SizedBox(height: AdminSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Kopiraj poruku'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: poruka));
            if (context.mounted) _poruka(context, 'Poruka je kopirana.');
          },
        ),
      ],
    );
  }
}
