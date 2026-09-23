/// Sitni dijelovi ekrana usluga — prekidač, sličica, ko radi uslugu, trajanje po izboru.
///
/// Stoje odvojeno od ekrana jer ih koriste i tabela (`3f`) i editor (`3f` panel, `3q`).
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/admin_verzal.dart';
import '../appointments/appointments_providers.dart';

/// Ko radi koju uslugu — iz postojećih `employees` i `employee_services` providera.
///
/// Samo za čitanje: veza se snima atomski uz profil radnika (`update_employee`), pa se i
/// mijenja na ekranu Osoblje. Dva RPC-a iz ovog ekrana bi razbila tu atomičnost.
class Izvodjaci {
  const Izvodjaci({
    required this.aktivni,
    required this.veze,
    required this.ucitano,
  });

  final List<Employee> aktivni;

  /// `serviceId` → ID-evi radnika koji je rade.
  final Map<String, Set<String>> veze;

  /// `false` dok stiže ili kad upit padne — tada se piše „—", ne „niko".
  final bool ucitano;

  bool radi(String serviceId, String employeeId) =>
      veze[serviceId]?.contains(employeeId) ?? false;

  List<Employee> za(String serviceId) => [
    for (final e in aktivni)
      if (radi(serviceId, e.id)) e,
  ];

  /// `svi`, `Emir, Amar` ili `—`.
  String tekst(String serviceId) {
    if (!ucitano) return '—';
    final lista = za(serviceId);
    if (lista.isEmpty) return '—';
    if (lista.length == aktivni.length && aktivni.length > 1) return 'svi';
    return lista.map((e) => e.name).join(', ');
  }
}

Izvodjaci izvodjaciAdmina(WidgetRef ref) {
  final radnici = ref.watch(adminEmployeesProvider);
  final veze = ref.watch(adminEmployeeLinksProvider);
  final mapa = <String, Set<String>>{};
  for (final v in veze.valueOrNull ?? const <EmployeeService>[]) {
    (mapa[v.serviceId] ??= <String>{}).add(v.employeeId);
  }
  return Izvodjaci(
    aktivni: [
      for (final e in radnici.valueOrNull ?? const <Employee>[])
        if (e.isActive) e,
    ],
    veze: mapa,
    ucitano: radnici.hasValue && veze.hasValue,
  );
}

/// Prekidač iz `3f`/`3q` — uži od Material `Switch` (42×24 u tabeli, 50×28 na telefonu).
///
/// Material `Switch` je 52×32 i ne da se suziti bez `Transform.scale`, koji bi smanjio i
/// dodirnu metu. Ovdje traka ostaje izmjerena, a meta je najmanje 44 × 44 px (FE-502).
class UslugaPrekidac extends StatelessWidget {
  const UslugaPrekidac({
    required this.vrijednost,
    required this.onChanged,
    this.sirina = 42,
    this.visina = 24,
    this.oznaka,
    super.key,
  });

  final bool vrijednost;
  final ValueChanged<bool>? onChanged;
  final double sirina;
  final double visina;
  final String? oznaka;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final aktivan = onChanged != null;
    const unutra = 3.0;
    final palac = visina - 2 * unutra;

    return Semantics(
      toggled: vrijednost,
      enabled: aktivan,
      label: oznaka,
      child: InkWell(
        // `InkWell`, ne `GestureDetector` (FE-502): prekidač se dohvata tastaturom na
        // webu i fokus crta preklop oko staze.
        borderRadius: BorderRadius.circular(AdminRadius.base),
        onTap: aktivan ? () => onChanged!(!vrijednost) : null,
        child: SizedBox(
          width: sirina < AdminSize.touchTarget
              ? AdminSize.touchTarget
              : sirina,
          height: visina < AdminSize.touchTarget
              ? AdminSize.touchTarget
              : visina,
          child: Center(
            child: Opacity(
              opacity: aktivan ? 1 : 0.5,
              child: AnimatedContainer(
                duration: AdminDuration.fast,
                width: sirina,
                height: visina,
                padding: const EdgeInsets.all(unutra),
                decoration: BoxDecoration(
                  color: vrijednost ? boje.accent : boje.border,
                  borderRadius: BorderRadius.circular(visina / 2),
                ),
                child: AnimatedAlign(
                  duration: AdminDuration.fast,
                  alignment: vrijednost
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: palac,
                    height: palac,
                    decoration: BoxDecoration(
                      color: boje.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kvadratna sličica usluge. Bez fotografije je tamni prelaz kao u izvozu — prazan okvir
/// je predviđeno stanje (`Service.imageUrl` je nullable namjerno), ne greška.
class UslugaSlicica extends StatelessWidget {
  const UslugaSlicica({
    required this.url,
    required this.strana,
    required this.radijus,
    super.key,
  });

  final String? url;
  final double strana;
  final double radijus;

  @override
  Widget build(BuildContext context) {
    final ink = context.adminColors.ink;
    final prelaz = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ink.withValues(alpha: 0.62), ink],
        ),
      ),
    );
    final adresa = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radijus),
      child: SizedBox.square(
        dimension: strana,
        child: adresa == null || adresa.isEmpty
            ? prelaz
            : Image.network(
                adresa,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => prelaz,
              ),
      ),
    );
  }
}

/// „Ko radi uslugu" — dugmad po radniku, popunjena kad radnik radi uslugu.
///
/// **Ne mijenja vezu** (v. [Izvodjaci]). Dodir kaže gdje se mijenja; tooltip, ne
/// SnackBar, jer na telefonu ovo stoji u bottom sheetu iznad Scaffolda.
class KoRadiUslugu extends ConsumerWidget {
  const KoRadiUslugu({
    required this.serviceId,
    required this.visina,
    super.key,
  });

  /// `null` za novu uslugu — niko je još ne radi.
  final String? serviceId;
  final double visina;

  static const _poRedu = 3;
  static const _razmak = AdminSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izvodjaci = izvodjaciAdmina(ref);
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;

    if (!izvodjaci.ucitano || izvodjaci.aktivni.isEmpty) {
      return SizedBox(
        height: visina,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '—',
            style: tema.bodyLarge?.copyWith(color: boje.textSecondary),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sirina =
            (constraints.maxWidth - (_poRedu - 1) * _razmak) / _poRedu;
        return Wrap(
          spacing: _razmak,
          runSpacing: _razmak,
          children: [
            for (final radnik in izvodjaci.aktivni)
              _RadnikDugme(
                ime: radnik.name,
                izabran:
                    serviceId != null && izvodjaci.radi(serviceId!, radnik.id),
                sirina: sirina,
                visina: visina,
              ),
          ],
        );
      },
    );
  }
}

class _RadnikDugme extends StatelessWidget {
  const _RadnikDugme({
    required this.ime,
    required this.izabran,
    required this.sirina,
    required this.visina,
  });

  final String ime;
  final bool izabran;
  final double sirina;
  final double visina;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return Tooltip(
      message: 'Ko radi uslugu mijenja se na ekranu Osoblje.',
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        width: sirina,
        height: visina,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm),
        decoration: BoxDecoration(
          color: izabran ? boje.accent : boje.surface,
          borderRadius: BorderRadius.circular(AdminRadius.base),
          border: izabran ? null : Border.all(color: boje.border),
        ),
        child: Text(
          ime,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: izabran
              ? tema.titleMedium?.copyWith(color: boje.onAccent)
              : tema.bodyLarge?.copyWith(color: boje.textSecondary),
        ),
      ),
    );
  }
}

/// Trajanje van ponuđenih — isti opseg koji je stari editor primao (1–1440 min).
Future<int?> pitajTrajanje(BuildContext context, int? pocetno) =>
    showDialog<int>(
      context: context,
      builder: (_) => _TrajanjeDijalog(pocetno: pocetno),
    );

class _TrajanjeDijalog extends StatefulWidget {
  const _TrajanjeDijalog({this.pocetno});

  final int? pocetno;

  @override
  State<_TrajanjeDijalog> createState() => _TrajanjeDijalogState();
}

class _TrajanjeDijalogState extends State<_TrajanjeDijalog> {
  late final _polje = TextEditingController(
    text: widget.pocetno?.toString() ?? '',
  );
  String? _greska;

  @override
  void dispose() {
    _polje.dispose();
    super.dispose();
  }

  void _primijeni() {
    final n = int.tryParse(_polje.text);
    if (n == null || n < 1 || n > 1440) {
      setState(() => _greska = '1–1440 min');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trajanje u minutama'),
    content: TextField(
      controller: _polje,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _primijeni(),
      decoration: InputDecoration(suffixText: 'min', errorText: _greska),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Odustani'),
      ),
      FilledButton(
        onPressed: _primijeni,
        style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
        child: const AdminVerzal('Primijeni'),
      ),
    ],
  );
}
