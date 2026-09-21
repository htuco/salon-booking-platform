/// Termini i zahtjevi — prikazi `3d` (desktop) i `3m` (telefon).
///
/// **Jedna ruta, dva lica.** `/appointments` je puna lista dana;
/// `/appointments?status=pending` je ekran zahtjeva, koji handoff crta kao zaseban prikaz.
/// Zasebna ruta za zahtjeve bi punu listu ostavila bez ijednog ulaza iz navigacije (task
/// 29), pa je razlika u filteru, a ne u adresi stabla.
///
/// Zahtjevi se **ne drže jednog dana**: klijent traži termin i za sutra i za dvije sedmice,
/// pa filter dana u tom licu ekrana ne stoji. Puna lista bez filtera statusa je i dalje
/// dnevna, jer se raspored gleda po danu.
///
/// ## Šta canvas traži, a ovdje nije nacrtano
///
/// - **„Preklapa se s pauzom Amara 15:00–15:30"** — pauze i blokade dolaze u tasku 34.
///   Upozorenje koje se ne računa iz podataka bilo bi ukras koji tvrdi da je provjera.
/// - **„12 dolazaka · bez nedolazaka"** i **„Tri nedolaska u 6 mjeseci"** — istorija
///   klijenta je modul iz taska 35.
/// - **„Ponudi drugo vrijeme" / „Ponudi 15:30"** — pomjeranje termina nema RPC putanju;
///   `set_appointment_status` mijenja status, ne vrijeme. Dok je nema, salon otkaže i
///   upiše novi termin, što oba koraka već rade.
/// - **„prosjek odgovora 8 min"** — `appointments` nema `created_at`.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'appointment_actions_bar.dart';
import 'appointment_card.dart';
import 'appointments_providers.dart';
import 'status_pill.dart';

/// Najveća širina kolone sa karticama na desktopu.
///
/// Radna površina raste sa prozorom, ali kartica termina ne treba biti šira od svog
/// sadržaja: na 2560 px bi ime klijenta i tri dugmeta stajali na suprotnim krajevima stola.
/// `3d` je crtan na radnoj površini od 1176 px, pa je to i granica.
const double _maxSirinaListe = 1176;

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({this.trazeniStatus, super.key});

  /// Status iz `?status=` u adresi, ili `null` za „svi".
  ///
  /// Dolazi iz **route buildera**, ne iz `GoRouterState` u ovom ekranu — v. komentar uz
  /// rutu. Zahvaljujući tome ekran se i dalje diže u testu bez routera.
  final AppointmentStatus? trazeniStatus;

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    // Filter je app-scoped `Notifier`, a adresa je ono što korisnik vidi — kad se ekran
    // otvori sa `?status=`, adresa je jača. Upis ide poslije prvog frame-a jer se provider
    // ne smije mijenjati usred gradnje widgeta.
    final trazeni = widget.trazeniStatus;
    if (trazeni != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(appointmentsFilterProvider.notifier)
            .postaviStatusTacno(trazeni);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(appointmentsFilterProvider);
    final jeDesktop = AdminShell.jeDesktop(context);
    final zahtjevi = filter.status == AppointmentStatus.pending;

    // Zahtjevi gledaju naprijed kroz dane, puna lista gleda jedan dan.
    final lista = zahtjevi
        ? ref.watch(zahtjeviProvider)
        : ref.watch(filtriraniTerminiProvider);

    return AdminScaffold(
      // Naslov prati filter, jer ista ruta nosi dvije ćelije navigacije: „Zahtjevi" vode
      // ovdje sa `?status=pending`. Ekran naslovljen „Termini" poslije tapa na „Zahtjeve"
      // izgleda kao da je ćelija promašila.
      title: zahtjevi ? 'Zahtjevi' : 'Termini',
      aktivna: AdminRoute.appointments,
      sopstvenoZaglavlje: true,
      actions: jeDesktop
          ? [zahtjevi ? const _PotvrdiSveDugme() : const _NoviTerminDugme()]
          : null,
      // Ručni unos je jedini ulaz u `/appointments/new` — bez njega ekran postoji ali se do
      // njega ne može doći iz aplikacije, što je rupa koju je task 17 već jednom našao sa
      // `/account`. Na desktopu isto dugme stoji u top baru, pa se FAB ne crta dvaput.
      floatingActionButton: jeDesktop || zahtjevi
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AdminRoute.appointmentNew.path),
              icon: const Icon(Icons.add),
              label: const Text('Novi termin'),
            ),
      body: Column(
        children: [
          _Zaglavlje(filter: filter, zahtjevi: zahtjevi, lista: lista),
          Expanded(
            child: lista.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // Greška nosi dugme, ne samo tekst: admin koji izgubi vezu usred smjene mora
              // moći ponoviti bez zatvaranja app-e.
              error: (greska, _) => _Greska(
                poruka: greska is ApiError
                    ? 'Termini se ne mogu učitati.'
                    : 'Došlo je do greške.',
                onPonovi: () => ref.invalidate(
                  zahtjevi ? zahtjeviProvider : filtriraniTerminiProvider,
                ),
              ),
              data: (termini) => termini.isEmpty
                  ? _PrazanDan(filter: filter, zahtjevi: zahtjevi)
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(
                        zahtjevi ? zahtjeviProvider : filtriraniTerminiProvider,
                      ),
                      child: _Lista(termini: termini, zahtjevi: zahtjevi),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Naslov, podnaslov, izbor dana i čipovi statusa.
class _Zaglavlje extends ConsumerWidget {
  const _Zaglavlje({
    required this.filter,
    required this.zahtjevi,
    required this.lista,
  });

  final AppointmentsFilter filter;
  final bool zahtjevi;
  final AsyncValue<List<Appointment>> lista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jeDesktop = AdminShell.jeDesktop(context);
    final broj = lista.valueOrNull?.length ?? 0;

    final naslov = zahtjevi
        ? (broj == 0 ? 'Nema zahtjeva' : '$broj ${_cekajuTekst(broj)}')
        : naslovDana(filter.dan);

    final podnaslov = zahtjevi
        ? 'Klijent vidi „na čekanju" dok ne odgovorite.'
        : datumSaGodinom(filter.dan);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AdminShell.gutterOf(context),
        jeDesktop ? AdminSpacing.gutterDesktop : AdminSpacing.md,
        AdminShell.gutterOf(context),
        AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Na telefonu je zaglavlje bijela traka iznad sive radne površine (`3m`); na
        // desktopu stoji **na** radnoj površini, jer je iznad njega već top bar.
        color: jeDesktop ? null : context.adminColors.surface,
        border: jeDesktop
            ? null
            : Border(
                bottom: BorderSide(
                  color: context.adminColors.separator,
                  width: AdminSize.hairline,
                ),
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        naslov,
                        style: jeDesktop
                            ? AdminText.display
                            : theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        podnaslov,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.adminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!jeDesktop) const AdminNalogDugme(ikona: true),
              ],
            ),
            if (!zahtjevi) ...[
              const SizedBox(height: AdminSpacing.md),
              _IzborDana(filter: filter),
            ],
            const SizedBox(height: AdminSpacing.lg),
            _Cipovi(filter: filter),
          ],
        ),
      ),
    );
  }
}

/// Dan naprijed/nazad i kalendar. Stoji samo u punoj listi — zahtjevi nisu dnevni.
class _IzborDana extends ConsumerWidget {
  const _IzborDana({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsFilterProvider.notifier);

    // `Flexible` oko datuma, uz `mainAxisSize.min`: bez njega dvije strelice plus
    // „19. septembar 2026." na 402 px izlaze 48 px van ekrana, a sa `Expanded` se dugme na
    // 1440 razvuče preko cijele radne površine. Prvo je našao test, drugo snimak.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => notifier.pomjeriDan(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Prethodni dan',
        ),
        Flexible(
          child: OutlinedButton(
            onPressed: () async {
              final izabran = await showDatePicker(
                context: context,
                initialDate: filter.dan,
                // Prošli termini se gledaju (ko se nije pojavio, šta je odrađeno), pa raspon
                // ide i unazad — ne samo naprijed.
                firstDate: DateTime(2024),
                lastDate: DateTime(2030, 12, 31),
              );
              if (izabran != null) notifier.postaviDan(izabran);
            },
            child: Text(
              datumSaGodinom(filter.dan),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          onPressed: () => notifier.pomjeriDan(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Sljedeći dan',
        ),
      ],
    );
  }
}

/// Čipovi statusa iz `3d`: izabrani je pun akcent, ostali su obrub.
class _Cipovi extends ConsumerWidget {
  const _Cipovi({required this.filter});

  final AppointmentsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentsFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Cip(
            labela: 'Svi',
            izabran: filter.status == null,
            onTap: () => notifier.postaviStatus(null),
          ),
          // `unknown` se ne nudi kao filter: to je status koji ova verzija app-e ne
          // poznaje, a ne nešto što vlasnik bira.
          for (final status in AppointmentStatus.values)
            if (status != AppointmentStatus.unknown)
              _Cip(
                labela: statusLabela(status),
                izabran: filter.status == status,
                onTap: () => notifier.postaviStatus(status),
              ),
        ],
      ),
    );
  }
}

class _Cip extends StatelessWidget {
  const _Cip({
    required this.labela,
    required this.izabran,
    required this.onTap,
  });

  final String labela;
  final bool izabran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Material(
        color: izabran
            ? context.adminColors.accent
            : context.adminColors.surface,
        // Obrub ide kroz `shape`, pa `borderRadius` uz njega **nije dozvoljen** —
        // `Material` to provjerava assertom i ruši ekran, ne samo čip.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.base),
          side: BorderSide(
            color: izabran
                ? context.adminColors.accent
                : context.adminColors.border,
            width: AdminSize.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminRadius.base),
          child: Container(
            height: AdminSize.buttonHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              labela,
              style: theme.textTheme.labelLarge?.copyWith(
                color: izabran
                    ? context.adminColors.onAccent
                    : context.adminColors.ink,
                fontWeight: izabran ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista kartica, centrirana i ograničena po širini na desktopu.
class _Lista extends ConsumerWidget {
  const _Lista({required this.termini, required this.zahtjevi});

  final List<Appointment> termini;
  final bool zahtjevi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeDesktop = AdminShell.jeDesktop(context);
    final usluge = ref.watch(uslugePoIdProvider);
    final radnici = ref.watch(radniciPoIdProvider);
    final gutter = AdminShell.gutterOf(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxSirinaListe),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(gutter, AdminSpacing.lg, gutter, 40),
          itemCount: termini.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: zahtjevi ? AdminSpacing.lg : AdminSpacing.md),
          itemBuilder: (context, i) {
            final termin = termini[i];
            final opis = opisTermina(termin, usluge: usluge, radnici: radnici);

            if (zahtjevi && jeDesktop) {
              return _ZahtjevKartica(termin: termin, opis: opis);
            }

            return AppointmentCard(
              termin: termin,
              opis: opis,
              // Zahtjev se može odnositi na bilo koji dan, pa vrijeme bez datuma ne kaže
              // dovoljno; u dnevnoj listi je datum u zaglavlju i ponavljao bi se u svakom
              // redu.
              datum: zahtjevi
                  ? naslovDanaZaDatum(termin.date).toLowerCase()
                  : null,
              onTap: () => context.go('/appointments/${termin.id}'),
              podnozje: AppointmentActionsBar(termin: termin),
            );
          },
        ),
      ),
    );
  }
}

/// Kartica zahtjeva iz `3d`: vrijeme lijevo, podaci u sredini, radnje desno.
class _ZahtjevKartica extends ConsumerStatefulWidget {
  const _ZahtjevKartica({required this.termin, required this.opis});

  final Appointment termin;
  final TerminOpis opis;

  @override
  ConsumerState<_ZahtjevKartica> createState() => _ZahtjevKarticaState();
}

class _ZahtjevKarticaState extends ConsumerState<_ZahtjevKartica> {
  bool _uToku = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final termin = widget.termin;

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vrijeme je najkrupnije na cijeloj kartici: zahtjev se prvo mjeri time kada
            // je, pa tek onda ko ga je poslao.
            Container(
              width: 160,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: context.adminColors.separator,
                    width: AdminSize.hairline,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vrijemeHhMm(termin.startTime),
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    naslovDanaZaDatum(termin.date).toLowerCase(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.adminColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${termin.durationMinutes} minuta',
                    style: AdminText.dataInline.copyWith(
                      color: context.adminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          termin.customerName,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(width: AdminSpacing.md),
                        AppointmentStatusPill(status: termin.status),
                      ],
                    ),
                    if (termin.customerPhone case final telefon?
                        when telefon.isNotEmpty) ...[
                      const SizedBox(height: AdminSpacing.xs),
                      Text(
                        telefon,
                        style: AdminText.dataInline.copyWith(
                          color: context.adminColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AdminSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Podatak(
                          labela: 'Usluga',
                          vrijednost: widget.opis.usluga ?? '—',
                        ),
                        const SizedBox(width: 30),
                        _Podatak(
                          labela: 'Majstor',
                          vrijednost: widget.opis.majstor ?? 'bilo ko',
                        ),
                        if (widget.opis.cijena case final cijena?) ...[
                          const SizedBox(width: 30),
                          _Podatak(
                            labela: 'Cijena',
                            vrijednost: iznosKm(cijena),
                          ),
                        ],
                      ],
                    ),
                    if (termin.customerNote case final napomena?
                        when napomena.isNotEmpty) ...[
                      const SizedBox(height: AdminSpacing.lg),
                      Container(
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                        decoration: BoxDecoration(
                          color: context.adminColors.neutralTint,
                          borderRadius: BorderRadius.circular(AdminRadius.base),
                        ),
                        child: Text(
                          napomena,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.adminColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 280,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.adminColors.separator,
                    width: AdminSize.hairline,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: _uToku ? null : _potvrdi,
                      child: const Text('Potvrdi'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _uToku ? null : _odbij,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.adminColors.destructive,
                      ),
                      child: const Text('Odbij zahtjev'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _potvrdi() => _izvrsi(
    () => ref.read(appointmentActionsProvider).potvrdi(widget.termin.id),
    uspjeh: 'Termin je potvrđen.',
  );

  Future<void> _odbij() => _izvrsi(
    () => ref.read(appointmentActionsProvider).odbij(widget.termin.id),
    uspjeh: 'Zahtjev je odbijen.',
  );

  Future<void> _izvrsi(
    Future<Appointment?> Function() poziv, {
    required String uspjeh,
  }) async {
    setState(() => _uToku = true);
    try {
      await poziv();
      if (!mounted) return;
      _poruka(context, uspjeh);
    } on ApiError catch (_) {
      if (!mounted) return;
      _poruka(context, 'Akcija nije uspjela. Pokušajte ponovo.');
    } finally {
      if (mounted) setState(() => _uToku = false);
    }
  }
}

class _Podatak extends StatelessWidget {
  const _Podatak({required this.labela, required this.vrijednost});

  final String labela;
  final String vrijednost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labela,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.adminColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(vrijednost, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// „+ Novi termin" u top baru pune liste.
class _NoviTerminDugme extends StatelessWidget {
  const _NoviTerminDugme();

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => context.go(AdminRoute.appointmentNew.path),
      child: const Text('+ Novi termin'),
    );
  }
}

/// „Potvrdi sve bez preklapanja" iz `3d`.
///
/// **Preklapanje ne provjerava aplikacija nego baza.** `appointments_no_overlap` je
/// exclusion constraint, pa potvrda zahtjeva koji se sudara sa već potvrđenim terminom
/// padne sa greškom; ovo dugme zato pokušava redom i **broji** šta je prošlo. Provjera u
/// Dartu bi bila druga istina o istom pravilu, i razišla bi se prvi put kad neko rezerviše
/// u međuvremenu.
class _PotvrdiSveDugme extends ConsumerStatefulWidget {
  const _PotvrdiSveDugme();

  @override
  ConsumerState<_PotvrdiSveDugme> createState() => _PotvrdiSveDugmeState();
}

class _PotvrdiSveDugmeState extends ConsumerState<_PotvrdiSveDugme> {
  bool _uToku = false;

  @override
  Widget build(BuildContext context) {
    final zahtjevi = ref.watch(zahtjeviProvider).valueOrNull ?? const [];

    return OutlinedButton(
      onPressed: _uToku || zahtjevi.isEmpty
          ? null
          : () => _potvrdiSve(zahtjevi),
      child: Text(_uToku ? 'Potvrđujem…' : 'Potvrdi sve bez preklapanja'),
    );
  }

  Future<void> _potvrdiSve(List<Appointment> zahtjevi) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrditi sve zahtjeve?'),
        content: Text(
          'Pokušat ću potvrditi ${zahtjevi.length} ${_zahtjevaTekst(zahtjevi.length)}. '
          'Onaj koji se preklapa sa već potvrđenim terminom ostaje na čekanju.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Potvrdi sve'),
          ),
        ],
      ),
    );
    if (potvrda != true || !mounted) return;

    setState(() => _uToku = true);
    var prosli = 0;
    var pali = 0;

    for (final zahtjev in zahtjevi) {
      try {
        await ref.read(appointmentActionsProvider).potvrdi(zahtjev.id);
        prosli++;
      } on ApiError catch (_) {
        pali++;
      }
    }

    if (!mounted) return;
    setState(() => _uToku = false);
    _poruka(
      context,
      pali == 0
          ? 'Potvrđeno $prosli ${_zahtjevaTekst(prosli)}.'
          : 'Potvrđeno $prosli, preskočeno $pali zbog preklapanja.',
    );
  }
}

class _PrazanDan extends StatelessWidget {
  const _PrazanDan({required this.filter, required this.zahtjevi});

  final AppointmentsFilter filter;
  final bool zahtjevi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              zahtjevi ? Icons.mark_email_read_outlined : Icons.event_available,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(
              zahtjevi
                  ? 'Nijedan zahtjev ne čeka odgovor.'
                  : filter.status == null
                  ? 'Nema termina za ovaj dan.'
                  : 'Nema termina sa statusom „${statusLabela(filter.status!)}".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.adminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.poruka, required this.onPonovi});

  final String poruka;
  final VoidCallback onPonovi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(poruka, textAlign: TextAlign.center),
            const SizedBox(height: AdminSpacing.lg),
            FilledButton(
              onPressed: onPonovi,
              child: const Text('Pokušaj opet'),
            ),
          ],
        ),
      ),
    );
  }
}

void _poruka(BuildContext context, String tekst) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tekst)));

String _cekajuTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva čeka';
  if (zadnja == 1) return 'zahtjev čeka';
  if (zadnja >= 2 && zadnja <= 4) return 'zahtjeva čekaju';
  return 'zahtjeva čeka';
}

String _zahtjevaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return 'zahtjeva';
  if (zadnja == 1) return 'zahtjev';
  return zadnja >= 2 && zadnja <= 4 ? 'zahtjeva' : 'zahtjeva';
}
