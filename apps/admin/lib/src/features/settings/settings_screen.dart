/// Postavke lokacije — `3i` na desktopu, ulaz preko „Još" (`3t`) na telefonu.
///
/// ## Salon mijenja svoje, platforma svoje
///
/// Tri sekcije ekrana pišu tri različite stvari, i granica među njima nije stilska:
/// **Osnovni podaci** su `salons` red koji klijent vidi na Početnoj, **Zakazivanje** je
/// `salon_settings` koji availability engine stvarno primjenjuje, a **Pravila salona** su
/// `salon_policies` — samo one sekcije `/terms` ekrana koje obavezuju salon.
///
/// **Zakazivanje, Cijene i „Vaši podaci" se odavde ne mogu dotaći** (`app_policies`,
/// [ADR-0009]). Te tri sekcije obavezuju firmu pod čijim imenom aplikacija stoji u storeu
/// i iste su u svakoj brandiranoj app-i; ekran ih prikazuje kao zaključan popis, jer
/// vlasnik koji ih ne vidi ne zna ni da postoje ni zašto ih ne može mijenjati.
///
/// ## Branding ovdje ne postoji
///
/// Boje i logo dolaze iz `tenant.yaml` kroz generator (`.claude/docs/tenant-factory.md`).
/// Polje za boju u adminu bi napravilo drugi izvor istine za isti podatak, a sljedeće
/// generisanje bi ga tiho vratilo na staro.
///
/// ## Pravila vrijede odmah
///
/// `min_cancel_hours` ne ulazi ni u jedan build: `cancel_appointment` ga čita pri
/// **svakom** pozivu. Promjena na ovom ekranu zato mijenja ponašanje klijentskog
/// otkazivanja bez nove verzije u storeu — što je i cijeli cilj taska.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'settings_dialogs.dart';
import 'settings_providers.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = AdminShell.gutterOf(context);
    final salon = ref.watch(postavkeSalonProvider);
    final pravila = ref.watch(postavkeBookingProvider);

    // Oba upita moraju stići prije nego se forma nacrta: polje koje se popuni tek u
    // drugom frameu pregazi ono što je vlasnik u međuvremenu ukucao.
    final ucitava = salon.isLoading || pravila.isLoading;
    final greska = salon.hasError || pravila.hasError;

    return AdminScaffold(
      title: 'Postavke',
      aktivna: AdminRoute.settings,
      body: switch ((ucitava, greska)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (_, true) => _Greska(
          onRetry: () {
            ref.invalidate(postavkeSalonProvider);
            ref.invalidate(postavkeBookingProvider);
          },
        ),
        _ => ListView(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: AdminSpacing.lg,
          ),
          children: [
            Text('Ovo klijenti vide u aplikaciji.', style: AdminText.eyebrow),
            const SizedBox(height: AdminSpacing.lg),
            if (salon.valueOrNull case final s?)
              _KontaktForma(salon: s)
            else
              const Text('Salon nije učitan.'),
            const SizedBox(height: AdminSpacing.xxl),
            if (pravila.valueOrNull case final p?) _PravilaForma(postavke: p),
            const SizedBox(height: AdminSpacing.xxl),
            const _SalonskaPravila(),
            const SizedBox(height: AdminSpacing.xxl),
            const _PlatformskaPravila(),
            const SizedBox(height: AdminSpacing.xxxl),
          ],
        ),
      },
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
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
      const Center(child: Text('Postavke se ne mogu učitati.')),
      const SizedBox(height: AdminSpacing.md),
      Center(
        child: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Pokušaj ponovo'),
        ),
      ),
    ],
  );
}

/// Naslov sekcije sa karticom ispod — isti oblik za sve četiri grupe.
class _Sekcija extends StatelessWidget {
  const _Sekcija({
    required this.naslov,
    required this.podnaslov,
    required this.child,
  });

  final String naslov;
  final String podnaslov;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(naslov, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AdminSpacing.xs),
      Text(
        podnaslov,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: context.adminColors.textMuted),
      ),
      const SizedBox(height: AdminSpacing.md),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: child,
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Osnovni podaci
// ---------------------------------------------------------------------------

class _KontaktForma extends ConsumerStatefulWidget {
  const _KontaktForma({required this.salon});

  final Salon salon;

  @override
  ConsumerState<_KontaktForma> createState() => _KontaktFormaState();
}

class _KontaktFormaState extends ConsumerState<_KontaktForma> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _naziv;
  late final TextEditingController _adresa;
  late final TextEditingController _grad;
  late final TextEditingController _opis;
  late final TextEditingController _telefon;
  late final TextEditingController _email;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;

  bool _snimam = false;
  String? _greska;
  String? _poruka;

  @override
  void initState() {
    super.initState();
    final s = widget.salon;
    _naziv = TextEditingController(text: s.name);
    _adresa = TextEditingController(text: s.address);
    _grad = TextEditingController(text: s.city);
    _opis = TextEditingController(text: s.description);
    // `null` i prazan string su isto stanje (v. `update_salon_contact`), pa polje pokazuje
    // prazno u oba slučaja.
    _telefon = TextEditingController(text: s.phone ?? '');
    _email = TextEditingController(text: s.email ?? '');
    _instagram = TextEditingController(text: s.instagramUrl ?? '');
    _facebook = TextEditingController(text: s.facebookUrl ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _naziv,
      _adresa,
      _grad,
      _opis,
      _telefon,
      _email,
      _instagram,
      _facebook,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sacuvaj() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _snimam = true;
      _greska = null;
      _poruka = null;
    });

    try {
      await ref
          .read(settingsActionsProvider)
          .sacuvajKontakt(
            ContactInput(
              name: _naziv.text,
              address: _adresa.text,
              city: _grad.text,
              description: _opis.text,
              phone: _telefon.text,
              email: _email.text,
              instagramUrl: _instagram.text,
              facebookUrl: _facebook.text,
            ),
          );
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _poruka = 'Podaci su sačuvani.';
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Podaci se ne mogu sačuvati.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sekcija(
      naslov: 'Osnovni podaci',
      podnaslov: 'Naziv, kontakt i opis koje klijent vidi u aplikaciji.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _naziv,
              decoration: const InputDecoration(labelText: 'Naziv'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Naziv je obavezan.' : null,
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _adresa,
              decoration: const InputDecoration(labelText: 'Adresa'),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _grad,
              decoration: const InputDecoration(labelText: 'Grad'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Grad je obavezan.' : null,
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _opis,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Opis'),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _telefon,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _instagram,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Instagram'),
            ),
            const SizedBox(height: AdminSpacing.md),
            // **Stranica salona, ne prijava Facebookom.** Prijava preko Facebooka ne
            // postoji (ADR-0011), pa labela govori šta polje jeste.
            TextFormField(
              controller: _facebook,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Facebook stranica',
                helperText: 'Stranica salona, ne prijava Facebookom.',
              ),
            ),
            if (_greska case final greska?) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                greska,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_poruka case final poruka?) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                poruka,
                style: TextStyle(color: context.adminColors.positiveInk),
              ),
            ],
            const SizedBox(height: AdminSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _snimam ? null : _sacuvaj,
                child: Text(_snimam ? 'Čuvanje…' : 'Sačuvaj podatke'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking pravila
// ---------------------------------------------------------------------------

class _PravilaForma extends ConsumerStatefulWidget {
  const _PravilaForma({required this.postavke});

  final SalonSettings postavke;

  @override
  ConsumerState<_PravilaForma> createState() => _PravilaFormaState();
}

class _PravilaFormaState extends ConsumerState<_PravilaForma> {
  final _form = GlobalKey<FormState>();
  late BookingSettingsInput _unos;
  late final TextEditingController _buffer;
  late final TextEditingController _korak;
  late final TextEditingController _najranije;
  late final TextEditingController _najkasnije;
  late final TextEditingController _rokOtkazivanja;

  bool _snimam = false;
  String? _greska;
  String? _poruka;

  @override
  void initState() {
    super.initState();
    _unos = BookingSettingsInput.from(widget.postavke);
    _buffer = TextEditingController(text: '${_unos.bufferMinutes}');
    _korak = TextEditingController(text: '${_unos.slotStepMinutes}');
    _najranije = TextEditingController(text: '${_unos.minAdvanceBookingHours}');
    _najkasnije = TextEditingController(text: '${_unos.maxAdvanceBookingDays}');
    _rokOtkazivanja = TextEditingController(text: '${_unos.minCancelHours}');
  }

  @override
  void dispose() {
    for (final c in [
      _buffer,
      _korak,
      _najranije,
      _najkasnije,
      _rokOtkazivanja,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sacuvaj() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _snimam = true;
      _greska = null;
      _poruka = null;
    });

    final unos = _unos.copyWith(
      bufferMinutes: int.parse(_buffer.text),
      slotStepMinutes: int.parse(_korak.text),
      minAdvanceBookingHours: int.parse(_najranije.text),
      maxAdvanceBookingDays: int.parse(_najkasnije.text),
      minCancelHours: int.parse(_rokOtkazivanja.text),
    );

    try {
      await ref.read(settingsActionsProvider).sacuvajPravila(unos);
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _unos = unos;
        _poruka = 'Pravila vrijede odmah, bez nove verzije u prodavnici.';
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snimam = false;
        _greska = 'Pravila se ne mogu sačuvati.';
      });
    }
  }

  /// Cijeli broj u rasponu; poruka je uz polje, ne uz formu.
  String? _raspon(String? v, {required int min, required int max}) {
    final n = int.tryParse(v ?? '');
    return n == null || n < min || n > max ? '$min–$max' : null;
  }

  @override
  Widget build(BuildContext context) {
    return _Sekcija(
      naslov: 'Zakazivanje',
      podnaslov: 'Pravila koja aplikacija primjenjuje pri rezervaciji.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Način potvrde je `booking_mode`, i mijenja šta klijent vidi odmah nakon
            // rezervacije: „čeka potvrdu" ili „potvrđeno".
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ručna potvrda termina'),
              subtitle: const Text('Isključeno — termin se potvrđuje odmah.'),
              value: _unos.bookingMode == 'manual',
              onChanged: _snimam
                  ? null
                  : (v) => setState(
                      () => _unos = _unos.copyWith(
                        bookingMode: v ? 'manual' : 'auto',
                      ),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Klijent bira tačno vrijeme'),
              subtitle: const Text(
                'Isključeno — klijent bira samo datum, salon rasporedi.',
              ),
              value: _unos.bookingGranularity == 'exact_slot',
              onChanged: _snimam
                  ? null
                  : (v) => setState(
                      () => _unos = _unos.copyWith(
                        bookingGranularity: v ? 'exact_slot' : 'date_only',
                      ),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dozvoli izbor majstora'),
              subtitle: const Text('Klijent bira ko ga uslužuje.'),
              value: _unos.requireStaffChoice,
              onChanged: _snimam
                  ? null
                  : (v) => setState(
                      () => _unos = _unos.copyWith(requireStaffChoice: v),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prikaži cijene u aplikaciji'),
              value: _unos.showPricesInApp,
              onChanged: _snimam
                  ? null
                  : (v) => setState(
                      () => _unos = _unos.copyWith(showPricesInApp: v),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zakazivanje bez prijave'),
              subtitle: const Text('Gost može zakazati bez naloga.'),
              value: _unos.allowGuestBooking,
              onChanged: _snimam
                  ? null
                  : (v) => setState(
                      () => _unos = _unos.copyWith(allowGuestBooking: v),
                    ),
            ),
            const SizedBox(height: AdminSpacing.md),
            _BrojPolje(
              controller: _buffer,
              labela: 'Pauza između termina (min)',
              validator: (v) => _raspon(v, min: 0, max: 120),
            ),
            const SizedBox(height: AdminSpacing.md),
            _BrojPolje(
              controller: _korak,
              labela: 'Korak ponuđenih termina (min)',
              validator: (v) => _raspon(v, min: 1, max: 120),
            ),
            const SizedBox(height: AdminSpacing.md),
            _BrojPolje(
              controller: _najranije,
              labela: 'Najraniji termin (sati unaprijed)',
              validator: (v) => _raspon(v, min: 0, max: 720),
            ),
            const SizedBox(height: AdminSpacing.md),
            _BrojPolje(
              controller: _najkasnije,
              labela: 'Kalendar otvoren (dana unaprijed)',
              validator: (v) => _raspon(v, min: 1, max: 365),
            ),
            const SizedBox(height: AdminSpacing.md),
            // **Ovo polje mijenja ponašanje klijentske app-e odmah.**
            // `cancel_appointment` čita rok pri svakom pozivu, ne pri rezervaciji.
            _BrojPolje(
              controller: _rokOtkazivanja,
              labela: 'Rok za otkazivanje (sati prije termina)',
              pomoc: 'Vrijedi odmah — i za već zakazane termine.',
              validator: (v) => _raspon(v, min: 0, max: 720),
            ),
            if (_greska case final greska?) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                greska,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_poruka case final poruka?) ...[
              const SizedBox(height: AdminSpacing.sm),
              Text(
                poruka,
                style: TextStyle(color: context.adminColors.positiveInk),
              ),
            ],
            const SizedBox(height: AdminSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _snimam ? null : _sacuvaj,
                child: Text(_snimam ? 'Čuvanje…' : 'Sačuvaj pravila'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrojPolje extends StatelessWidget {
  const _BrojPolje({
    required this.controller,
    required this.labela,
    required this.validator,
    this.pomoc,
  });

  final TextEditingController controller;
  final String labela;
  final String? pomoc;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: labela, helperText: pomoc),
    validator: validator,
  );
}

// ---------------------------------------------------------------------------
// Pravila salona (`salon_policies`)
// ---------------------------------------------------------------------------

class _SalonskaPravila extends ConsumerWidget {
  const _SalonskaPravila();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekcije = ref.watch(postavkeSekcijeProvider);

    return _Sekcija(
      naslov: 'Pravila salona',
      podnaslov:
          'Otkazivanje, kašnjenje i kontakt — sekcije koje salon piše sam. '
          'Prikazuju se u aplikaciji na „Pravila korištenja".',
      child: sekcije.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AdminSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => const Text('Sekcije se ne mogu učitati.'),
        data: (lista) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                child: Text(
                  'Nema vaših sekcija. Aplikacija tada prikazuje samo '
                  'platformske — to je uredno stanje, ne greška.',
                  style: TextStyle(color: context.adminColors.textMuted),
                ),
              ),
            for (final sekcija in lista)
              _SekcijaRed(sekcija: sekcija, zadnja: sekcija == lista.last),
            const SizedBox(height: AdminSpacing.md),
            OutlinedButton.icon(
              onPressed: () => prikaziUredjivacSekcije(
                context,
                ref,
                sortOrder: sljedeciSortOrder(lista),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj sekciju'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SekcijaRed extends ConsumerWidget {
  const _SekcijaRed({required this.sekcija, required this.zadnja});

  final PolicySection sekcija;
  final bool zadnja;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(sekcija.title),
        subtitle: Text(
          sekcija.paragraphs.isEmpty ? '' : sekcija.paragraphs.first,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Uredi',
          onPressed: () =>
              prikaziUredjivacSekcije(context, ref, sekcija: sekcija),
        ),
      ),
      if (!zadnja)
        Divider(
          height: AdminSize.hairline,
          thickness: AdminSize.hairline,
          color: context.adminColors.separator,
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Platformska pravila — vidljiva, zaključana
// ---------------------------------------------------------------------------

/// Zaključan popis sekcija koje piše platforma.
///
/// **Postoji zato što nevidljivo ograničenje izgleda kao kvar.** Vlasnik koji na `/terms`
/// vidi šest sekcija, a u postavkama tri, prijavljuje da mu „fale pravila". Ovdje piše
/// koje su i zašto ih ne može mijenjati (ADR-0009). Lista je kratka i statična jer je
/// ista u svakoj brandiranoj app-i — čitanje iz `app_policies` bi dodalo upit koji ne
/// mijenja ništa što je vlasniku upotrebljivo.
class _PlatformskaPravila extends StatelessWidget {
  const _PlatformskaPravila();

  static const _sekcije = ['Zakazivanje', 'Cijene', 'Vaši podaci'];

  @override
  Widget build(BuildContext context) => _Sekcija(
    naslov: 'Pravila platforme',
    podnaslov:
        'Iste su u svakoj aplikaciji i mijenjamo ih mi — obavezuju firmu koja '
        'aplikaciju objavljuje u prodavnici.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final naslov in _sekcije)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              Icons.lock_outline,
              size: 18,
              color: context.adminColors.textMuted,
            ),
            title: Text(naslov),
          ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          'Politika privatnosti je u cijelosti naša i ne uređuje se ovdje.',
          style: TextStyle(color: context.adminColors.textMuted),
        ),
      ],
    ),
  );
}
