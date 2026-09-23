/// Postavke lokacije — `3i` na desktopu, ulaz preko „Još" (`3t`) na telefonu.
///
/// ## Salon mijenja svoje, platforma svoje
///
/// Kartice ekrana pišu tri različite stvari, i granica među njima nije stilska:
/// **osnovni podaci i kontakt** su `salons` red koji klijent vidi na Početnoj,
/// **Zakazivanje** i **Rezervacija i otkazivanje** su `salon_settings` koji availability
/// engine stvarno primjenjuje, a **Pravila salona** su `salon_policies` — samo one sekcije
/// `/terms` ekrana koje obavezuju salon.
///
/// **Zakazivanje, Cijene i „Vaši podaci" se odavde ne mogu dotaći** (`app_policies`,
/// [ADR-0009]). Te tri sekcije obavezuju firmu pod čijim imenom aplikacija stoji u storeu
/// i iste su u svakoj brandiranoj app-i; ekran ih prikazuje kao zaključan popis, jer
/// vlasnik koji ih ne vidi ne zna ni da postoje ni zašto ih ne može mijenjati.
///
/// ## Jedno „Sačuvaj" za cijeli ekran
///
/// `3i` crta jedno koralno dugme u top baru, ne dugme po kartici. Zato forma živi u jednom
/// stanju ([_PostavkeState]) i snima i `salons` i `salon_settings` u istom potezu.
///
/// ## Šta `3i` crta, a iza čega nema podatka
///
/// Lista čekanja, podsjetnici, promjena naslovne fotografije, pregled u aplikaciji i
/// upravljanje pristupom nemaju ni kolonu ni RPC. Crtaju se kao ugašene kontrole koje na
/// dodir kažu „uskoro" — kontrola koja se pomjeri, a ne snimi ništa, laže.
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
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_verzal.dart';
import '../../core/widgets/admin_wordmark.dart';
import 'settings_dialogs.dart';
import 'settings_providers.dart';

/// Mjere izmjerene iz `3i` (2× izvoz). Stoje zajedno jer opisuju isti oblik kartice.
abstract final class _Mjera {
  /// Unutrašnji rub kartice.
  static const double kartica = 22;

  /// Razmak između kolona i između kartica.
  static const double kolone = 20;
  static const double kartice = 18;

  /// Vertikalni padding reda sa prekidačem.
  static const double red = 14;

  /// Visina dugmeta u top baru.
  static const double dugme = 42;
}

/// SnackBar za kontrolu koja je nacrtana, a funkcija iza nje još ne postoji.
void _uskoro(BuildContext context, String poruka) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(poruka)));
}

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(postavkeSalonProvider);
    final pravila = ref.watch(postavkeBookingProvider);

    // Oba upita moraju stići prije nego se forma nacrta: polje koje se popuni tek u
    // drugom frameu pregazi ono što je vlasnik u međuvremenu ukucao. Osvježavanje poslije
    // snimanja **ne** vraća skeleton — forma bi se tada uništila usred poruke o uspjehu.
    final ucitava =
        (!salon.hasValue && !salon.hasError) ||
        (!pravila.hasValue && !pravila.hasError);
    final greska =
        (salon.hasError && !salon.hasValue) ||
        (pravila.hasError && !pravila.hasValue);

    if (ucitava) {
      return const _Okvir(
        body: Padding(
          padding: EdgeInsets.all(AdminSpacing.gutterDesktop),
          child: AdminSkeletonList(),
        ),
      );
    }
    if (greska) {
      return _Okvir(
        body: _Greska(
          onRetry: () {
            ref.invalidate(postavkeSalonProvider);
            ref.invalidate(postavkeBookingProvider);
          },
        ),
      );
    }

    final s = salon.valueOrNull;
    final p = pravila.valueOrNull;
    if (s == null || p == null) {
      return const _Okvir(body: Center(child: Text('Salon nije učitan.')));
    }

    return _Postavke(key: ValueKey(s.id), salon: s, postavke: p);
  }
}

/// Ljuska ekrana: top bar sa akcijama na desktopu, bijelo zaglavlje na telefonu.
///
/// [onSacuvaj] `null` znači ugašeno dugme — dok se učitava ili snima.
class _Okvir extends StatelessWidget {
  const _Okvir({required this.body, this.onSacuvaj, this.snimam = false});

  final Widget body;
  final VoidCallback? onSacuvaj;
  final bool snimam;

  @override
  Widget build(BuildContext context) {
    final jeDesktop = AdminShell.jeDesktop(context);

    return AdminScaffold(
      title: 'Postavke',
      aktivna: AdminRoute.settings,
      // Telefon crta veliki naslov u tijelu (kao `3k`/`3t`), a „Sačuvaj" stoji uz njega.
      sopstvenoZaglavlje: !jeDesktop,
      actions: jeDesktop
          ? [_TopBarAkcije(onSacuvaj: onSacuvaj, snimam: snimam)]
          : null,
      body: jeDesktop
          ? body
          : Column(
              children: [
                _MobilnoZaglavlje(onSacuvaj: onSacuvaj, snimam: snimam),
                Expanded(child: body),
              ],
            ),
    );
  }
}

/// „Pregled u aplikaciji" i „SAČUVAJ" iz `3i`.
class _TopBarAkcije extends StatelessWidget {
  const _TopBarAkcije({required this.onSacuvaj, required this.snimam});

  final VoidCallback? onSacuvaj;
  final bool snimam;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _Mjera.dugme,
          child: OutlinedButton(
            // Nema rute koja bi pokazala klijentsku aplikaciju iz admina.
            onPressed: () =>
                _uskoro(context, 'Pregled u aplikaciji stiže uskoro.'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 17),
            ),
            child: const Text('Pregled u aplikaciji'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: _Mjera.dugme,
          child: FilledButton(
            onPressed: onSacuvaj,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 19),
              textStyle: AdminText.actionLabel,
            ),
            child: AdminVerzal(snimam ? 'Čuvanje…' : 'Sačuvaj'),
          ),
        ),
      ],
    );
  }
}

/// Bijela traka sa naslovom na telefonu — isti oblik kao zaglavlje `3k`.
class _MobilnoZaglavlje extends StatelessWidget {
  const _MobilnoZaglavlje({required this.onSacuvaj, required this.snimam});

  final VoidCallback? onSacuvaj;
  final bool snimam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.md,
        AdminSpacing.gutterMobile,
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Postavke', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Ovo klijenti vide u aplikaciji.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            SizedBox(
              height: AdminSize.buttonHeight,
              child: FilledButton(
                onPressed: onSacuvaj,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AdminSize.buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: AdminText.actionLabel,
                ),
                child: AdminVerzal(snimam ? 'Čuvanje…' : 'Sačuvaj'),
              ),
            ),
          ],
        ),
      ),
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

// ---------------------------------------------------------------------------
// Forma
// ---------------------------------------------------------------------------

class _Postavke extends ConsumerStatefulWidget {
  const _Postavke({required this.salon, required this.postavke, super.key});

  final Salon salon;
  final SalonSettings postavke;

  @override
  ConsumerState<_Postavke> createState() => _PostavkeState();
}

class _PostavkeState extends ConsumerState<_Postavke> {
  final _form = GlobalKey<FormState>();

  // `salons` — osnovni podaci i kontakt.
  late final TextEditingController _naziv;
  late final TextEditingController _adresa;
  late final TextEditingController _grad;
  late final TextEditingController _opis;
  late final TextEditingController _telefon;
  late final TextEditingController _email;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;

  // `salon_settings` — brojevi idu kroz polja, prekidači kroz [_unos].
  late BookingSettingsInput _unos;
  late final TextEditingController _buffer;
  late final TextEditingController _korak;
  late final TextEditingController _najranije;
  late final TextEditingController _najkasnije;
  late final TextEditingController _rokOtkazivanja;

  bool _snimam = false;

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
      _naziv,
      _adresa,
      _grad,
      _opis,
      _telefon,
      _email,
      _instagram,
      _facebook,
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

  void _promijeni(BookingSettingsInput Function(BookingSettingsInput) izmjena) {
    if (_snimam) return;
    setState(() => _unos = izmjena(_unos));
  }

  Future<void> _sacuvaj() async {
    if (!(_form.currentState?.validate() ?? false)) {
      _uskoro(context, 'Provjerite označena polja.');
      return;
    }
    setState(() => _snimam = true);

    final unos = _unos.copyWith(
      bufferMinutes: int.parse(_buffer.text),
      slotStepMinutes: int.parse(_korak.text),
      minAdvanceBookingHours: int.parse(_najranije.text),
      maxAdvanceBookingDays: int.parse(_najkasnije.text),
      minCancelHours: int.parse(_rokOtkazivanja.text),
    );

    String poruka;
    try {
      final akcije = ref.read(settingsActionsProvider);
      await akcije.sacuvajKontakt(
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
      await akcije.sacuvajPravila(unos);
      _unos = unos;
      poruka =
          'Sačuvano. Pravila vrijede odmah, bez nove verzije u prodavnici.';
    } on ApiError catch (error) {
      poruka = error.message;
    } catch (_) {
      poruka = 'Postavke se ne mogu sačuvati.';
    }
    if (!mounted) return;
    setState(() => _snimam = false);
    _uskoro(context, poruka);
  }

  /// Cijeli broj u rasponu; poruka je uz polje, ne uz formu.
  String? _raspon(String? v, {required int min, required int max}) {
    final n = int.tryParse(v ?? '');
    return n == null || n < min || n > max ? '$min–$max' : null;
  }

  @override
  Widget build(BuildContext context) {
    final jeDesktop = AdminShell.jeDesktop(context);
    final gutter = AdminShell.gutterOf(context);

    final osnovno = _OsnovnaKartica(
      salon: widget.salon,
      naziv: _naziv,
      telefon: _telefon,
      adresa: _adresa,
      opis: _opis,
    );
    final zakazivanje = _ZakazivanjeKartica(
      unos: _unos,
      onChanged: _snimam ? null : _promijeni,
    );
    const obavijesti = _ObavijestiKartica();
    final kontakt = _KontaktKartica(
      grad: _grad,
      email: _email,
      instagram: _instagram,
      facebook: _facebook,
    );
    final rezervacija = _RezervacijaKartica(
      unos: _unos,
      onChanged: _snimam ? null : _promijeni,
      buffer: _buffer,
      korak: _korak,
      najranije: _najranije,
      najkasnije: _najkasnije,
      rokOtkazivanja: _rokOtkazivanja,
      raspon: _raspon,
    );
    const pristup = _PristupKartica();
    const salonska = _SalonskaPravila();
    const platformska = _PlatformskaPravila();

    return _Okvir(
      onSacuvaj: _snimam ? null : _sacuvaj,
      snimam: _snimam,
      body: Form(
        key: _form,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `bandZa` nad stvarnom širinom radne površine, ne prozora — sidebar je
            // već oduzeo svojih 236 px.
            final jednaKolona = AdminShell.bandZa(constraints.maxWidth)
                .jeCompact;

            final sadrzaj = jednaKolona
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _razmaknuto([
                      if (jeDesktop) const _Naslov(),
                      osnovno,
                      zakazivanje,
                      obavijesti,
                      kontakt,
                      rezervacija,
                      salonska,
                      platformska,
                      pristup,
                    ]),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lijevo `salons`, desno ponašanje — kako `3i` dijeli ekran.
                      // Kartice kojih nema u izvozu idu ispod lijeve, da desna kolona
                      // ostane tačno kako je nacrtana.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _razmaknuto([
                            const _Naslov(),
                            osnovno,
                            kontakt,
                            rezervacija,
                            salonska,
                            platformska,
                          ]),
                        ),
                      ),
                      const SizedBox(width: _Mjera.kolone),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _razmaknuto([
                            zakazivanje,
                            obavijesti,
                            pristup,
                          ]),
                        ),
                      ),
                    ],
                  );

            return ListView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                jeDesktop ? AdminSpacing.gutterDesktop : 14,
                gutter,
                AdminSpacing.xxxl,
              ),
              children: [
                // Preko cijele radne površine, kao „Danas": vlasnik je tražio da se
                // ekrani ne zaustavljaju na fiksnoj širini.
                sadrzaj,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kartice sa razmakom iz `3i`; naslov ekrana ima svoj, manji.
List<Widget> _razmaknuto(List<Widget> djeca) => [
  for (var i = 0; i < djeca.length; i++) ...[
    if (i > 0) SizedBox(height: djeca[i - 1] is _Naslov ? 16 : _Mjera.kartice),
    djeca[i],
  ],
];

/// „Postavke lokacije" i red ispod — samo na desktopu; telefon ga nosi u zaglavlju.
class _Naslov extends StatelessWidget {
  const _Naslov();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Postavke lokacije', style: AdminText.display),
      const SizedBox(height: 4),
      Text(
        'Ovo klijenti vide u aplikaciji.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Gradivni dijelovi
// ---------------------------------------------------------------------------

/// Bijela kartica sa rubom `cardEdge` (iz teme) i paddingom iz `3i`.
class _Kartica extends StatelessWidget {
  const _Kartica({required this.child, this.naslov, this.dno = 20});

  final String? naslov;
  final Widget child;

  /// Donji padding: kartica sa redovima ga ima manjeg, jer red nosi svoj.
  final double dno;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        _Mjera.kartica,
        _Mjera.kartica,
        _Mjera.kartica,
        dno,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (naslov case final n?) ...[
            Text(n, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AdminSpacing.sm),
          ],
          child,
        ],
      ),
    ),
  );
}

/// Redovi razdvojeni hairline linijom — ne ispod zadnjeg, jer bi udvojila rub kartice.
class _Redovi extends StatelessWidget {
  const _Redovi({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          Divider(
            height: AdminSize.hairline,
            thickness: AdminSize.hairline,
            color: context.adminColors.separator,
          ),
        children[i],
      ],
    ],
  );
}

/// Labela iznad polja, kako je `3i` crta — ne Material labela u rubu polja.
class _Polje extends StatelessWidget {
  const _Polje({required this.labela, required this.child});

  final String labela;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        labela,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: context.adminColors.textSecondary),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// Polje od 46 px iz `3i`.
InputDecoration _ukras({String? pomoc}) => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  helperText: pomoc,
  helperMaxLines: 2,
);

/// Dva polja u redu kad stanu, jedno ispod drugog kad ne.
class _ParPolja extends StatelessWidget {
  const _ParPolja({required this.lijevo, this.desno});

  final Widget lijevo;
  final Widget? desno;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desno = this.desno;
      if (c.maxWidth < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            lijevo,
            if (desno != null) ...[const SizedBox(height: 16), desno],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: lijevo),
          const SizedBox(width: AdminSpacing.md),
          Expanded(child: desno ?? const SizedBox.shrink()),
        ],
      );
    },
  );
}

/// Prekidač iz `3i` — 46 × 26, plava staza, bijeli palac.
///
/// Material `Switch` je 52 × 32 sa obrubom u isključenom stanju; `3i` crta manji, bez
/// obruba. Semantiku nosi red ([_PrekidacRed]), pa je ovdje nema.
class _Prekidac extends StatelessWidget {
  const _Prekidac({required this.ukljuceno, required this.omogucen});

  final bool ukljuceno;
  final bool omogucen;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;

    return Opacity(
      opacity: omogucen ? 1 : 0.5,
      child: AnimatedContainer(
        duration: AdminDuration.fast,
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: ukljuceno ? boje.accent : boje.border,
          borderRadius: BorderRadius.circular(AdminRadius.pill),
        ),
        child: AnimatedAlign(
          duration: AdminDuration.fast,
          alignment: ukljuceno ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: boje.surface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Red sa naslovom, opcionim opisom i prekidačem desno. Cijeli red je meta dodira.
///
/// [onChanged] `null` znači ugašen red; tada [naDodir] kaže zašto (npr. „uskoro").
class _PrekidacRed extends StatelessWidget {
  const _PrekidacRed({
    required this.naslov,
    required this.ukljuceno,
    required this.onChanged,
    this.opis,
    this.naDodir,
  });

  final String naslov;
  final String? opis;
  final bool ukljuceno;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? naDodir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = this.onChanged;

    return Semantics(
      toggled: ukljuceno,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged != null ? () => onChanged(!ukljuceno) : naDodir,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _Mjera.red),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(naslov, style: theme.textTheme.titleSmall),
                      if (opis case final o?)
                        Text(
                          o,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.adminColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AdminSpacing.lg),
                ExcludeSemantics(
                  child: _Prekidac(
                    ukljuceno: ukljuceno,
                    omogucen: onChanged != null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slika sa prelivom kad je nema — isti placeholder kao u sidebaru.
class _Slika extends StatelessWidget {
  const _Slika({required this.url, required this.strana, this.krug = false});

  final String? url;
  final double strana;
  final bool krug;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [boje.sidebarMuted, boje.sidebarSelected],
        ),
      ),
    );
    final adresa = url;
    final slika = adresa == null || adresa.isEmpty
        ? placeholder
        : Image.network(
            adresa,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );

    return SizedBox(
      width: strana,
      height: strana,
      child: krug
          ? ClipOval(child: slika)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AdminRadius.small),
              child: slika,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lijeva kolona — `salons`
// ---------------------------------------------------------------------------

/// Prva kartica `3i`: naslovna fotografija, naziv, telefon i adresa, opis.
class _OsnovnaKartica extends StatelessWidget {
  const _OsnovnaKartica({
    required this.salon,
    required this.naziv,
    required this.telefon,
    required this.adresa,
    required this.opis,
  });

  final Salon salon;
  final TextEditingController naziv;
  final TextEditingController telefon;
  final TextEditingController adresa;
  final TextEditingController opis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final polje = theme.textTheme.bodyMedium;

    return _Kartica(
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Slika(url: salon.coverImageUrl, strana: 96),
              const SizedBox(width: AdminSpacing.lg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Naslovna fotografija',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Prikazuje se na vrhu profila salona',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.adminColors.textSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 11),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: OutlinedButton(
                            // Upload slike ne postoji ni u repozitoriju ni u bazi.
                            onPressed: () => _uskoro(
                              context,
                              'Promjena fotografije stiže uskoro.',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              textStyle: theme.textTheme.labelMedium,
                            ),
                            child: const Text('Promijeni'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Polje(
            labela: 'Naziv',
            child: TextFormField(
              controller: naziv,
              style: polje,
              decoration: _ukras(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Naziv je obavezan.' : null,
            ),
          ),
          const SizedBox(height: 16),
          _ParPolja(
            lijevo: _Polje(
              labela: 'Telefon',
              child: TextFormField(
                controller: telefon,
                style: polje,
                keyboardType: TextInputType.phone,
                decoration: _ukras(),
              ),
            ),
            desno: _Polje(
              labela: 'Adresa',
              child: TextFormField(
                controller: adresa,
                style: polje,
                decoration: _ukras(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Polje(
            labela: 'Opis',
            child: TextFormField(
              controller: opis,
              minLines: 4,
              maxLines: 4,
              // `3i` opis piše sivim, za razliku od ostalih polja.
              style: polje?.copyWith(color: context.adminColors.textSecondary),
              decoration: _ukras(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ostatak `salons` reda — `3i` ga ne crta, ali ga klijent vidi na Početnoj.
class _KontaktKartica extends StatelessWidget {
  const _KontaktKartica({
    required this.grad,
    required this.email,
    required this.instagram,
    required this.facebook,
  });

  final TextEditingController grad;
  final TextEditingController email;
  final TextEditingController instagram;
  final TextEditingController facebook;

  @override
  Widget build(BuildContext context) {
    final polje = Theme.of(context).textTheme.bodyMedium;

    return _Kartica(
      naslov: 'Kontakt i mreže',
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AdminSpacing.sm),
          _ParPolja(
            lijevo: _Polje(
              labela: 'Grad',
              child: TextFormField(
                controller: grad,
                style: polje,
                decoration: _ukras(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Grad je obavezan.' : null,
              ),
            ),
            desno: _Polje(
              labela: 'Email',
              child: TextFormField(
                controller: email,
                style: polje,
                keyboardType: TextInputType.emailAddress,
                decoration: _ukras(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ParPolja(
            lijevo: _Polje(
              labela: 'Instagram',
              child: TextFormField(
                controller: instagram,
                style: polje,
                keyboardType: TextInputType.url,
                decoration: _ukras(),
              ),
            ),
            // **Stranica salona, ne prijava Facebookom.** Prijava preko Facebooka ne
            // postoji (ADR-0011), pa labela govori šta polje jeste.
            desno: _Polje(
              labela: 'Facebook stranica',
              child: TextFormField(
                controller: facebook,
                style: polje,
                keyboardType: TextInputType.url,
                decoration: _ukras(
                  pomoc: 'Stranica salona, ne prijava Facebookom.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ostatak `salon_settings` — pravila koja `3i` ne crta, a engine ih primjenjuje.
class _RezervacijaKartica extends StatelessWidget {
  const _RezervacijaKartica({
    required this.unos,
    required this.onChanged,
    required this.buffer,
    required this.korak,
    required this.najranije,
    required this.najkasnije,
    required this.rokOtkazivanja,
    required this.raspon,
  });

  final BookingSettingsInput unos;
  final void Function(BookingSettingsInput Function(BookingSettingsInput))?
  onChanged;
  final TextEditingController buffer;
  final TextEditingController korak;
  final TextEditingController najranije;
  final TextEditingController najkasnije;
  final TextEditingController rokOtkazivanja;
  final String? Function(String?, {required int min, required int max}) raspon;

  @override
  Widget build(BuildContext context) {
    final promijeni = onChanged;

    return _Kartica(
      naslov: 'Rezervacija i otkazivanje',
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Redovi(
            children: [
              _PrekidacRed(
                naslov: 'Klijent bira tačno vrijeme',
                opis: 'isključeno = bira samo datum, salon rasporedi',
                ukljuceno: unos.bookingGranularity == 'exact_slot',
                onChanged: promijeni == null
                    ? null
                    : (v) => promijeni(
                        (u) => u.copyWith(
                          bookingGranularity: v ? 'exact_slot' : 'date_only',
                        ),
                      ),
              ),
              _PrekidacRed(
                naslov: 'Prikaži cijene u aplikaciji',
                ukljuceno: unos.showPricesInApp,
                onChanged: promijeni == null
                    ? null
                    : (v) => promijeni((u) => u.copyWith(showPricesInApp: v)),
              ),
              _PrekidacRed(
                naslov: 'Zakazivanje bez prijave',
                opis: 'gost može zakazati bez naloga',
                ukljuceno: unos.allowGuestBooking,
                onChanged: promijeni == null
                    ? null
                    : (v) => promijeni((u) => u.copyWith(allowGuestBooking: v)),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          _ParPolja(
            lijevo: _BrojPolje(
              controller: buffer,
              labela: 'Pauza između termina (min)',
              validator: (v) => raspon(v, min: 0, max: 120),
            ),
            desno: _BrojPolje(
              controller: korak,
              labela: 'Korak ponuđenih termina (min)',
              validator: (v) => raspon(v, min: 1, max: 120),
            ),
          ),
          const SizedBox(height: 16),
          _ParPolja(
            lijevo: _BrojPolje(
              controller: najranije,
              labela: 'Najraniji termin (sati unaprijed)',
              validator: (v) => raspon(v, min: 0, max: 720),
            ),
            desno: _BrojPolje(
              controller: najkasnije,
              labela: 'Kalendar otvoren (dana unaprijed)',
              validator: (v) => raspon(v, min: 1, max: 365),
            ),
          ),
          const SizedBox(height: 16),
          // **Ovo polje mijenja ponašanje klijentske app-e odmah.**
          // `cancel_appointment` čita rok pri svakom pozivu, ne pri rezervaciji.
          _ParPolja(
            lijevo: _BrojPolje(
              controller: rokOtkazivanja,
              labela: 'Rok za otkazivanje (sati prije termina)',
              pomoc: 'Vrijedi odmah — i za već zakazane termine.',
              validator: (v) => raspon(v, min: 0, max: 720),
            ),
          ),
        ],
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
  Widget build(BuildContext context) => _Polje(
    labela: labela,
    child: TextFormField(
      controller: controller,
      style: AdminText.dataInline.copyWith(fontSize: 15),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _ukras(pomoc: pomoc),
      validator: validator,
    ),
  );
}

// ---------------------------------------------------------------------------
// Desna kolona — ponašanje
// ---------------------------------------------------------------------------

/// „Zakazivanje" iz `3i`: ručna potvrda, izbor majstora, lista čekanja.
class _ZakazivanjeKartica extends StatelessWidget {
  const _ZakazivanjeKartica({required this.unos, required this.onChanged});

  final BookingSettingsInput unos;
  final void Function(BookingSettingsInput Function(BookingSettingsInput))?
  onChanged;

  @override
  Widget build(BuildContext context) {
    final promijeni = onChanged;

    return _Kartica(
      naslov: 'Zakazivanje',
      child: _Redovi(
        children: [
          // Način potvrde je `booking_mode`, i mijenja šta klijent vidi odmah nakon
          // rezervacije: „čeka potvrdu" ili „potvrđeno".
          _PrekidacRed(
            naslov: 'Ručna potvrda termina',
            opis: 'isključeno = termin se potvrđuje odmah',
            ukljuceno: unos.bookingMode == 'manual',
            onChanged: promijeni == null
                ? null
                : (v) => promijeni(
                    (u) => u.copyWith(bookingMode: v ? 'manual' : 'auto'),
                  ),
          ),
          _PrekidacRed(
            naslov: 'Dozvoli izbor majstora',
            opis: 'klijent bira ko ga uslužuje',
            ukljuceno: unos.requireStaffChoice,
            onChanged: promijeni == null
                ? null
                : (v) => promijeni((u) => u.copyWith(requireStaffChoice: v)),
          ),
          // Nema kolone za listu čekanja — prekidač stoji ugašen i isključen.
          _PrekidacRed(
            naslov: 'Lista čekanja',
            opis: 'nudi otkazane termine drugima',
            ukljuceno: false,
            onChanged: null,
            naDodir: () => _uskoro(context, 'Lista čekanja stiže uskoro.'),
          ),
        ],
      ),
    );
  }
}

/// „Obavijesti klijentima" iz `3i`.
///
/// Nijedna od tri nije postavka salona: potvrdu `send-push` šalje uvijek, a podsjetnike
/// (`send-reminders`) još niko ne šalje. Prekidači zato pokazuju stvarno stanje i ne
/// pomjeraju se.
class _ObavijestiKartica extends StatelessWidget {
  const _ObavijestiKartica();

  @override
  Widget build(BuildContext context) {
    void podsjetnici() => _uskoro(context, 'Podsjetnici stižu uskoro.');

    return _Kartica(
      naslov: 'Obavijesti klijentima',
      child: _Redovi(
        children: [
          _PrekidacRed(
            naslov: 'Potvrda termina',
            ukljuceno: true,
            onChanged: null,
            naDodir: () => _uskoro(
              context,
              'Potvrda termina se šalje uvijek i ne može se isključiti.',
            ),
          ),
          _PrekidacRed(
            naslov: 'Podsjetnik dan prije',
            ukljuceno: false,
            onChanged: null,
            naDodir: podsjetnici,
          ),
          _PrekidacRed(
            naslov: 'Podsjetnik sat prije',
            ukljuceno: false,
            onChanged: null,
            naDodir: podsjetnici,
          ),
        ],
      ),
    );
  }
}

/// „Pristup" iz `3i`.
///
/// Admin danas zna samo za sebe (membership, bez RBAC-a), pa lista ima jedan red — onaj
/// koji je stvaran. Uređivanje i dodavanje korisnika nemaju RPC.
class _PristupKartica extends ConsumerWidget {
  const _PristupKartica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clan = ref.watch(currentStaffProvider).valueOrNull;

    return _Kartica(
      naslov: 'Pristup',
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          if (clan != null) ...[
            Container(
              height: 62,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: context.adminColors.ground,
                borderRadius: BorderRadius.circular(AdminRadius.base),
              ),
              child: Row(
                children: [
                  const _Slika(url: null, strana: 36, krug: true),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clan.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          [?labelaUloge(clan.role), 'vi'].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.adminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _uskoro(context, 'Uređivanje pristupa stiže uskoro.'),
                    style: TextButton.styleFrom(
                      textStyle: theme.textTheme.labelMedium,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Uredi'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton(
            onPressed: () =>
                _uskoro(context, 'Dodavanje korisnika stiže uskoro.'),
            child: const Text('+ Dodaj korisnika'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pravila salona (`salon_policies`)
// ---------------------------------------------------------------------------

class _SalonskaPravila extends ConsumerWidget {
  const _SalonskaPravila();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sekcije = ref.watch(postavkeSekcijeProvider);
    final prigusen = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.adminColors.textSecondary);

    return _Kartica(
      naslov: 'Pravila salona',
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Otkazivanje, kašnjenje i kontakt — sekcije koje salon piše sam. '
            'Prikazuju se u aplikaciji na „Pravila korištenja".',
            style: prigusen,
          ),
          const SizedBox(height: AdminSpacing.sm),
          sekcije.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AdminSpacing.lg),
              child: AdminSkeletonList(redova: 3),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: AdminSpacing.md),
              child: Text('Sekcije se ne mogu učitati.'),
            ),
            data: (lista) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AdminSpacing.md,
                    ),
                    child: Text(
                      'Nema vaših sekcija. Aplikacija tada prikazuje samo '
                      'platformske — to je uredno stanje, ne greška.',
                      style: prigusen,
                    ),
                  )
                else
                  _Redovi(
                    children: [
                      for (final sekcija in lista)
                        _SekcijaRed(sekcija: sekcija),
                    ],
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => prikaziUredjivacSekcije(
                    context,
                    ref,
                    sortOrder: sljedeciSortOrder(lista),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dodaj sekciju'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SekcijaRed extends ConsumerWidget {
  const _SekcijaRed({required this.sekcija});

  final PolicySection sekcija;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sekcija.title, style: theme.textTheme.titleSmall),
                if (sekcija.paragraphs.isNotEmpty)
                  Text(
                    sekcija.paragraphs.first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Uredi',
            color: context.adminColors.accent,
            onPressed: () =>
                prikaziUredjivacSekcije(context, ref, sekcija: sekcija),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prigusen = theme.textTheme.bodySmall?.copyWith(
      color: context.adminColors.textSecondary,
    );

    return _Kartica(
      naslov: 'Pravila platforme',
      dno: _Mjera.kartica,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Iste su u svakoj aplikaciji i mijenjamo ih mi — obavezuju firmu koja '
            'aplikaciju objavljuje u prodavnici.',
            style: prigusen,
          ),
          const SizedBox(height: AdminSpacing.sm),
          _Redovi(
            children: [
              for (final naslov in _sekcije)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(naslov, style: theme.textTheme.titleSmall),
                      ),
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: context.adminColors.textMuted,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            'Politika privatnosti je u cijelosti naša i ne uređuje se ovdje.',
            style: prigusen,
          ),
        ],
      ),
    );
  }
}
