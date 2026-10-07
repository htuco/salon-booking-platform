import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/admin_toast.dart';
import '../../core/widgets/admin_verzal.dart';
import '../../core/widgets/admin_wordmark.dart';
import '../appointments/appointments_providers.dart';
import 'profilna_slika.dart';

/// `4b` / `4d` — Moj profil: podaci i slika **osobe**, ne salona (task 61).
///
/// Postavke lokacije (`3i`) ostaju salonske; ovdje je ono što pripada nalogu: ime, telefon,
/// profilna slika, lozinka i sesije.
///
/// **Jedan salon po nalogu.** Handoff crta listu članstava i „Koristi svuda"; nalog osoblja
/// ovdje pripada jednom salonu (`public.users.salon_id`), pa je lista jedan red i glavni
/// prekidač nema šta da sabere. Kad nalog dobije više salona, red postaje lista.
///
/// Prekidač i slika se snimaju odmah; ime i telefon na „Sačuvaj" (handoff, §Save).
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stanje = ref.watch(currentStaffProvider);
    final clan = stanje.valueOrNull;
    if (clan == null) {
      return AdminScaffold(
        title: 'Moj profil',
        header: AppHeader(title: 'Moj profil', tabRoot: false),
        body: stanje.isLoading
            ? const Padding(
                padding: EdgeInsets.all(AdminSpacing.gutterDesktop),
                child: AdminSkeletonList(),
              )
            : const Center(child: Text('Profil nije učitan.')),
      );
    }
    return _Profil(key: ValueKey(clan.id), clan: clan);
  }
}

class _Profil extends ConsumerStatefulWidget {
  const _Profil({required this.clan, super.key});

  final StaffMember clan;

  @override
  ConsumerState<_Profil> createState() => _ProfilState();
}

class _ProfilState extends ConsumerState<_Profil> {
  late final _ime = TextEditingController(text: widget.clan.name);
  late final _telefon = TextEditingController(text: widget.clan.phone);
  bool _snimam = false;

  bool get _izmijenjeno =>
      _ime.text.trim() != widget.clan.name ||
      _telefon.text.trim() != widget.clan.phone;

  @override
  void initState() {
    super.initState();
    _ime.addListener(_osvjezi);
    _telefon.addListener(_osvjezi);
  }

  void _osvjezi() => setState(() {});

  @override
  void didUpdateWidget(covariant _Profil stari) {
    super.didUpdateWidget(stari);
    // Nova slika ili prekidač osvježe člana; polja koja korisnik još kuca se ne diraju.
    if (!_izmijenjenoPrema(stari.clan)) {
      _ime.text = widget.clan.name;
      _telefon.text = widget.clan.phone;
    }
  }

  bool _izmijenjenoPrema(StaffMember c) =>
      _ime.text.trim() != c.name || _telefon.text.trim() != c.phone;

  @override
  void dispose() {
    _ime.dispose();
    _telefon.dispose();
    super.dispose();
  }

  void _odustani() {
    _ime.text = widget.clan.name;
    _telefon.text = widget.clan.phone;
  }

  Future<void> _sacuvaj() async {
    setState(() => _snimam = true);
    try {
      await ref
          .read(staffRepositoryProvider)
          .updateProfile(name: _ime.text, phone: _telefon.text);
      if (!mounted) return;
      ref.invalidate(currentStaffProvider);
      AdminToast.uspjeh(context, 'Profil je sačuvan.');
    } catch (e) {
      if (mounted) AdminToast.greska(context, porukaGreske(e));
    } finally {
      if (mounted) setState(() => _snimam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AdminShell.jeDesktop(context);
    final onSacuvaj = _izmijenjeno && !_snimam ? _sacuvaj : null;
    final clan = widget.clan;

    final licni = _LicniPodaci(
      ime: _ime,
      telefon: _telefon,
      email: clan.email,
      desktop: desktop,
    );

    final sadrzaj = desktop
        ? ListView(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.gutterDesktop,
              AdminSpacing.xxxl,
              AdminSpacing.gutterDesktop,
              AdminSpacing.xxxl,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Moj profil',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vaši lični podaci i slika — važe za salon u kojem radite.',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: context.adminColors.textSecondary),
                    ),
                    const SizedBox(height: AdminSpacing.xxl),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 280,
                            child: _Kartica(child: _SlikaDesktop(clan: clan)),
                          ),
                          const SizedBox(width: AdminSpacing.lg),
                          Expanded(child: _Kartica(child: licni)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.lg),
                    _Kartica(
                      bezPaddinga: true,
                      child: _SlikaUSalonu(clan: clan, desktop: true),
                    ),
                    const SizedBox(height: AdminSpacing.lg),
                    _Kartica(
                      bezPaddinga: true,
                      child: _Sigurnost(clan: clan, desktop: true),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.gutterMobile,
              AdminSpacing.xxl,
              AdminSpacing.gutterMobile,
              AdminSpacing.xxxl,
            ),
            children: [
              _SlikaTelefon(clan: clan),
              _Grupa(naslov: 'Lični podaci', child: licni),
              _Grupa(
                naslov: 'Slika u salonu',
                napomena: 'Klijenti vide sliku pri zakazivanju.',
                child: _SlikaUSalonu(clan: clan, desktop: false),
              ),
              _Grupa(
                naslov: 'Sigurnost',
                child: _Sigurnost(clan: clan, desktop: false),
              ),
            ],
          );

    return AdminScaffold(
      title: 'Moj profil',
      header: AppHeader(
        title: 'Moj profil',
        tabRoot: false,
        textAction: HeaderTextAction(
          key: const Key('profil-sacuvaj-telefon'),
          label: _snimam ? 'Čuvanje…' : 'Sačuvaj',
          onTap: onSacuvaj,
        ),
      ),
      actions: desktop
          ? [
              SizedBox(
                height: AdminSize.touchTarget,
                child: OutlinedButton(
                  onPressed: _izmijenjeno && !_snimam ? _odustani : null,
                  child: const Text('Odustani'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: AdminSize.touchTarget,
                child: FilledButton(
                  key: const Key('profil-sacuvaj'),
                  onPressed: onSacuvaj,
                  style: FilledButton.styleFrom(
                    textStyle: AdminText.actionLabel,
                  ),
                  child: AdminVerzal(_snimam ? 'Čuvanje…' : 'Sačuvaj'),
                ),
              ),
            ]
          : null,
      body: sadrzaj,
    );
  }
}

// ---------------------------------------------------------------------------
// Slika
// ---------------------------------------------------------------------------

class _SlikaDesktop extends ConsumerWidget {
  const _SlikaDesktop({required this.clan});

  final StaffMember clan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final ima = clan.photoUrl != null;

    return Column(
      children: [
        const SizedBox(height: AdminSpacing.sm),
        ProfilAvatar(url: clan.photoUrl, ime: clan.name, velicina: 148),
        const SizedBox(height: AdminSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AdminSpacing.sm,
          children: [
            OutlinedButton(
              key: const Key('profil-promijeni-sliku'),
              onPressed: () => promijeniProfilnuSliku(context, ref),
              child: const Text('Promijeni sliku'),
            ),
            if (ima)
              TextButton(
                onPressed: () => ukloniProfilnuSliku(context, ref),
                style: TextButton.styleFrom(foregroundColor: boje.destructive),
                child: const Text('Ukloni'),
              ),
          ],
        ),
        const SizedBox(height: AdminSpacing.md),
        Text(
          // Bez imenice za radnika: „majstor" je riječ barbera, a admin je isti za sve
          // vertikale.
          'JPG ili PNG, najmanje $kProfilnaMinStrana×$kProfilnaMinStrana.\n'
          'Klijenti je vide pri zakazivanju.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: boje.textSecondary),
        ),
      ],
    );
  }
}

class _SlikaTelefon extends ConsumerWidget {
  const _SlikaTelefon({required this.clan});

  final StaffMember clan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _listSlike(context, ref, clan),
          child: ProfilAvatar(
            url: clan.photoUrl,
            ime: clan.name,
            velicina: 112,
          ),
        ),
        TextButton(
          onPressed: () => _listSlike(context, ref, clan),
          child: const Text('Promijeni sliku'),
        ),
      ],
    );
  }
}

/// `4e` — akcije nad slikom na telefonu. „Uslikaj" samo gdje kamera postoji.
Future<void> _listSlike(
  BuildContext context,
  WidgetRef ref,
  StaffMember clan,
) async {
  final salon = ref.read(adminSalonProvider).valueOrNull;
  final izbor = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      final boje = context.adminColors;
      Widget akcija(String vrijednost, String tekst, {bool opasno = false}) =>
          ListTile(
            minTileHeight: 58,
            title: Text(
              tekst,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: opasno ? boje.destructive : boje.accent,
                fontSize: 17,
              ),
            ),
            onTap: () => Navigator.of(context).pop(vrijednost),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ProfilAvatar(
                url: clan.photoUrl,
                ime: clan.name,
                velicina: 44,
              ),
              title: const Text('Profilna slika'),
              subtitle: salon == null || !clan.useProfilePhoto
                  ? null
                  : Text('Prikazuje se u: ${salon.name}'),
            ),
            const Divider(height: 1),
            if (imaKameru) akcija('kamera', 'Uslikaj'),
            akcija('galerija', 'Izaberi iz galerije'),
            if (clan.photoUrl != null)
              akcija('ukloni', 'Ukloni sliku', opasno: true),
            const Divider(height: 1),
            ListTile(
              minTileHeight: 58,
              title: const Text(
                'Odustani',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
  if (!context.mounted) return;
  switch (izbor) {
    case 'kamera':
      await promijeniProfilnuSliku(context, ref, izvor: ImageSource.camera);
    case 'galerija':
      await promijeniProfilnuSliku(context, ref);
    case 'ukloni':
      await ukloniProfilnuSliku(context, ref);
  }
}

// ---------------------------------------------------------------------------
// Lični podaci
// ---------------------------------------------------------------------------

/// Ime i prezime su **jedno** polje i na desktopu, ne dva kao u `4b`: baza čuva `name`, a
/// rastavljanje „Emir Bešić" na dva stupca bi pogađalo za svako ime sa tri riječi.
class _LicniPodaci extends StatelessWidget {
  const _LicniPodaci({
    required this.ime,
    required this.telefon,
    required this.email,
    required this.desktop,
  });

  final TextEditingController ime;
  final TextEditingController telefon;
  final String email;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final polja = [
      TextField(
        key: const Key('profil-ime'),
        controller: ime,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Ime i prezime'),
      ),
      TextField(
        key: const Key('profil-telefon'),
        controller: telefon,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Telefon'),
      ),
      // Promjena emaila traži potvrdu na novu adresu — van ovog taska (handoff).
      TextFormField(
        initialValue: email,
        enabled: false,
        decoration: const InputDecoration(labelText: 'Email za prijavu'),
      ),
    ];

    return Padding(
      padding: desktop
          ? EdgeInsets.zero
          : const EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (desktop) ...[
            Text('Lični podaci', style: tema.titleLarge),
            const SizedBox(height: AdminSpacing.lg),
          ],
          for (var i = 0; i < polja.length; i++) ...[
            if (i > 0) const SizedBox(height: AdminSpacing.md),
            polja[i],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slika u salonu
// ---------------------------------------------------------------------------

class _SlikaUSalonu extends ConsumerWidget {
  const _SlikaUSalonu({required this.clan, required this.desktop});

  final StaffMember clan;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final salon = ref.watch(adminSalonProvider).valueOrNull;
    final radnici = ref.watch(adminEmployeesProvider).valueOrNull ?? const [];
    final radnik = radnici.where((r) => r.id == clan.employeeId).firstOrNull;

    final uloga = [
      labelaUloge(clan.role) ?? '',
      if (radnik != null && radnik.role.trim().isNotEmpty) radnik.role.trim(),
      // `4d`: na telefonu stanje slike ide u podnaslov, desno ostaje samo prekidač.
      if (!desktop && clan.employeeId != null)
        clan.useProfilePhoto ? 'profilna slika' : 'slika salona',
    ].where((d) => d.isNotEmpty).join(' · ');

    final Widget desno;
    if (clan.employeeId == null) {
      desno = clan.isSalonAdmin
          ? _IzborRadnika(radnici: radnici)
          : Text('Nije povezano', style: tema.bodySmall);
    } else {
      desno = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (desktop && !clan.useProfilePhoto) ...[
            ProfilAvatar(
              url: radnik?.imageUrl,
              ime: radnik?.name ?? clan.name,
              velicina: 30,
            ),
            const SizedBox(width: AdminSpacing.sm),
          ],
          if (desktop) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clan.useProfilePhoto
                      ? 'Profilna slika'
                      : 'Slika koju je dodao salon',
                  style: tema.bodySmall?.copyWith(color: boje.textSecondary),
                ),
                if (!clan.useProfilePhoto && clan.photoUrl != null)
                  TextButton(
                    onPressed: () => _prekidac(context, ref, true),
                    // Meta 44 px (FE-502), a tekst ostaje poravnat sa redom iznad.
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, AdminSize.touchTarget),
                      alignment: Alignment.centerLeft,
                      foregroundColor: boje.accent,
                      textStyle: tema.bodySmall,
                    ),
                    child: const Text('Zamijeni mojom'),
                  ),
              ],
            ),
            const SizedBox(width: AdminSpacing.md),
          ],
          Semantics(
            label: 'Koristi profilnu sliku u salonu',
            child: Switch(
              key: const Key('profil-prekidac'),
              value: clan.useProfilePhoto,
              // Handoff: prekidač je u boji akcije (`#ee6c4d`), linkovi u `accent`.
              activeTrackColor: boje.action,
              // Bez profilne slike salon nema šta da preuzme; baza bi odbila (PT400).
              onChanged: clan.photoUrl == null && !clan.useProfilePhoto
                  ? null
                  : (v) => _prekidac(context, ref, v),
            ),
          ),
        ],
      );
    }

    final red = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminRadius.small),
            child: SizedBox.square(
              dimension: 38,
              child: salon?.logoUrl == null
                  ? ColoredBox(color: boje.neutralTint)
                  : Image.network(salon!.logoUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salon?.name ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: tema.titleSmall,
                ),
                if (uloga.isNotEmpty)
                  Text(
                    uloga,
                    overflow: TextOverflow.ellipsis,
                    style: tema.bodySmall?.copyWith(color: boje.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Flexible(child: desno),
        ],
      ),
    );

    if (!desktop) return red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.xl,
            AdminSpacing.xl,
            AdminSpacing.xl,
            AdminSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Slika u salonu', style: tema.titleLarge),
              const SizedBox(height: 2),
              Text(
                'Gdje klijenti vide ovu profilnu sliku.',
                style: tema.bodyMedium?.copyWith(color: boje.textSecondary),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: boje.separator),
        red,
      ],
    );
  }

  Future<void> _prekidac(BuildContext context, WidgetRef ref, bool v) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(staffRepositoryProvider).setUseProfilePhoto(v);
    } catch (e) {
      if (context.mounted) AdminToast.greska(context, porukaGreske(e));
      return;
    }
    osvjeziProfil(container);
  }
}

/// Vlasnik koji i sam radi bira svog radnika iz Osoblja — tek tada salon ima gdje da
/// pokaže njegovu profilnu sliku.
class _IzborRadnika extends ConsumerWidget {
  const _IzborRadnika({required this.radnici});

  final List<Employee> radnici;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktivni = radnici.where((r) => r.isActive).toList();
    if (aktivni.isEmpty) {
      return Text(
        'Dodajte se u Osoblje',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Povežite nalog sa radnikom',
      onSelected: (id) async {
        final container = ProviderScope.containerOf(context, listen: false);
        try {
          await container.read(staffRepositoryProvider).linkEmployee(id);
        } catch (e) {
          if (context.mounted) AdminToast.greska(context, porukaGreske(e));
          return;
        }
        osvjeziProfil(container);
      },
      itemBuilder: (context) => [
        for (final r in aktivni)
          PopupMenuItem<String>(value: r.id, child: Text(r.name)),
      ],
      child: Text(
        'Ja sam radnik…',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: context.adminColors.accent),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sigurnost
// ---------------------------------------------------------------------------

class _Sigurnost extends ConsumerWidget {
  const _Sigurnost({required this.clan, required this.desktop});

  final StaffMember clan;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;

    Widget red({
      required String naslov,
      required String opis,
      required Widget akcija,
    }) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.xl,
        vertical: AdminSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(naslov, style: tema.titleSmall),
                Text(
                  opis,
                  style: tema.bodySmall?.copyWith(color: boje.textSecondary),
                ),
              ],
            ),
          ),
          akcija,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (desktop) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.xl,
              AdminSpacing.xl,
              AdminSpacing.xl,
              AdminSpacing.md,
            ),
            child: Text('Sigurnost', style: tema.titleLarge),
          ),
          Divider(height: 1, color: boje.separator),
        ],
        red(
          naslov: 'Lozinka',
          opis: _opisLozinke(clan.passwordChangedAt),
          akcija: OutlinedButton(
            key: const Key('profil-lozinka'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _PromjenaLozinke(email: clan.email),
            ),
            child: Text(desktop ? 'Promijeni lozinku' : 'Promijeni'),
          ),
        ),
        Divider(height: 1, color: boje.separator),
        red(
          naslov: 'Prijavljeni uređaji',
          opis: 'Ovaj uređaj ostaje prijavljen.',
          akcija: TextButton(
            onPressed: () => _odjaviOstale(context, ref),
            style: TextButton.styleFrom(foregroundColor: boje.destructive),
            child: Text(desktop ? 'Odjavi sve uređaje' : 'Odjavi ostale'),
          ),
        ),
      ],
    );
  }

  Future<void> _odjaviOstale(BuildContext context, WidgetRef ref) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odjaviti sve druge uređaje?'),
        content: const Text(
          'Svi drugi telefoni i računari se odjavljuju i moraju ponovo unijeti '
          'lozinku. Ovaj uređaj ostaje prijavljen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odjavi'),
          ),
        ],
      ),
    );
    if (potvrda != true || !context.mounted) return;
    final staff = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(staffRepositoryProvider);
    try {
      await staff.signOutOtherDevices();
      if (context.mounted) {
        AdminToast.uspjeh(context, 'Drugi uređaji su odjavljeni.');
      }
    } catch (e) {
      if (context.mounted) AdminToast.greska(context, porukaGreske(e));
    }
  }
}

/// „Promijenjena prije 3 mjeseca". Kolona se puni tek od ovog taska, pa je za stare naloge
/// prazna — tada se ne izmišlja datum.
String _opisLozinke(DateTime? kad, {DateTime? sada}) {
  if (kad == null) return 'Nije mijenjana iz aplikacije.';
  final dana = (sada ?? DateTime.now()).difference(kad).inDays;
  if (dana < 1) return 'Promijenjena danas';
  if (dana < 2) return 'Promijenjena jučer';
  if (dana < 30) return 'Promijenjena prije $dana dana';
  final mjeseci = dana ~/ 30;
  if (mjeseci < 12) {
    return 'Promijenjena prije $mjeseci '
        '${mjeseci == 1
            ? 'mjesec'
            : mjeseci < 5
            ? 'mjeseca'
            : 'mjeseci'}';
  }
  return 'Promijenjena prije više od godinu dana';
}

class _PromjenaLozinke extends ConsumerStatefulWidget {
  const _PromjenaLozinke({required this.email});

  final String email;

  @override
  ConsumerState<_PromjenaLozinke> createState() => _PromjenaLozinkeState();
}

class _PromjenaLozinkeState extends ConsumerState<_PromjenaLozinke> {
  final _forma = GlobalKey<FormState>();
  final _trenutna = TextEditingController();
  final _nova = TextEditingController();
  final _ponovo = TextEditingController();
  bool _saljem = false;
  String? _greska;

  @override
  void dispose() {
    _trenutna.dispose();
    _nova.dispose();
    _ponovo.dispose();
    super.dispose();
  }

  Future<void> _potvrdi() async {
    if (!(_forma.currentState?.validate() ?? false)) return;
    setState(() {
      _saljem = true;
      _greska = null;
    });
    final container = ProviderScope.containerOf(context, listen: false);
    final staff = container.read(staffRepositoryProvider);
    // Dva koraka, dvije poruke: odbijena **trenutna** lozinka nije isto što i nova lozinka
    // koju server ne prihvata.
    try {
      await staff.verifyPassword(email: widget.email, password: _trenutna.text);
    } on ApiError catch (e) {
      _neuspjeh(
        e is AuthRejectedError
            ? 'Trenutna lozinka nije tačna.'
            : porukaGreske(e),
      );
      return;
    }
    try {
      await staff.changePassword(_nova.text);
    } on ApiError catch (e) {
      _neuspjeh(porukaGreske(e, opsta: 'Nova lozinka nije prihvaćena.'));
      return;
    }
    container.invalidate(currentStaffProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AdminToast.uspjeh(context, 'Lozinka je promijenjena.');
  }

  void _neuspjeh(String poruka) {
    if (!mounted) return;
    setState(() {
      _saljem = false;
      _greska = poruka;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dok promjena traje dijalog se ne zatvara: zatvoren usred poziva ostavio bi promijenjenu
    // lozinku bez ikakve potvrde.
    return PopScope(canPop: !_saljem, child: _dijalog(context));
  }

  Widget _dijalog(BuildContext context) {
    return AlertDialog(
      title: const Text('Promijeni lozinku'),
      content: Form(
        key: _forma,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _trenutna,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Trenutna lozinka',
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Unesite trenutnu lozinku' : null,
              ),
              const SizedBox(height: AdminSpacing.md),
              TextFormField(
                controller: _nova,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Nova lozinka'),
                // Isto pravilo kao registracija (task 57): 8+ znakova, slovo i cifra.
                validator: (v) => (v ?? '').length < 8
                    ? 'Najmanje 8 znakova'
                    : !RegExp(r'\p{L}', unicode: true).hasMatch(v!) ||
                          !RegExp(r'\d').hasMatch(v)
                    ? 'Treba bar jedno slovo i jednu cifru'
                    : v == _trenutna.text
                    ? 'Nova lozinka je ista kao trenutna'
                    : null,
              ),
              const SizedBox(height: AdminSpacing.md),
              TextFormField(
                controller: _ponovo,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ponovite novu lozinku',
                ),
                validator: (v) =>
                    v != _nova.text ? 'Lozinke se ne poklapaju' : null,
              ),
              if (_greska != null) ...[
                const SizedBox(height: AdminSpacing.md),
                Text(
                  _greska!,
                  style: TextStyle(color: context.adminColors.destructive),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saljem ? null : () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _saljem ? null : _potvrdi,
          child: Text(_saljem ? 'Mijenjam…' : 'Promijeni'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Okvir
// ---------------------------------------------------------------------------

class _Kartica extends StatelessWidget {
  const _Kartica({required this.child, this.bezPaddinga = false});

  final Widget child;
  final bool bezPaddinga;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: bezPaddinga
          ? EdgeInsets.zero
          : const EdgeInsets.all(AdminSpacing.xl),
      child: child,
    ),
  );
}

/// Grupa sa verzalnim naslovom iznad kartice, kao u „Još" (`4d`).
class _Grupa extends StatelessWidget {
  const _Grupa({required this.naslov, required this.child, this.napomena});

  final String naslov;
  final Widget child;
  final String? napomena;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Padding(
      padding: const EdgeInsets.only(top: AdminSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            naslov.toUpperCase(),
            semanticsLabel: naslov,
            style: AdminText.eyebrow.copyWith(color: boje.textSecondary),
          ),
          const SizedBox(height: AdminSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          if (napomena != null) ...[
            const SizedBox(height: AdminSpacing.sm),
            Text(
              napomena!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: boje.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
