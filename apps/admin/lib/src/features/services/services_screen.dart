/// Usluge i cjenovnik — `3f` na desktopu, `3p` lista i `3q` editor na telefonu.
///
/// Desktop: tabela lijevo, editor izabrane usluge desno (bez modala). Kad radna površina
/// padne u `compact` pojas, tabela i panel ne stanu jedno uz drugo, pa se crta lista iz
/// `3p` i editor ide u sheet — isti oblik kao na telefonu, ne stisnuta tabela.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../../core/widgets/admin_refresh.dart';
import '../../core/format/tekst.dart';
import '../../core/format/terminologija.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../appointments/appointments_providers.dart';
import 'services_providers.dart';
import 'usluga_editor.dart';
import 'usluge_dijelovi.dart';

export 'usluga_editor.dart' show showServiceEditor;

/// `3f`: širina desnog panela i razmak do tabele (360 + 20 na 1440).
const double _sirinaPanela = 360;
const double _razmakPanela = 20;

/// `3f`: unutrašnji horizontalni razmak tabele i panela (22 px, izmjereno).
const double _unutraTabele = 22;

/// Ispod ove širine tabele kolona radnika otpada; ime usluge je važnije.
const double _tabelaSaRadnicima = 620;

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  ConsumerState<AdminServicesScreen> createState() =>
      _AdminServicesScreenState();
}

class _AdminServicesScreenState extends ConsumerState<AdminServicesScreen> {
  /// Usluga u desnom panelu `3f`. `null` = prva u listi.
  String? _izabranaId;

  /// Panel je u režimu „Nova usluga".
  bool _nova = false;

  /// Usluge čiji se prekidač „Online" upravo snima.
  final Set<String> _uToku = {};

  /// Tabela sa panelom stoji samo na desktopu izvan `compact` pojasa.
  bool _saPanelom(BuildContext context) =>
      AdminShell.jeDesktop(context) && !AdminShell.bandOf(context).jeCompact;

  void _novaUsluga() {
    if (_saPanelom(context)) {
      setState(() => _nova = true);
    } else {
      showServiceEditor(context, ref);
    }
  }

  void _uredi(Service service) {
    if (_saPanelom(context)) {
      setState(() {
        _nova = false;
        _izabranaId = service.id;
      });
    } else {
      showServiceEditor(context, ref, service: service);
    }
  }

  Future<void> _online(Service service, bool vrijednost) async {
    setState(() => _uToku.add(service.id));
    String? greska;
    try {
      await ref.read(serviceActionsProvider).setActive(service, vrijednost);
    } on ApiError catch (e) {
      greska = porukaGreske(e);
    } catch (_) {
      greska = 'Status se ne može promijeniti.';
    }
    if (!mounted) return;
    setState(() => _uToku.remove(service.id));
    if (greska != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(greska)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AdminShell.jeDesktop(context);

    return AdminScaffold(
      title: 'Usluge',
      aktivna: AdminRoute.services,
      // `3p` crta veliki naslov u tijelu; `AppBar` sa istom riječi bi stajao iznad njega.
      sopstvenoZaglavlje: true,
      actions: desktop ? [_NovaUslugaDugme(onPressed: _novaUsluga)] : null,
      body: AdminRefresh(
        onRefresh: () {
          ref
            ..invalidate(adminEmployeesProvider)
            ..invalidate(adminEmployeeLinksProvider);
          return ref.refresh(adminServicesProvider.future);
        },
        child: desktop ? _desktop(context) : _telefon(context),
      ),
    );
  }

  Widget _desktop(BuildContext context) {
    final stanje = ref.watch(adminServicesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final saPanelom = !AdminShell.bandZa(constraints.maxWidth).jeCompact;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AdminSpacing.gutterDesktop),
          child: Align(
            alignment: Alignment.topLeft,
            // Preko cijele radne površine, kao „Danas" — bez gornje granice širine.
            child: ConstrainedBox(
              constraints: const BoxConstraints(),
              child: stanje.when(
                loading: () => const AdminSkeletonList(),
                error: (_, _) =>
                    _Kvar(onRetry: () => ref.invalidate(adminServicesProvider)),
                data: (usluge) =>
                    saPanelom ? _tabelaSaPanelom(usluge) : _uskiDesktop(usluge),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabelaSaPanelom(List<Service> usluge) {
    final izabrana = _nova || usluge.isEmpty
        ? null
        : usluge.firstWhere(
            (s) => s.id == _izabranaId,
            orElse: () => usluge.first,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DesktopNaslov(),
              const SizedBox(height: AdminSpacing.lg),
              if (usluge.isEmpty)
                _Prazno(onAdd: _novaUsluga)
              else
                _Tabela(
                  usluge: usluge,
                  izabranaId: izabrana?.id,
                  uToku: _uToku,
                  onTap: _uredi,
                  onOnline: _online,
                ),
            ],
          ),
        ),
        const SizedBox(width: _razmakPanela),
        SizedBox(
          width: _sirinaPanela,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              _unutraTabele,
              AdminSpacing.xl,
              _unutraTabele,
              _unutraTabele,
            ),
            decoration: BoxDecoration(
              color: context.adminColors.surface,
              borderRadius: BorderRadius.circular(AdminRadius.base),
              border: Border.all(color: context.adminColors.cardEdge),
            ),
            child: UslugaEditor(
              // Nova instanca po usluzi: kontroleri se pune samo u `initState`.
              key: ValueKey(izabrana?.id ?? 'nova'),
              service: izabrana,
              kompaktno: false,
              onSacuvano: (s) => setState(() {
                _nova = false;
                _izabranaId = s.id;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uskiDesktop(List<Service> usluge) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _DesktopNaslov(),
      const SizedBox(height: AdminSpacing.lg),
      if (usluge.isEmpty)
        _Prazno(onAdd: _novaUsluga)
      else
        _Kartice(usluge: usluge, onTap: _uredi),
    ],
  );

  Widget _telefon(BuildContext context) {
    final stanje = ref.watch(adminServicesProvider);
    final lista = switch (stanje) {
      AsyncData(:final value) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.gutterMobile,
          vertical: AdminSpacing.md,
        ),
        children: [
          if (value.isEmpty)
            _Prazno(onAdd: _novaUsluga)
          else
            _Kartice(usluge: value, onTap: _uredi),
        ],
      ),
      AsyncError() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        children: [_Kvar(onRetry: () => ref.invalidate(adminServicesProvider))],
      ),
      _ => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminSpacing.gutterMobile),
        children: const [AdminSkeletonList()],
      ),
    };

    return Column(
      children: [
        const _TelefonZaglavlje(),
        Expanded(child: lista),
        _DonjaAkcija(onPressed: _novaUsluga),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Zaglavlja i akcije
// ---------------------------------------------------------------------------

/// `+ NOVA USLUGA` u top baru `3f` — 40 px visoko.
class _NovaUslugaDugme extends StatelessWidget {
  const _NovaUslugaDugme({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 17),
        textStyle: AdminText.actionLabel,
      ),
      child: const AdminVerzal('+ Nova usluga'),
    ),
  );
}

/// `3f`: „Cjenovnik" i rečenica ispod.
class _DesktopNaslov extends StatelessWidget {
  const _DesktopNaslov();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Naslov u izvozu stoji 4 px više od vrha panela.
        Transform.translate(
          offset: const Offset(0, -4),
          child: Text('Cjenovnik', style: AdminText.display),
        ),
        const SizedBox(height: 2),
        Text(
          'Trajanje određuje koliko mjesta usluga zauzme u kalendaru.',
          style: tema.bodyLarge,
        ),
      ],
    );
  }
}

/// `3p`: „Usluge" 30 px i uputa, bijela traka sa linijom ispod.
class _TelefonZaglavlje extends StatelessWidget {
  const _TelefonZaglavlje();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.sm,
        AdminSpacing.sm,
        AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Usluge', style: tema.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Dodirni uslugu za izmjenu',
                    style: tema.bodyMedium?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // `3p` ga ne crta, ali bez `AppBar`-a je ovo jedini put do naloga i odjave
            // sa ovog ekrana — isto kao na „Danas".
            const AdminNalogDugme(ikona: true),
          ],
        ),
      ),
    );
  }
}

/// `3p`: `+ NOVA USLUGA` preko cijele širine, iznad donje navigacije.
class _DonjaAkcija extends StatelessWidget {
  const _DonjaAkcija({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AdminSpacing.gutterMobile,
      vertical: AdminSpacing.md,
    ),
    decoration: BoxDecoration(
      color: context.adminColors.surface,
      border: Border(
        top: BorderSide(
          color: context.adminColors.separator,
          width: AdminSize.hairline,
        ),
      ),
    ),
    child: SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          textStyle: AdminText.actionLabel.copyWith(fontSize: 16),
        ),
        child: const AdminVerzal('+ Nova usluga'),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// `3f` — tabela
// ---------------------------------------------------------------------------

/// Udjeli kolona izmjereni iz `3f`: 264 / 110 / 110 / 150 / 90 px na 724.
const _flexUsluga = 26, _flexTrajanje = 11, _flexCijena = 11;
const _flexRadnici = 15, _flexOnline = 9;

class _Tabela extends ConsumerWidget {
  const _Tabela({
    required this.usluge,
    required this.izabranaId,
    required this.uToku,
    required this.onTap,
    required this.onOnline,
  });

  final List<Service> usluge;
  final String? izabranaId;
  final Set<String> uToku;
  final ValueChanged<Service> onTap;
  final void Function(Service, bool) onOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izvodjaci = izvodjaciAdmina(ref);
    final radnik = radnikJednina(ref);
    final boje = context.adminColors;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: boje.surface,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        border: Border.all(color: boje.cardEdge),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final saRadnicima = constraints.maxWidth >= _tabelaSaRadnicima;
          return Column(
            children: [
              _Zaglavlje(radnik: radnik, saRadnicima: saRadnicima),
              for (final (i, s) in usluge.indexed)
                _Red(
                  service: s,
                  izabrana: s.id == izabranaId,
                  zadnji: i == usluge.length - 1,
                  radnici: saRadnicima ? izvodjaci.tekst(s.id) : null,
                  uToku: uToku.contains(s.id),
                  onTap: () => onTap(s),
                  onOnline: (v) => onOnline(s, v),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje({required this.radnik, required this.saRadnicima});

  final String radnik;
  final bool saRadnicima;

  @override
  Widget build(BuildContext context) {
    final stil = AdminText.eyebrow.copyWith(
      color: context.adminColors.textSecondary,
    );
    Widget celija(int flex, String tekst) => Expanded(
      flex: flex,
      child: Text(tekst, style: stil, overflow: TextOverflow.ellipsis),
    );
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: _unutraTabele),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          celija(_flexUsluga, 'USLUGA'),
          celija(_flexTrajanje, 'TRAJANJE'),
          celija(_flexCijena, 'CIJENA'),
          // Riječ za radnika dolazi iz vertikale; jednina, kao i „USLUGA".
          if (saRadnicima) celija(_flexRadnici, radnik.toUpperCase()),
          celija(_flexOnline, 'ONLINE'),
        ],
      ),
    );
  }
}

/// Red tabele `3f` — 74 px + linija. Izabrani red je na `accentTint`, isključeni blijed.
class _Red extends StatelessWidget {
  const _Red({
    required this.service,
    required this.izabrana,
    required this.zadnji,
    required this.radnici,
    required this.uToku,
    required this.onTap,
    required this.onOnline,
  });

  final Service service;
  final bool izabrana;
  final bool zadnji;

  /// `null` kad kolona radnika ne stane.
  final String? radnici;
  final bool uToku;
  final VoidCallback onTap;
  final ValueChanged<bool> onOnline;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final sporedno = tema.bodyLarge?.copyWith(
      color: boje.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final aktivna = service.isActive;
    Widget blijedo(Widget w) => aktivna ? w : Opacity(opacity: 0.45, child: w);

    return Material(
      color: izabrana ? boje.accentTint : boje.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: zadnji ? 74 : 75,
          padding: const EdgeInsets.symmetric(horizontal: _unutraTabele),
          decoration: zadnji
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: boje.separator,
                      width: AdminSize.hairline,
                    ),
                  ),
                ),
          child: Row(
            children: [
              Expanded(
                flex: _flexUsluga,
                child: blijedo(
                  Row(
                    children: [
                      UslugaSlicica(
                        url: service.imageUrl,
                        strana: 44,
                        radijus: AdminRadius.small,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.titleMedium,
                            ),
                            if (_podnaslov(service) case final pod?)
                              Text(
                                pod,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tema.bodySmall?.copyWith(
                                  color: boje.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AdminSpacing.md),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _flexTrajanje,
                child: blijedo(
                  Text('${service.durationMinutes} min', style: sporedno),
                ),
              ),
              Expanded(
                flex: _flexCijena,
                child: blijedo(
                  Text(
                    iznosKm(service.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (radnici case final r?)
                Expanded(
                  flex: _flexRadnici,
                  child: blijedo(
                    Padding(
                      padding: const EdgeInsets.only(right: AdminSpacing.md),
                      child: Text(
                        r,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sporedno,
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: _flexOnline,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: UslugaPrekidac(
                    vrijednost: aktivna,
                    oznaka: 'Online: ${service.name}',
                    onChanged: uToku ? null : onOnline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Druga linija imena. `3f` tu piše udio u terminima („41% termina") — tog podatka nema,
/// pa stoji kategorija, a za isključenu uslugu zašto je blijeda.
String? _podnaslov(Service s) {
  if (!s.isActive) return 'isključeno iz online zakazivanja';
  return s.category.isEmpty ? null : s.category;
}

// ---------------------------------------------------------------------------
// `3p` — kartice
// ---------------------------------------------------------------------------

class _Kartice extends ConsumerWidget {
  const _Kartice({required this.usluge, required this.onTap});

  final List<Service> usluge;
  final ValueChanged<Service> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izvodjaci = izvodjaciAdmina(ref);
    return Column(
      children: [
        for (final (i, s) in usluge.indexed) ...[
          if (i > 0) const SizedBox(height: AdminSpacing.sm),
          _Kartica(
            service: s,
            radnici: izvodjaci.tekst(s.id),
            onTap: () => onTap(s),
          ),
        ],
      ],
    );
  }
}

/// Kartica `3p` — 80 px: sličica 52, ime i „30 min · svi", cijena desno.
class _Kartica extends StatelessWidget {
  const _Kartica({
    required this.service,
    required this.radnici,
    required this.onTap,
  });

  final Service service;
  final String radnici;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final drugi = service.isActive ? radnici : 'nije online';

    final sadrzaj = Row(
      children: [
        UslugaSlicica(
          url: service.imageUrl,
          strana: 52,
          radijus: AdminRadius.base,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${service.durationMinutes} min · $drugi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.bodySmall?.copyWith(
                  color: boje.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
        Text(
          iznosKm(service.price),
          style: tema.headlineMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Material(
      color: boje.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.base),
        side: BorderSide(color: boje.cardEdge, width: AdminSize.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 15, 12),
          child: service.isActive
              ? sadrzaj
              : Opacity(opacity: 0.45, child: sadrzaj),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stanja
// ---------------------------------------------------------------------------

class _Prazno extends StatelessWidget {
  const _Prazno({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.content_cut_outlined,
              size: 42,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.md),
            const Text('Cjenovnik je prazan.'),
            const SizedBox(height: AdminSpacing.md),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
              child: const AdminVerzal('Dodaj prvu uslugu'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Kvar extends StatelessWidget {
  const _Kvar({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 120),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: context.adminColors.textMuted,
          ),
          const SizedBox(height: AdminSpacing.md),
          const Text('Cjenovnik se ne može učitati.'),
          const SizedBox(height: AdminSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    ),
  );
}
