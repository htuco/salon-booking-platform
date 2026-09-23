/// Editor usluge — desni panel u `3f` i bottom sheet u `3q`.
///
/// Isti state i ista akcija (`ServiceActions.save` + `setActive`) u oba oblika; razlikuje
/// se samo raspored. Dva editora bi se razišla već kod prve nove validacije.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_verzal.dart';
import 'services_providers.dart';
import 'usluge_dijelovi.dart';

/// Otvara `3q` — bottom sheet sa editorom. Telefon i uski desktop.
Future<void> showServiceEditor(
  BuildContext context,
  WidgetRef ref, {
  Service? service,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.adminColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_radijusSheeta)),
  ),
  builder: (_) => UslugaEditor(service: service, kompaktno: true),
);

/// `3q`: gornji uglovi sheeta, izmjereno (32 px na 2× izvozu).
const double _radijusSheeta = 16;

/// Ponuđena trajanja u `3q` — pet dugmadi, šesto je „drugo".
const _trajanjaTelefon = [20, 30, 40, 60, 80];

/// Ponuđena trajanja u padajućem meniju `3f`.
const _trajanjaDesktop = [
  10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 80, 90, 105, 120, 150, 180, 240, //
];

/// Vrijednost stavke „Drugo…" u padajućem meniju; nije trajanje.
const _drugo = -1;

class UslugaEditor extends ConsumerStatefulWidget {
  const UslugaEditor({
    required this.service,
    required this.kompaktno,
    this.onSacuvano,
    super.key,
  });

  /// `null` je nova usluga.
  final Service? service;

  /// `true` je `3q` (sheet, zatvara se po snimanju), `false` desni panel iz `3f`.
  final bool kompaktno;

  final ValueChanged<Service>? onSacuvano;

  @override
  ConsumerState<UslugaEditor> createState() => _UslugaEditorState();
}

class _UslugaEditorState extends ConsumerState<UslugaEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _naziv;
  late final TextEditingController _opis;
  late final TextEditingController _kategorija;
  late final TextEditingController _cijena;
  int? _trajanje;
  late bool _aktivna;
  bool _detalji = false;

  /// Mijenja ključ padajućeg menija da zaboravi „Drugo…" i opet pokaže pravo trajanje.
  int _meniVerzija = 0;
  bool _cuvanje = false;
  String? _greska;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _naziv = TextEditingController(text: s?.name ?? '');
    _opis = TextEditingController(text: s?.description ?? '');
    _kategorija = TextEditingController(text: s?.category ?? '');
    // `toStringAsFixed(2)` pa normalizacija: iz `double` se izlazi jednom, na dvije
    // decimale, i dalje se radi u centima.
    _cijena = TextEditingController(
      text: s == null ? '' : _centiUTekst(_uCente(s.price.toStringAsFixed(2))!),
    );
    _trajanje = s?.durationMinutes ?? 30;
    _aktivna = s?.isActive ?? true;
  }

  @override
  void didUpdateWidget(covariant UslugaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Prekidač u tabeli mijenja status dok je panel otvoren; bez ovoga bi „Sačuvaj"
    // vratio staro stanje.
    final novo = widget.service?.isActive;
    if (novo != null && novo != oldWidget.service?.isActive) _aktivna = novo;
  }

  @override
  void dispose() {
    _naziv.dispose();
    _opis.dispose();
    _kategorija.dispose();
    _cijena.dispose();
    super.dispose();
  }

  Future<void> _sacuvaj() async {
    final ispravno = _form.currentState!.validate();
    // Naziv se na telefonu kod postojeće usluge krije u „detaljima"; greška ne smije
    // ostati sakrivena.
    if (!ispravno && _naziv.text.trim().isEmpty) {
      setState(() => _detalji = true);
    }
    if (!ispravno) return;
    setState(() {
      _cuvanje = true;
      _greska = null;
    });
    try {
      final akcije = ref.read(serviceActionsProvider);
      final rezultat = await akcije.save(
        widget.service,
        ServiceInput(
          name: _naziv.text.trim(),
          description: _opis.text.trim(),
          category: _kategorija.text.trim(),
          price: normalizeServicePrice(_cijena.text)!,
          durationMinutes: _trajanje!,
        ),
      );
      if (rezultat.isActive != _aktivna) {
        await akcije.setActive(rezultat, _aktivna);
      }
      if (!mounted) return;
      setState(() => _cuvanje = false);
      widget.onSacuvano?.call(rezultat.copyWith(isActive: _aktivna));
      if (widget.kompaktno) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _cuvanje = false;
          _greska = porukaGreske(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cuvanje = false;
          _greska = 'Promjena se ne može sačuvati.';
        });
      }
    }
  }

  void _pomjeriCijenu(int km) {
    final centi = _uCente(normalizeServicePrice(_cijena.text) ?? '0.00')!;
    final novo = centi + km * 100;
    setState(() => _cijena.text = _centiUTekst(novo < 0 ? 0 : novo));
  }

  Future<void> _drugoTrajanje() async {
    final n = await pitajTrajanje(context, _trajanje);
    if (n != null && mounted) setState(() => _trajanje = n);
  }

  @override
  Widget build(BuildContext context) {
    final sadrzaj = Form(
      key: _form,
      child: AbsorbPointer(
        absorbing: _cuvanje,
        child: widget.kompaktno ? _telefon(context) : _panel(context),
      ),
    );
    if (!widget.kompaktno) return sadrzaj;
    return PopScope(
      canPop: !_cuvanje,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.gutterMobile,
            AdminSpacing.md,
            AdminSpacing.gutterMobile,
            AdminSpacing.xl,
          ),
          child: sadrzaj,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // `3f` — desni panel
  // -------------------------------------------------------------------------

  Widget _panel(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final service = widget.service;
    // `3f`: razmak od dna polja do sljedeće labele je 14 px, uži od telefonskog.
    const izmedju = 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          service == null ? 'Nova usluga' : 'Uredi uslugu',
          style: tema.headlineMedium,
        ),
        if (service != null) ...[
          const SizedBox(height: 2),
          Text(
            service.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.bodySmall?.copyWith(color: boje.textSecondary),
          ),
        ],
        const SizedBox(height: AdminSpacing.lg),
        _Labela('Naziv'),
        _nazivPolje(),
        const SizedBox(height: izmedju),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_Labela('Trajanje'), _trajanjeMeni()],
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Labela('Cijena'),
                  TextFormField(
                    controller: _cijena,
                    style: tema.bodyLarge,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _polje(context).copyWith(
                      suffixText: 'KM',
                      suffixStyle: tema.bodySmall?.copyWith(
                        color: boje.textSecondary,
                      ),
                    ),
                    validator: _cijenaGreska,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: izmedju),
        _Labela('Ko radi uslugu'),
        KoRadiUslugu(serviceId: service?.id, visina: 42),
        const SizedBox(height: izmedju),
        _Labela('Pauza poslije usluge'),
        // Placeholder: pauza postoji samo za cijeli salon (`salon_settings.buffer_minutes`),
        // ne po usluzi. Polje stoji na svom mjestu, ali ne glumi vrijednost.
        Tooltip(
          message: 'Pauza se za sada podešava za cijeli salon u Postavkama.',
          triggerMode: TooltipTriggerMode.tap,
          child: InputDecorator(
            isEmpty: false,
            decoration: _polje(context).copyWith(
              enabled: false,
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: boje.textMuted,
              ),
            ),
            child: Text(
              '—',
              style: tema.bodyLarge?.copyWith(color: boje.textMuted),
            ),
          ),
        ),
        const SizedBox(height: izmedju),
        _detaljiSekcija(context, sNazivom: false),
        const SizedBox(height: AdminSpacing.lg),
        Divider(height: 1, thickness: 1, color: boje.separator),
        const SizedBox(height: AdminSpacing.lg),
        _vidljivo(context, sirina: 46, visina: 26, naslov: tema.titleMedium),
        ..._greskaTekst(context),
        const SizedBox(height: AdminSpacing.lg),
        Row(
          children: [
            FilledButton(
              onPressed: _cuvanje ? null : _sacuvaj,
              style: FilledButton.styleFrom(
                textStyle: AdminText.actionLabel,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: AdminVerzal(_cuvanje ? 'Čuvanje…' : 'Sačuvaj'),
            ),
            if (service != null) ...[
              const SizedBox(width: AdminSpacing.md),
              // Placeholder: brisanja usluge nema u `ServiceActions` ni u RPC-u.
              // Isključivanje radi prekidač iznad.
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Brisanje usluge stiže uskoro. Do tada je isključite '
                      'prekidačem „Vidljivo u aplikaciji".',
                    ),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: boje.destructive),
                child: const Text('Obriši'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _trajanjeMeni() {
    final tema = Theme.of(context).textTheme;
    final ponuda = {..._trajanjaDesktop, ?_trajanje}.toList()..sort();
    return DropdownButtonFormField<int>(
      key: ValueKey('$_trajanje-$_meniVerzija'),
      initialValue: _trajanje,
      isExpanded: true,
      style: tema.bodyLarge?.copyWith(color: context.adminColors.ink),
      icon: Icon(
        Icons.arrow_drop_down,
        size: 18,
        color: context.adminColors.textSecondary,
      ),
      decoration: _polje(context),
      items: [
        for (final m in ponuda)
          DropdownMenuItem(value: m, child: Text('$m min')),
        const DropdownMenuItem(value: _drugo, child: Text('Drugo…')),
      ],
      validator: (v) => v == null ? 'Izaberite trajanje.' : null,
      onChanged: (v) {
        if (v == _drugo) {
          // Meni bi inače zapamtio „Drugo…" kao vrijednost; vraća se prava pa dijalog.
          setState(() => _meniVerzija++);
          _drugoTrajanje();
          return;
        }
        setState(() => _trajanje = v);
      },
    );
  }

  // -------------------------------------------------------------------------
  // `3q` — bottom sheet
  // -------------------------------------------------------------------------

  Widget _telefon(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final service = widget.service;
    const izmedju = AdminSpacing.lg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: boje.border,
              borderRadius: BorderRadius.circular(AdminRadius.dot),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          service?.name ?? 'Nova usluga',
          style: tema.headlineLarge?.copyWith(fontSize: 26),
        ),
        if (service != null && service.category.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            service.category,
            style: tema.bodySmall?.copyWith(color: boje.textSecondary),
          ),
        ],
        const SizedBox(height: izmedju),
        // Nova usluga nema ime u naslovu, pa naziv mora biti na vidiku, ne u detaljima.
        if (service == null) ...[
          _Labela('Naziv'),
          _nazivPolje(),
          const SizedBox(height: izmedju),
        ],
        _Labela('Trajanje'),
        _trajanjeDugmad(),
        const SizedBox(height: izmedju),
        _Labela('Cijena'),
        _cijenaKoraci(context),
        const SizedBox(height: izmedju),
        _Labela('Ko radi uslugu'),
        KoRadiUslugu(serviceId: service?.id, visina: 46),
        const SizedBox(height: AdminSpacing.md),
        _detaljiSekcija(context, sNazivom: service != null),
        const SizedBox(height: AdminSpacing.sm),
        Divider(height: 1, thickness: 1, color: boje.separator),
        const SizedBox(height: AdminSpacing.lg),
        _vidljivo(context, sirina: 50, visina: 28, naslov: tema.titleSmall),
        ..._greskaTekst(context),
        const SizedBox(height: AdminSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _cuvanje ? null : _sacuvaj,
            style: FilledButton.styleFrom(
              textStyle: AdminText.actionLabel.copyWith(fontSize: 16),
            ),
            child: AdminVerzal(_cuvanje ? 'Čuvanje…' : 'Sačuvaj'),
          ),
        ),
      ],
    );
  }

  /// Pet ponuđenih trajanja i šesto dugme za bilo koje drugo (stari editor je primao
  /// 1–1440, pa izbor ne smije biti uži od toga).
  Widget _trajanjeDugmad() {
    final trajanje = _trajanje;
    final van = trajanje != null && !_trajanjaTelefon.contains(trajanje);
    return FormField<int>(
      validator: (_) => _trajanje == null ? 'Izaberite trajanje.' : null,
      builder: (state) => Row(
        children: [
          for (final m in _trajanjaTelefon) ...[
            Expanded(
              child: _Izbor(
                tekst: '$m',
                izabran: trajanje == m,
                onTap: () => setState(() => _trajanje = m),
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
          ],
          Expanded(
            child: _Izbor(
              tekst: van ? '$trajanje' : '…',
              izabran: van,
              oznaka: 'Drugo trajanje',
              onTap: _drugoTrajanje,
            ),
          ),
        ],
      ),
    );
  }

  /// `3q`: „20 KM" veliko, − i + desno. Korak je 1 KM, u centima — nikad kroz `double`.
  Widget _cijenaKoraci(BuildContext context) {
    final boje = context.adminColors;
    final stil = barlowTabular(size: 24, weight: 600, color: boje.ink);

    return FormField<String>(
      validator: (_) => _cijenaGreska(_cijena.text),
      builder: (state) {
        final greska = state.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.only(left: 15, right: 15),
              decoration: BoxDecoration(
                color: boje.surface,
                borderRadius: BorderRadius.circular(AdminRadius.base),
                border: Border.all(
                  color: greska == null ? boje.border : boje.destructive,
                ),
              ),
              child: Row(
                children: [
                  _SirinaTeksta(
                    kontroler: _cijena,
                    stil: stil,
                    child: TextField(
                      controller: _cijena,
                      style: stil,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      onChanged: (_) => state.didChange(_cijena.text),
                      // Obrub nosi okvir oko broja i „KM"; bez eksplicitnog `none` tema
                      // bi nacrtala drugi obrub oko samog polja.
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        hintText: '0',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('KM', style: stil),
                  const Spacer(),
                  _Korak(
                    ikona: Icons.remove,
                    oznaka: 'Smanji cijenu',
                    onTap: () {
                      _pomjeriCijenu(-1);
                      state.didChange(_cijena.text);
                    },
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  _Korak(
                    ikona: Icons.add,
                    oznaka: 'Povećaj cijenu',
                    onTap: () {
                      _pomjeriCijenu(1);
                      state.didChange(_cijena.text);
                    },
                  ),
                ],
              ),
            ),
            if (greska != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  greska,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Zajedničko
  // -------------------------------------------------------------------------

  InputDecoration _polje(BuildContext context) => const InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _nazivPolje() => TextFormField(
    controller: _naziv,
    style: Theme.of(context).textTheme.bodyLarge,
    decoration: _polje(context),
    validator: (v) =>
        v == null || v.trim().isEmpty ? 'Naziv je obavezan.' : null,
  );

  String? _cijenaGreska(String? v) =>
      normalizeServicePrice(v ?? '') == null ? 'Npr. 15,00' : null;

  /// Kategorija i opis — `3f`/`3q` ih ne crtaju, ali ih stari editor mijenja, pa ostaju
  /// iza jednog reda umjesto da nestanu.
  Widget _detaljiSekcija(BuildContext context, {required bool sNazivom}) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _detalji = !_detalji),
          borderRadius: BorderRadius.circular(AdminRadius.small),
          child: SizedBox(
            height: AdminSize.touchTarget,
            child: Row(
              children: [
                // `Flexible`: uz veće pismo tekst bi gurnuo strelicu van ekrana.
                Flexible(
                  child: Text(
                    sNazivom ? 'Naziv, kategorija i opis' : 'Kategorija i opis',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.labelMedium?.copyWith(color: boje.accent),
                  ),
                ),
                Icon(
                  _detalji ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: boje.accent,
                ),
              ],
            ),
          ),
        ),
        if (_detalji) ...[
          if (sNazivom) ...[
            _Labela('Naziv'),
            _nazivPolje(),
            const SizedBox(height: AdminSpacing.md),
          ],
          _Labela('Kategorija'),
          TextFormField(
            controller: _kategorija,
            style: tema.bodyLarge,
            decoration: _polje(context),
          ),
          const SizedBox(height: AdminSpacing.md),
          _Labela('Opis'),
          TextFormField(
            controller: _opis,
            maxLines: 2,
            style: tema.bodyLarge,
            decoration: _polje(context),
          ),
          const SizedBox(height: AdminSpacing.sm),
        ],
      ],
    );
  }

  Widget _vidljivo(
    BuildContext context, {
    required double sirina,
    required double visina,
    required TextStyle? naslov,
  }) {
    final boje = context.adminColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vidljivo u aplikaciji', style: naslov),
              Text(
                'klijenti mogu sami zakazati',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: boje.textSecondary),
              ),
            ],
          ),
        ),
        UslugaPrekidac(
          vrijednost: _aktivna,
          sirina: sirina,
          visina: visina,
          oznaka: 'Vidljivo u aplikaciji',
          onChanged: _cuvanje ? null : (v) => setState(() => _aktivna = v),
        ),
      ],
    );
  }

  List<Widget> _greskaTekst(BuildContext context) => [
    if (_greska case final greska?) ...[
      const SizedBox(height: AdminSpacing.sm),
      Text(
        greska,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];
}

/// Labela iznad polja — `3f`/`3q`: 14 px, 500, 8 px do polja.
class _Labela extends StatelessWidget {
  const _Labela(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
    child: Text(
      tekst,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: context.adminColors.textSecondary),
    ),
  );
}

/// Dugme izbora trajanja u `3q` — 50 px, popunjeno kad je izabrano.
class _Izbor extends StatelessWidget {
  const _Izbor({
    required this.tekst,
    required this.izabran,
    required this.onTap,
    this.oznaka,
  });

  final String tekst;
  final bool izabran;
  final VoidCallback onTap;
  final String? oznaka;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final stil = barlowTabular(
      size: 16,
      weight: izabran ? 600 : 400,
      color: izabran ? boje.onAccent : boje.textSecondary,
    );
    return Semantics(
      button: true,
      selected: izabran,
      label: oznaka,
      child: Material(
        color: izabran ? boje.accent : boje.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.base),
          side: izabran ? BorderSide.none : BorderSide(color: boje.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadius.base),
          ),
          child: SizedBox(
            height: 50,
            child: Center(child: Text(tekst, maxLines: 1, style: stil)),
          ),
        ),
      ),
    );
  }
}

/// − / + uz cijenu u `3q` — 40×40 na podlozi, bez obruba.
class _Korak extends StatelessWidget {
  const _Korak({
    required this.ikona,
    required this.oznaka,
    required this.onTap,
  });

  final IconData ikona;
  final String oznaka;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.adminColors.ground,
    borderRadius: BorderRadius.circular(AdminRadius.small),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminRadius.small),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(
          ikona,
          size: 18,
          semanticLabel: oznaka,
          color: context.adminColors.textSecondary,
        ),
      ),
    ),
  );
}

/// Polje široko koliko tekst u njemu, da „KM" stoji odmah iza broja kao u `3q`.
///
/// `TextField` nema intrinzičnu širinu po sadržaju; mjeri se isti tekst istim stilom.
class _SirinaTeksta extends StatefulWidget {
  const _SirinaTeksta({
    required this.kontroler,
    required this.stil,
    required this.child,
  });

  final TextEditingController kontroler;
  final TextStyle stil;
  final Widget child;

  @override
  State<_SirinaTeksta> createState() => _SirinaTekstaState();
}

class _SirinaTekstaState extends State<_SirinaTeksta> {
  @override
  void initState() {
    super.initState();
    widget.kontroler.addListener(_osvjezi);
  }

  @override
  void dispose() {
    widget.kontroler.removeListener(_osvjezi);
    super.dispose();
  }

  void _osvjezi() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tekst = widget.kontroler.text.isEmpty ? '0' : widget.kontroler.text;
    final mjera = TextPainter(
      text: TextSpan(text: tekst, style: widget.stil),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // + kursor; gornja granica čuva − i + od potiskivanja na uskom ekranu.
    final sirina = (mjera.width + 4).clamp(16.0, 160.0);
    mjera.dispose();
    return SizedBox(width: sirina, child: widget.child);
  }
}

/// `"20.50"` → 2050. `null` za neispravan tekst.
int? _uCente(String normalizovano) {
  final dijelovi = normalizovano.split('.');
  if (dijelovi.length != 2) return null;
  final km = int.tryParse(dijelovi[0]);
  final centi = int.tryParse(dijelovi[1]);
  if (km == null || centi == null) return null;
  return km * 100 + centi;
}

/// 2000 → `20`, 1250 → `12,50`. Zarez, jer ga `normalizeServicePrice` prima i jer se
/// tako piše na bosanskom.
String _centiUTekst(int centi) {
  final km = centi ~/ 100;
  final ostatak = centi % 100;
  return ostatak == 0 ? '$km' : '$km,${ostatak.toString().padLeft(2, '0')}';
}
