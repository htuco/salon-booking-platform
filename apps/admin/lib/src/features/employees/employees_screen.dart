/// „Osoblje" — prikazi `3g` (desktop) i `3r` (telefon).
///
/// ## Isti ekran, dva rasporeda
///
/// Desktop crta red kartica radnika pa tabelu smjena ispod. Telefon (i desktop uži od
/// `AdminBreakpoint.compact`) tabelu spušta **u karticu**: svaki radnik nosi svoju traku od
/// sedam dana, jer tabela od osam kolona na 402 px nije tabela nego horizontalni skrol.
///
/// ## Šta je iz `3g`/`3r` placeholder
///
/// - **Broj termina u sedmici** („31 termin") — ekran nema sedmični upit termina, a novi
///   ne pravi. Piše se „— termina", ne izmišljena brojka. Sati su stvarni: zbir smjena.
/// - **„Kopiraj prošlu sedmicu"**, **„Uredi smjene"** i klik na polje smjene — raspored po
///   radniku se danas ne uređuje nigdje u adminu, pa dugmad kažu „uskoro" i vode na
///   „Radno vrijeme", gdje su salonski raspored i odsustva.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/poruka_greske.dart';
import '../../core/widgets/admin_refresh.dart';
import '../../core/format/terminologija.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_skeleton.dart';
import '../../core/widgets/slika_polje.dart';
import '../../core/widgets/admin_verzal.dart';
import '../appointments/appointments_providers.dart';
import '../calendar/calendar_providers.dart';
import '../working_hours/working_hours_providers.dart';
import 'employees_providers.dart';
import 'employees_sedmica.dart';

const _dani = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

/// Ponavljajuci raspored iz working_hours, bez izmisljene sedmicne evidencije.
String employeeShift(List<WorkingHour> hours, String employeeId, int day) {
  final shift = workingHoursFor(hours, dayOfWeek: day, employeeId: employeeId);
  if (shift == null || shift.isClosed) return 'Slobodno';
  return '${shift.startTime.format()}–${shift.endTime.format()}';
}

/// „Majstor" → „majstora", „Kozmetičarka" → „kozmetičarku" — za „+ Dodaj …".
///
/// Vertikala nosi samo nominativ; ovo pokriva imenice kakve `terms.staffSingular` daje
/// (muški rod na suglasnik, ženski na `-a`).
String _akuzativ(String jednina) {
  final r = jednina.toLowerCase();
  return r.endsWith('a') ? '${r.substring(0, r.length - 1)}u' : '${r}a';
}

void _uskoro(BuildContext context, String poruka) {
  final router = GoRouter.maybeOf(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(poruka),
        persist: false,
        action: router == null
            ? null
            : SnackBarAction(
                label: 'Radno vrijeme',
                onPressed: () => router.go(AdminRoute.workingHours.path),
              ),
      ),
    );
}

void _uskoroSmjene(BuildContext context) => _uskoro(
  context,
  'Uređivanje smjene po osobi stiže uskoro. Salonsko radno vrijeme i '
  'odsustva su u Radnom vremenu.',
);

class AdminEmployeesScreen extends ConsumerWidget {
  const AdminEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);

    Future<void> osvjezi() async {
      ref
        ..invalidate(adminEmployeeLinksProvider)
        ..invalidate(adminServicesProvider)
        ..invalidate(kalendarRadnoVrijemeProvider)
        ..invalidate(buduceBlokadeProvider)
        ..invalidate(adminEmployeesProvider);
      await ref.read(adminEmployeesProvider.future);
    }

    return AdminScaffold(
      title: 'Osoblje',
      aktivna: AdminRoute.employees,
      // `3r` crta veliki naslov i sedmicu u bijelom zaglavlju, bez `AppBar`-a.
      sopstvenoZaglavlje: true,
      actions: desktop ? const [_TopBarAkcije()] : null,
      body: desktop
          ? AdminRefresh(
              onRefresh: osvjezi,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AdminSpacing.gutterDesktop),
                children: const [
                  _NaslovDesktop(),
                  SizedBox(height: 22),
                  _Sadrzaj(),
                ],
              ),
            )
          : Column(
              children: [
                const _ZaglavljeTelefon(),
                Expanded(
                  child: AdminRefresh(
                    onRefresh: osvjezi,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AdminSpacing.gutterMobile,
                        14,
                        AdminSpacing.gutterMobile,
                        AdminSpacing.xl,
                      ),
                      children: const [_Sadrzaj()],
                    ),
                  ),
                ),
                const _AkcijeTelefon(),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zaglavlja i akcije
// ---------------------------------------------------------------------------

String _sedmicaDanas() => sedmicaTekst(ponedjeljakSedmice(DateTime.now()));

class _NaslovDesktop extends StatelessWidget {
  const _NaslovDesktop();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Osoblje', style: AdminText.display),
      const SizedBox(height: AdminSpacing.sm),
      Text(_sedmicaDanas(), style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

class _ZaglavljeTelefon extends StatelessWidget {
  const _ZaglavljeTelefon();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.gutterMobile,
          AdminSpacing.md,
          AdminSpacing.gutterMobile,
          AdminSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Osoblje', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(_sedmicaDanas(), style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    ),
  );
}

/// „Kopiraj prošlu sedmicu" i „+ DODAJ MAJSTORA" iz `3g`.
class _TopBarAkcije extends ConsumerWidget {
  const _TopBarAkcije();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Placeholder, i zato prvi otpada kad top bar postane uzak: raspored je
        // ponavljajući, pa „prošla sedmica" danas nema šta kopirati. Prag 1200 kao na
        // dashboardu: na 1024 px pored sidebara breadcrumb je prelijevao top bar.
        if (MediaQuery.sizeOf(context).width >= 1200) ...[
          SizedBox(
            height: AdminSize.touchTarget,
            child: OutlinedButton(
              onPressed: () => _uskoro(
                context,
                'Kopiranje sedmice stiže uskoro — raspored se danas ponavlja '
                'svake sedmice.',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Kopiraj prošlu sedmicu'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(
          height: AdminSize.touchTarget,
          child: FilledButton(
            onPressed: () => _uredi(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              textStyle: AdminText.actionLabel,
            ),
            child: AdminVerzal('+ Dodaj ${_akuzativ(radnikJednina(ref))}'),
          ),
        ),
      ],
    );
  }
}

/// „UREDI SMJENE" i „+ Majstor" iznad donje navigacije (`3r`).
class _AkcijeTelefon extends ConsumerWidget {
  const _AkcijeTelefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `3r`: natpisi su 18 px — veći od desktop dugmeta, jer je dugme 52 px visoko.
    final natpis = AdminText.actionLabel.copyWith(fontSize: 18);
    return Container(
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          top: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.gutterMobile,
        AdminSpacing.md,
        AdminSpacing.gutterMobile,
        AdminSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () => _uskoroSmjene(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                textStyle: natpis,
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: AdminVerzal('Uredi smjene'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _uredi(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                textStyle: natpis.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('+ ${radnikJednina(ref)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sadržaj
// ---------------------------------------------------------------------------

class _Sadrzaj extends ConsumerWidget {
  const _Sadrzaj();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(adminEmployeesProvider)
        .when(
          loading: () => const AdminSkeletonList(),
          error: (_, _) => Column(
            children: [
              const SizedBox(height: 80),
              const Center(child: Text('Osoblje se ne može učitati.')),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(adminEmployeesProvider),
                  child: const Text('Pokušaj ponovo'),
                ),
              ),
            ],
          ),
          data: (radnici) {
            if (radnici.isEmpty) return const _Prazno();
            return LayoutBuilder(
              builder: (context, constraints) {
                final sirina = constraints.maxWidth;
                // Pojas iz dostupne širine, ne iz prozora: pored sidebara je uže.
                if (AdminShell.bandZa(sirina).jeCompact) {
                  return Column(
                    children: [
                      for (final (i, r) in radnici.indexed) ...[
                        if (i > 0) const SizedBox(height: AdminSpacing.md),
                        _KarticaRadnika(radnik: r, saTrakom: true),
                      ],
                    ],
                  );
                }
                final skala = MediaQuery.textScalerOf(context).scale(14) / 14;
                final kolone = (sirina / (340 * skala)).floor().clamp(
                  2,
                  AdminShell.bandZa(sirina).kolone.clamp(3, 4),
                );
                final sirinaKartice =
                    (sirina - AdminSpacing.lg * (kolone - 1)) / kolone;
                final aktivni = radnici.where((r) => r.isActive).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AdminSpacing.lg,
                      runSpacing: AdminSpacing.lg,
                      children: [
                        for (final r in radnici)
                          SizedBox(
                            width: sirinaKartice,
                            child: _KarticaRadnika(radnik: r, saTrakom: false),
                          ),
                      ],
                    ),
                    if (aktivni.isNotEmpty) ...[
                      const SizedBox(height: AdminSpacing.gutterDesktop),
                      Text(
                        'Smjene',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _TabelaSmjena(radnici: aktivni),
                      const SizedBox(height: AdminSpacing.lg),
                      Text(
                        'Praznine znače da ${radnikJednina(ref).toLowerCase()} '
                        'ne radi i termini se ne nude u aplikaciji · odsustva se '
                        'unose u Radnom vremenu.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
  }
}

class _Prazno extends ConsumerWidget {
  const _Prazno();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text('Osoblje je još prazno.'),
          TextButton(
            onPressed: () => _uredi(context),
            child: Text('Dodaj ${_akuzativ(radnikJednina(ref))}'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Kartica radnika
// ---------------------------------------------------------------------------

/// Kartica iz `3g`; sa [saTrakom] i sedmična traka ispod, kako je crta `3r`.
class _KarticaRadnika extends ConsumerWidget {
  const _KarticaRadnika({required this.radnik, required this.saTrakom});

  final Employee radnik;
  final bool saTrakom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final sati = ref.watch(kalendarRadnoVrijemeProvider).valueOrNull;
    // Blokade su dodatak: bez njih se smjena i dalje prikazuje, samo bez odsustva.
    final blokade =
        ref.watch(buduceBlokadeProvider).valueOrNull ?? const <BlockedSlot>[];
    // `DateTime.now()` u buildu, ne sat koji kuca: pilula se osvježi sa ekranom i na
    // povlačenje, a periodični tajmer bi radio dok god je lista otvorena.
    final stanje = sati == null
        ? null
        : stanjeDanas(
            radnik: radnik,
            sati: sati,
            blokade: blokade,
            sada: DateTime.now(),
          );

    final opis = [
      if (radnik.role.trim().isNotEmpty) radnik.role.trim(),
      _uslugeTekst(ref),
    ].join(' · ');
    final brojke =
        '— termina · ${sati == null ? '— h' : satiTekst(minuteSedmice(sati, radnik.id))}';

    final sporedni = (saTrakom ? tema.bodyLarge : tema.bodyMedium)?.copyWith(
      color: boje.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final vrh = Padding(
      padding: saTrakom
          ? const EdgeInsets.fromLTRB(16, 20, 16, 20)
          : const EdgeInsets.all(20),
      child: Row(
        children: [
          _Avatar(radnik: radnik, precnik: saTrakom ? 52 : 64),
          SizedBox(width: saTrakom ? 14 : AdminSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        radnik.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: saTrakom ? tema.headlineSmall : tema.titleLarge,
                      ),
                    ),
                    if (stanje != null) ...[
                      const SizedBox(width: AdminSpacing.sm),
                      Flexible(
                        child: _PilulaStanja(stanje: stanje, kratko: saTrakom),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  opis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sporedni,
                ),
                const SizedBox(height: 6),
                Text(
                  brojke,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sporedni,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Uredi ${radnik.name}',
            child: InkWell(onTap: () => _uredi(context, radnik), child: vrh),
          ),
          if (saTrakom && radnik.isActive)
            _TrakaSedmice(radnik: radnik, sati: sati, blokade: blokade),
        ],
      ),
    );
  }

  /// `sve usluge`, ili nazivi dodijeljenih usluga.
  String _uslugeTekst(WidgetRef ref) {
    final veze = ref.watch(adminEmployeeLinksProvider);
    final usluge = ref.watch(adminServicesProvider);
    if (veze.hasError || usluge.hasError) return 'usluge nisu učitane';
    if (!veze.hasValue || !usluge.hasValue) return 'učitavanje usluga…';
    final ids = {
      for (final v in veze.value!)
        if (v.employeeId == radnik.id) v.serviceId,
    };
    final dodijeljene = usluge.value!.where((s) => ids.contains(s.id)).toList();
    if (dodijeljene.isEmpty) return 'bez dodijeljenih usluga';
    final aktivne = usluge.value!.where((s) => s.isActive).toList();
    if (aktivne.length > 1 && aktivne.every((s) => ids.contains(s.id))) {
      return 'sve usluge';
    }
    return dodijeljene
        .map((s) => '${s.name}${s.isActive ? '' : ' (neaktivna)'}')
        .join(', ');
  }
}

/// „u smjeni", „počinje 12:00" — boja kaže stanje, tekst ga imenuje.
class _PilulaStanja extends StatelessWidget {
  const _PilulaStanja({required this.stanje, required this.kratko});

  final StanjeDanas stanje;

  /// Telefon: „od 12:00" umjesto „počinje 12:00" — pilula dijeli red sa imenom.
  final bool kratko;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final (tekst, pozadina, tinta) = switch (stanje) {
      USmjeni() => ('u smjeni', boje.positiveTint, boje.positiveInk),
      Pocinje(:final od) => (
        '${kratko ? 'od' : 'počinje'} ${od.format()}',
        boje.waitingTint,
        boje.waitingInk,
      ),
      NaPauzi() => ('na pauzi', boje.neutralTint, boje.textSecondary),
      SmjenaGotova() => ('smjena gotova', boje.neutralTint, boje.textSecondary),
      NeRadiDanas() => ('ne radi danas', boje.neutralTint, boje.textSecondary),
      OdsutanSada() => ('odsutan', boje.neutralTint, boje.textSecondary),
      Neaktivan() => ('neaktivan', boje.neutralTint, boje.textSecondary),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kratko ? 14 : 10,
        vertical: kratko ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: pozadina,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(
        tekst,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdminText.statusLabel.copyWith(
          color: tinta,
          fontSize: kratko ? 16 : null,
        ),
      ),
    );
  }
}

/// Fotografija, a bez nje sivi preliv kakav `3g` crta — ne slomljena slika.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.radnik, required this.precnik});

  final Employee radnik;
  final double precnik;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final zamjena = Container(
      width: precnik,
      height: precnik,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.6),
          radius: 1.1,
          colors: [boje.sidebarMuted, boje.sidebarRaised],
        ),
      ),
    );
    final url = radnik.imageUrl;
    return Semantics(
      image: true,
      label: 'Fotografija: ${radnik.name}',
      child: url == null || url.isEmpty
          ? zamjena
          : ClipOval(
              child: Image.network(
                url,
                width: precnik,
                height: precnik,
                fit: BoxFit.cover,
                loadingBuilder: (_, slika, napredak) =>
                    napredak == null ? slika : zamjena,
                errorBuilder: (_, _, _) => zamjena,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smjene
// ---------------------------------------------------------------------------

/// Sedam ćelija ispod kartice na telefonu (`3r`).
class _TrakaSedmice extends StatelessWidget {
  const _TrakaSedmice({
    required this.radnik,
    required this.sati,
    required this.blokade,
  });

  final Employee radnik;
  final List<WorkingHour>? sati;
  final List<BlockedSlot> blokade;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final linija = BorderSide(color: boje.separator, width: AdminSize.hairline);
    final dani = daniSedmice(ponedjeljakSedmice(DateTime.now()));
    return Container(
      decoration: BoxDecoration(border: Border(top: linija)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, dan) in dani.indexed)
              Expanded(
                child: InkWell(
                  onTap: () => _uskoroSmjene(context),
                  child: Container(
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(left: linija),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 11,
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _dani[i].toUpperCase(),
                            semanticsLabel: _dani[i],
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: boje.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _vrijednost(dan),
                            semanticsLabel: _procitano(dan),
                            style: AdminText.timeLarge.copyWith(
                              color: boje.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _vrijednost(DateTime dan) {
    final s = sati;
    if (s == null) return '…';
    return switch (danRadnika(
      sati: s,
      blokade: blokade,
      employeeId: radnik.id,
      dan: dan,
    )) {
      final RadiDan d => d.kratko,
      SlobodanDan() => '—',
      OdsutanDan(:final razlog) => skracenicaOdsustva(razlog),
    };
  }

  /// Isto što i [_vrijednost], ali za čitač ekrana: skraćenica `GO` se sriče, pa
  /// čitač dobija puni razlog (FE-502). `null` ostavlja vidljivi tekst.
  String? _procitano(DateTime dan) {
    final s = sati;
    if (s == null) return null;
    return switch (danRadnika(
      sati: s,
      blokade: blokade,
      employeeId: radnik.id,
      dan: dan,
    )) {
      OdsutanDan(:final razlog) => razlog ?? 'Odsutan',
      SlobodanDan() => 'Ne radi',
      RadiDan() => null,
    };
  }
}

/// Tabela smjena iz `3g`: radnik po redu, dan po koloni.
class _TabelaSmjena extends ConsumerWidget {
  const _TabelaSmjena({required this.radnici});

  final List<Employee> radnici;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(kalendarRadnoVrijemeProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AdminSpacing.xxl),
            child: AdminSkeletonList(),
          ),
          error: (_, _) => Column(
            children: [
              const Text('Raspored se ne može učitati.'),
              TextButton(
                onPressed: () => ref.invalidate(kalendarRadnoVrijemeProvider),
                child: const Text('Ponovi učitavanje rasporeda'),
              ),
            ],
          ),
          data: (sati) => _tabela(context, ref, sati),
        );
  }

  Widget _tabela(BuildContext context, WidgetRef ref, List<WorkingHour> sati) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final blokade =
        ref.watch(buduceBlokadeProvider).valueOrNull ?? const <BlockedSlot>[];
    final dani = daniSedmice(ponedjeljakSedmice(DateTime.now()));
    // Naziv kolone iz vertikale, ne iz canvasa: `3g` je barber i piše „Majstor".
    final radnik = radnikJednina(ref);

    Widget danZaglavlje(int i, DateTime dan) {
      // Dan u kojem niko ne radi je siv, kao nedjelja u `3g`.
      final iko = radnici.any(
        (r) =>
            danRadnika(sati: sati, blokade: blokade, employeeId: r.id, dan: dan)
                is! SlobodanDan,
      );
      final labela = '${_dani[i]} ${dan.day}.';
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
        child: Text(
          labela.toUpperCase(),
          semanticsLabel: labela,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: tema.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: iko ? boje.ink : boje.textMuted,
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        // `3g`: kolona imena je ~1,1 dnevne kolone.
        columnWidths: const {0: FlexColumnWidth(1.12)},
        border: TableBorder(
          horizontalInside: BorderSide(
            color: boje.separator,
            width: AdminSize.hairline,
          ),
        ),
        children: [
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Text(
                  radnik.toUpperCase(),
                  semanticsLabel: radnik,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AdminText.eyebrow.copyWith(color: boje.textSecondary),
                ),
              ),
              for (final (i, dan) in dani.indexed) danZaglavlje(i, dan),
            ],
          ),
          for (final r in radnici)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.titleSmall,
                  ),
                ),
                for (final dan in dani)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                    child: _CelijaSmjene(
                      dan: danRadnika(
                        sati: sati,
                        blokade: blokade,
                        employeeId: r.id,
                        dan: dan,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Polje smjene: plavo sa vremenom, koralno za odsustvo, crtica za slobodan dan.
class _CelijaSmjene extends StatelessWidget {
  const _CelijaSmjene({required this.dan});

  final DanRadnika dan;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final (tekst, pozadina, tinta) = switch (dan) {
      final RadiDan d => (d.kratko, boje.accentTint, boje.accent),
      OdsutanDan(:final razlog) => (
        razlog ?? 'Odsutan',
        boje.action,
        boje.onAction,
      ),
      SlobodanDan() => ('', null, null),
    };
    if (pozadina == null) {
      return SizedBox(
        height: AdminSize.touchTarget,
        child: Center(
          child: Text(
            '—',
            semanticsLabel: 'Ne radi',
            style: AdminText.time.copyWith(color: boje.textMuted),
          ),
        ),
      );
    }
    return Material(
      color: pozadina,
      borderRadius: BorderRadius.circular(AdminRadius.small),
      child: InkWell(
        onTap: () => _uskoroSmjene(context),
        borderRadius: BorderRadius.circular(AdminRadius.small),
        child: ConstrainedBox(
          // `3g` crta 34; ćelija se tapa, pa je 44 po FE-502.
          constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tekst,
                  style: AdminText.time.copyWith(
                    color: tinta,
                    fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// Uređivanje radnika — kreiranje, izmjena, usluge, (de)aktivacija
// ---------------------------------------------------------------------------

Future<void> _uredi(BuildContext context, [Employee? employee]) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmployeeEditor(employee: employee),
    );

class _EmployeeEditor extends ConsumerStatefulWidget {
  const _EmployeeEditor({this.employee});
  final Employee? employee;
  @override
  ConsumerState<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends ConsumerState<_EmployeeEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.employee?.name);
  late final _role = TextEditingController(text: widget.employee?.role);
  late final _bio = TextEditingController(text: widget.employee?.bio);
  late final _years = TextEditingController(
    text: widget.employee?.experienceYears?.toString(),
  );
  late String? _slika = widget.employee?.imageUrl;
  bool _slikaSeSalje = false;
  Set<String>? _selected;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _role, _bio, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_slikaSeSalje) {
      setState(() => _error = 'Slika se još šalje. Sačekajte trenutak.');
      return;
    }
    if (_saving || _selected == null || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeActionsProvider)
          .save(
            widget.employee,
            EmployeeInput(
              name: _name.text.trim(),
              role: _role.text.trim(),
              bio: _bio.text.trim(),
              experienceYears: int.tryParse(_years.text.trim()),
              imageUrl: _slika,
              serviceIds: _selected!.toList(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = porukaGreske(e, opsta: 'Promjena se ne može sačuvati.');
        });
      }
    }
  }

  Future<void> _toggle() async {
    final employee = widget.employee!;
    final jednina = radnikJednina(ref);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          employee.isActive
              ? 'Deaktivirati ${_akuzativ(jednina)}?'
              : 'Aktivirati ${_akuzativ(jednina)}?',
        ),
        content: Text(
          employee.isActive
              ? '$jednina se više ne nudi za nove rezervacije. Postojeći termini ostaju zakazani; pregledajte ih u kalendaru.'
              : '$jednina se ponovo nudi za rezervacije prema rasporedu i dodijeljenim uslugama.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(textStyle: AdminText.actionLabel),
            child: const AdminVerzal('Potvrdi'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeActionsProvider)
          .setActive(employee, !employee.isActive);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = porukaGreske(e, opsta: 'Status se ne može promijeniti.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(adminServicesProvider);
    final links = ref.watch(adminEmployeeLinksProvider);
    if (_selected == null &&
        (widget.employee == null ||
            (links.hasValue && !links.isLoading && !links.hasError))) {
      _selected = {
        for (final l in links.valueOrNull ?? <EmployeeService>[])
          if (l.employeeId == widget.employee?.id) l.serviceId,
      };
    }
    final ready =
        !services.isLoading &&
        (widget.employee == null || !links.isLoading) &&
        services.hasValue &&
        _selected != null &&
        !services.hasError &&
        (widget.employee == null || !links.hasError);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminSpacing.xxl),
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.employee == null
                        ? 'Dodaj ${_akuzativ(radnikJednina(ref))}'
                        : 'Uredi ${_akuzativ(radnikJednina(ref))}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AdminSpacing.xl),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ime'),
                    maxLength: 120,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ime je obavezno.'
                        : null,
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  TextFormField(
                    controller: _role,
                    decoration: const InputDecoration(labelText: 'Titula'),
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  TextFormField(
                    controller: _bio,
                    decoration: const InputDecoration(labelText: 'Biografija'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  TextFormField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Godine staža (opcionalno)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      return n == null || n < 0 || n > 80
                          ? 'Unesite od 0 do 80 godina.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  Text(
                    'Fotografija (opcionalno)',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AdminSpacing.xs),
                  SlikaPolje(
                    url: _slika,
                    kind: MediaKind.radnici,
                    krug: true,
                    onChanged: (url) => setState(() => _slika = url),
                    onSaljeChanged: (v) => _slikaSeSalje = v,
                  ),
                  const SizedBox(height: AdminSpacing.xl),
                  Text(
                    'Usluge koje ${radnikJednina(ref).toLowerCase()} pruža',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!ready) ...[
                    if (services.hasError || links.hasError)
                      TextButton(
                        onPressed: () {
                          ref.invalidate(adminServicesProvider);
                          ref.invalidate(adminEmployeeLinksProvider);
                        },
                        child: const Text(
                          'Usluge nisu učitane. Pokušaj ponovo.',
                        ),
                      )
                    else
                      const AdminSkeletonList(redova: 3),
                  ] else ...[
                    if (services.value!.isEmpty)
                      const Text(
                        'Cjenovnik je prazan. Usluge možete dodijeliti kasnije.',
                      ),
                    for (final s in services.value!)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${s.name}${s.isActive ? '' : ' (neaktivna)'}',
                        ),
                        value: _selected!.contains(s.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected!.add(s.id);
                          } else {
                            _selected!.remove(s.id);
                          }
                        }),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AdminSpacing.md,
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AdminSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: ready && !_saving ? _save : null,
                      style: FilledButton.styleFrom(
                        textStyle: AdminText.actionLabel,
                      ),
                      child: AdminVerzal(_saving ? 'Čuvanje…' : 'Sačuvaj'),
                    ),
                  ),
                  if (widget.employee != null)
                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : _toggle,
                        child: Text(
                          widget.employee!.isActive
                              ? 'Deaktiviraj ${_akuzativ(radnikJednina(ref))}'
                              : 'Ponovo aktiviraj ${_akuzativ(radnikJednina(ref))}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
