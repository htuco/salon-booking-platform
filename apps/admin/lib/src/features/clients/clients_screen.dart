import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../appointments/status_pill.dart';
import '../../core/widgets/admin_skeleton.dart';
import 'clients_providers.dart';

/// Ime klijenta kako ga ekran smije prikazati.
///
/// **Brisanje naloga (task 17) anonimizira red**: `customers.name` je `not null`, pa
/// obrisan klijent dobije tekst „Obrisan klijent" umjesto imena. Uz to red iz starijeg
/// importa može nositi prazan string. Oboje ovdje izgleda isto — prazno mjesto na kojem
/// treba stajati ime je gore od riječi koja kaže da imena nema.
String imeKlijenta(Customer klijent) {
  final ime = klijent.name.trim();
  return ime.isEmpty ? 'Bez imena' : ime;
}

/// Inicijal za avatar.
///
/// Canvas `3e` crta fotografije, ali `customers` nema sliku — kao i kod kolone radnika u
/// kalendaru (task 31), stoji inicijal umjesto slomljene slike.
String inicijal(Customer klijent) {
  final ime = imeKlijenta(klijent);
  return ime.characters.first.toUpperCase();
}

/// Telefon, ili ono što stoji umjesto njega.
///
/// **Klijent bez broja nije greška.** Prijavljen korisnik ga nikad nije morao ostaviti, a
/// anonimizacija ga briše. Prazno mjesto bi izgledalo kao da se podatak nije učitao.
String telefonKlijenta(Customer klijent) =>
    klijent.hasPhone ? klijent.phone!.trim() : 'Bez broja';

class AdminClientsScreen extends ConsumerWidget {
  const AdminClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = AdminShell.jeDesktop(context);
    return AdminScaffold(
      title: 'Klijenti',
      aktivna: AdminRoute.clients,
      body: desktop ? const _Desktop() : const _Telefon(),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop `3e` — lista lijevo, profil desno
// ---------------------------------------------------------------------------

class _Desktop extends ConsumerWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabrani = ref.watch(izabraniKlijentProvider);
    final gutter = AdminShell.gutterOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, AdminSpacing.xxl, gutter, 0),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Zaglavlje(),
                SizedBox(height: AdminSpacing.lg),
                _Filteri(),
                SizedBox(height: AdminSpacing.lg),
                Expanded(child: _Lista()),
              ],
            ),
          ),
        ),
        // Profil je **pola ekrana kad je otvoren, i ništa kad nije**. Prazan panel
        // stalne širine oduzima prostor tabeli zbog nečega što korisnik nije tražio.
        if (izabrani != null)
          SizedBox(
            width: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.adminColors.surface,
                border: Border(
                  left: BorderSide(
                    color: context.adminColors.border,
                    width: AdminSize.hairline,
                  ),
                ),
              ),
              child: _Profil(customerId: izabrani),
            ),
          ),
      ],
    );
  }
}

class _Zaglavlje extends ConsumerWidget {
  const _Zaglavlje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijenti = ref.watch(adminKlijentiProvider);
    final boje = context.adminColors;

    // Brojke opisuju **ono što je na ekranu**, ne cijeli adresar: lista je filtrirana i
    // odrezana na `limit`, pa bi „342 ukupno" iz canvasa bila tvrdnja koju ovaj upit ne
    // može dokazati. Podnaslov zato broji prikazane redove.
    final ukupno = klijenti.valueOrNull?.length;
    final redovnih = klijenti.valueOrNull
        ?.where((k) => k.visitCount >= ClientsFilter.pragRedovnog)
        .length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Klijenti', style: AdminText.display),
              const SizedBox(height: AdminSpacing.xs),
              Text(
                ukupno == null
                    ? 'Učitavanje…'
                    : '$ukupno prikazano · $redovnih redovnih',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: boje.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AdminSpacing.lg),
        const SizedBox(width: 260, child: _Pretraga()),
      ],
    );
  }
}

class _Pretraga extends ConsumerStatefulWidget {
  const _Pretraga();

  @override
  ConsumerState<_Pretraga> createState() => _PretragaState();
}

class _PretragaState extends ConsumerState<_Pretraga> {
  late final TextEditingController _kontroler;

  @override
  void initState() {
    super.initState();
    // Polje se gradi iz stanja, a ne obrnuto: prelazak sa telefona na desktop podiže
    // drugi widget, i unos bi se izgubio da se čita samo iz kontrolera.
    _kontroler = TextEditingController(text: ref.read(clientsPretragaProvider));
  }

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _kontroler,
      decoration: InputDecoration(
        hintText: 'Ime ili broj telefona',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _kontroler.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Očisti pretragu',
                onPressed: () {
                  _kontroler.clear();
                  ref.read(clientsPretragaProvider.notifier).postavi('');
                  setState(() {});
                },
              ),
        isDense: true,
      ),
      onChanged: (izraz) {
        ref.read(clientsPretragaProvider.notifier).postavi(izraz);
        setState(() {});
      },
    );
  }
}

class _Filteri extends ConsumerWidget {
  const _Filteri();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabran = ref.watch(clientsFilterProvider);

    // `Wrap`, ne `Row`: četiri kartice na uskom desktop prozoru prelaze u drugi red
    // umjesto da prelijevaju. Prvi preljev koji je ovaj repo našao (task 34) bio je
    // tačno ovakav red dugmadi.
    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      children: [
        for (final filter in ClientsFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: filter == izabran,
            onSelected: (_) =>
                ref.read(clientsFilterProvider.notifier).postavi(filter),
          ),
      ],
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijenti = ref.watch(adminKlijentiProvider);
    final izabrani = ref.watch(izabraniKlijentProvider);
    final boje = context.adminColors;

    return klijenti.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AdminSpacing.xxl),
        child: AdminSkeletonList(),
      ),
      error: (_, _) => _Greska(
        poruka: 'Klijenti se ne mogu učitati.',
        ponovo: () => ref.invalidate(adminKlijentiProvider),
      ),
      data: (redovi) {
        if (redovi.isEmpty) return const _Prazno();

        return DecoratedBox(
          decoration: BoxDecoration(
            color: boje.surface,
            borderRadius: BorderRadius.circular(AdminRadius.base),
            border: Border.all(color: boje.border, width: AdminSize.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ZaglavljeTabele(),
              Expanded(
                child: ListView.builder(
                  itemCount: redovi.length,
                  itemBuilder: (context, i) => _Red(
                    klijent: redovi[i],
                    izabran: redovi[i].id == izabrani,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZaglavljeTabele extends StatelessWidget {
  const _ZaglavljeTabele();

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.xl,
        AdminSpacing.lg,
        AdminSpacing.xl,
        AdminSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: boje.border, width: AdminSize.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _CelijaZaglavlja('Klijent')),
          SizedBox(width: 150, child: _CelijaZaglavlja('Zadnji dolazak')),
          SizedBox(width: 110, child: _CelijaZaglavlja('Dolazaka')),
          SizedBox(width: 130, child: _CelijaZaglavlja('Status')),
        ],
      ),
    );
  }
}

class _CelijaZaglavlja extends StatelessWidget {
  const _CelijaZaglavlja(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) => Text(
    tekst.toUpperCase(),
    style: AdminText.eyebrow.copyWith(color: context.adminColors.textSecondary),
  );
}

class _Red extends ConsumerWidget {
  const _Red({required this.klijent, required this.izabran});

  final Customer klijent;
  final bool izabran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;

    return InkWell(
      onTap: () =>
          ref.read(izabraniKlijentProvider.notifier).izaberi(klijent.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.xl,
          vertical: AdminSpacing.md,
        ),
        decoration: BoxDecoration(
          color: izabran ? boje.accentTint : null,
          border: Border(
            bottom: BorderSide(color: boje.border, width: AdminSize.hairline),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _ImeSaAvatarom(klijent: klijent)),
            SizedBox(
              width: 150,
              child: Text(
                _zadnjiDolazak(klijent),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: boje.textSecondary),
              ),
            ),
            SizedBox(
              width: 110,
              child: Text('${klijent.visitCount}', style: AdminText.time),
            ),
            SizedBox(width: 130, child: _Oznaka(klijent: klijent)),
          ],
        ),
      ),
    );
  }
}

/// `02. maj 2026.`, ili riječ umjesto datuma.
///
/// **`null` znači „nijedan termin nije održan"**, ne „podatak nedostaje". Crtica bi se
/// čitala kao greška u učitavanju; „Nikad" kaže šta stvarno stoji u redu.
String _zadnjiDolazak(Customer klijent) {
  final zadnji = klijent.lastVisitAt;
  return zadnji == null ? 'Nikad' : datumSaGodinom(zadnji);
}

class _ImeSaAvatarom extends StatelessWidget {
  const _ImeSaAvatarom({required this.klijent, this.veliki = false});

  final Customer klijent;
  final bool veliki;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final promjer = veliki ? 52.0 : 38.0;

    return Row(
      children: [
        Container(
          width: promjer,
          height: promjer,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: boje.accentTint,
            shape: BoxShape.circle,
          ),
          child: Text(
            inicijal(klijent),
            style: (veliki ? AdminText.metricNumber : null) == null
                ? TextStyle(
                    color: boje.accentInk,
                    fontWeight: FontWeight.w600,
                    fontSize: veliki ? 22 : 15,
                  )
                : TextStyle(
                    color: boje.accentInk,
                    fontWeight: FontWeight.w600,
                    fontSize: veliki ? 22 : 15,
                  ),
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                imeKlijenta(klijent),
                style: veliki
                    ? AdminText.display.copyWith(fontSize: 26)
                    : Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                telefonKlijenta(klijent),
                style: AdminText.dataInline.copyWith(
                  color: boje.textSecondary,
                  fontSize: veliki ? 14 : 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Oznaka klijenta — „Redovan", „VIP", „Nedolasci", ili ništa.
///
/// **Jedna oznaka po redu, po prioritetu.** Tri pilule u koloni od 130 px se preliju, a i
/// canvas `3e` crta tačno jednu. VIP je iznad ostalog jer ga salon dodjeljuje ručno:
/// odluka čovjeka ide ispred brojača.
class _Oznaka extends StatelessWidget {
  const _Oznaka({required this.klijent});

  final Customer klijent;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;

    final (tekst, pozadina, tekstBoja) = switch (klijent) {
      final k when k.isVip => ('VIP', boje.accentTint, boje.accentInk),
      final k when k.noShowCount >= ClientsFilter.pragNedolaska => (
        'Nedolasci',
        boje.waitingTint,
        boje.waitingInk,
      ),
      final k when k.visitCount >= ClientsFilter.pragRedovnog => (
        'Redovan',
        boje.neutralTint,
        boje.textSecondary,
      ),
      _ => (null, boje.neutralTint, boje.textSecondary),
    };

    if (tekst == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: pozadina,
          borderRadius: BorderRadius.circular(AdminRadius.pill),
        ),
        child: Text(
          tekst,
          style: AdminText.statusLabel.copyWith(color: tekstBoja),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class _Profil extends ConsumerWidget {
  const _Profil({required this.customerId, this.saZatvaranjem = false});

  final String customerId;

  /// Telefon profil otvara preko liste, pa mu treba izlaz. Desktop ga drži uz listu.
  final bool saZatvaranjem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijent = ref.watch(klijentProvider(customerId));

    return klijent.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AdminSpacing.xxl),
        child: AdminSkeletonList(),
      ),
      error: (_, _) => _Greska(
        poruka: 'Profil se ne može učitati.',
        ponovo: () => ref.invalidate(klijentProvider(customerId)),
      ),
      // `null` je predviđeno stanje: red je obrisan, ili je od tuđeg salona i RLS ga nije
      // propustio. Ekran oba prikazuje isto — poruka „nemate pravo" bi potvrdila da taj
      // klijent postoji, a to je kod baš ove tabele podatak o konkurenciji.
      data: (red) => red == null
          ? const _Greska(poruka: 'Ovaj klijent više ne postoji.')
          : _ProfilSadrzaj(klijent: red, saZatvaranjem: saZatvaranjem),
    );
  }
}

class _ProfilSadrzaj extends ConsumerWidget {
  const _ProfilSadrzaj({required this.klijent, required this.saZatvaranjem});

  final Customer klijent;
  final bool saZatvaranjem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final istorija = ref.watch(klijentIstorijaProvider(klijent.id));
    final boje = context.adminColors;

    return ListView(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      children: [
        Row(
          children: [
            Expanded(child: _ImeSaAvatarom(klijent: klijent, veliki: true)),
            if (saZatvaranjem)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Zatvori profil',
                onPressed: () =>
                    ref.read(izabraniKlijentProvider.notifier).izaberi(null),
              ),
          ],
        ),
        // Telefonski klijent nema nalog, i to je ispravno stanje, ne greška — salon ga je
        // unio po pozivu. Rečenica stoji da se prazan `auth_identity_id` ne bi čitao kao
        // neispravan red.
        if (klijent.isWalkin) ...[
          const SizedBox(height: AdminSpacing.md),
          Text(
            'Unesen u salonu — nema nalog u aplikaciji.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: boje.textSecondary),
          ),
        ],
        const SizedBox(height: AdminSpacing.xl),
        _Metrike(klijent: klijent, istorija: istorija.valueOrNull),
        const SizedBox(height: AdminSpacing.xxl),
        Text('Historija', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AdminSpacing.md),
        istorija.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AdminSpacing.xxl),
            child: AdminSkeletonList(),
          ),
          error: (_, _) => _Greska(
            poruka: 'Historija se ne može učitati.',
            ponovo: () => ref.invalidate(klijentIstorijaProvider(klijent.id)),
          ),
          data: (termini) => termini.isEmpty
              ? Text(
                  'Nijedan termin još nije zakazan.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: boje.textSecondary),
                )
              : Column(
                  children: [
                    for (final termin in termini) _RedIstorije(termin: termin),
                  ],
                ),
        ),
        if (klijent.note != null && klijent.note!.trim().isNotEmpty) ...[
          const SizedBox(height: AdminSpacing.xxl),
          Text('Bilješka', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AdminSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AdminSpacing.lg),
            decoration: BoxDecoration(
              color: boje.neutralTint,
              borderRadius: BorderRadius.circular(AdminRadius.base),
            ),
            child: Text(
              klijent.note!.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _Metrike extends StatelessWidget {
  const _Metrike({required this.klijent, required this.istorija});

  final Customer klijent;
  final List<Appointment>? istorija;

  @override
  Widget build(BuildContext context) {
    final zbir = istorija == null ? null : potroseno(istorija!);

    return Row(
      children: [
        Expanded(
          child: _Metrika(broj: '${klijent.visitCount}', labela: 'dolazaka'),
        ),
        const SizedBox(width: AdminSpacing.sm),
        Expanded(
          child: _Metrika(broj: '${klijent.noShowCount}', labela: 'nedolazaka'),
        ),
        const SizedBox(width: AdminSpacing.sm),
        // **Nema podatka ≠ nula.** Zbir se crta samo kad bar jedan održan termin nosi
        // cijenu; inače bi „0 KM" tvrdilo da klijent nije ništa potrošio, umjesto da se
        // ne zna. Isto pravilo kao u tasku 30: prazno mjesto je bolje od lažne brojke.
        Expanded(
          child: _Metrika(
            broj: zbir == null ? '—' : iznosKm(zbir).replaceAll(' KM', ''),
            labela: zbir == null ? 'nema cijena' : 'KM ukupno',
          ),
        ),
      ],
    );
  }
}

class _Metrika extends StatelessWidget {
  const _Metrika({required this.broj, required this.labela});

  final String broj;
  final String labela;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: boje.neutralTint,
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(broj, style: AdminText.metricNumber),
          ),
          const SizedBox(height: 2),
          Text(
            labela,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: boje.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RedIstorije extends StatelessWidget {
  const _RedIstorije({required this.termin});

  final Appointment termin;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final cijena = termin.servicePrice;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: boje.border, width: AdminSize.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termin.serviceName ?? 'Usluga',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _datumIRadnik(termin),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: boje.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Otkazani i nedošli termini **ostaju u listi**, sa svojom oznakom:
              // istorija koja pokazuje samo održane ne bi objasnila `no_show_count`
              // u istom profilu.
              AppointmentStatusPill(status: termin.status),
              if (cijena != null) ...[
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  iznosKm(cijena),
                  style: AdminText.time.copyWith(color: boje.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// `02.05. · Emir`, ili samo datum kad radnika nema.
///
/// `employee_name` je nullable — termin je mogao biti zakazan na „bilo ko", ili je radnik
/// u međuvremenu obrisan (kolona „Bez radnika" iz taska 31 je ista stvar).
String _datumIRadnik(Appointment termin) {
  final datum = datumSaGodinom(
    DateTime(termin.date.year, termin.date.month, termin.date.day),
  );
  final radnik = termin.employeeName?.trim();
  return radnik == null || radnik.isEmpty ? datum : '$datum · $radnik';
}

// ---------------------------------------------------------------------------
// Telefon `3o` — lista, profil preko nje
// ---------------------------------------------------------------------------

class _Telefon extends ConsumerWidget {
  const _Telefon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final izabrani = ref.watch(izabraniKlijentProvider);
    final gutter = AdminShell.gutterOf(context);

    // Profil **zamjenjuje** listu umjesto da se otvara kao sheet: `3o` ga crta kao punu
    // površinu, a i sadržaj je predugačak za sheet na 402 px.
    if (izabrani != null) {
      return _Profil(customerId: izabrani, saZatvaranjem: true);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AdminSpacing.lg, gutter, 0),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pretraga(),
          SizedBox(height: AdminSpacing.md),
          _Filteri(),
          SizedBox(height: AdminSpacing.md),
          Expanded(child: _MobilnaLista()),
        ],
      ),
    );
  }
}

class _MobilnaLista extends ConsumerWidget {
  const _MobilnaLista();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klijenti = ref.watch(adminKlijentiProvider);

    return klijenti.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AdminSpacing.xxl),
        child: AdminSkeletonList(),
      ),
      error: (_, _) => _Greska(
        poruka: 'Klijenti se ne mogu učitati.',
        ponovo: () => ref.invalidate(adminKlijentiProvider),
      ),
      data: (redovi) => redovi.isEmpty
          ? const _Prazno()
          : ListView.separated(
              itemCount: redovi.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AdminSpacing.sm),
              itemBuilder: (context, i) => _MobilnaKartica(klijent: redovi[i]),
            ),
    );
  }
}

class _MobilnaKartica extends ConsumerWidget {
  const _MobilnaKartica({required this.klijent});

  final Customer klijent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boje = context.adminColors;

    return InkWell(
      onTap: () =>
          ref.read(izabraniKlijentProvider.notifier).izaberi(klijent.id),
      borderRadius: BorderRadius.circular(AdminRadius.base),
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        decoration: BoxDecoration(
          color: boje.surface,
          borderRadius: BorderRadius.circular(AdminRadius.base),
          border: Border.all(color: boje.border, width: AdminSize.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImeSaAvatarom(klijent: klijent),
            const SizedBox(height: AdminSpacing.md),
            // `Wrap`: na 402 px se datum, broj dolazaka i oznaka ne mogu poredati u red
            // bez preljeva — dvije takve greške je ovaj repo već imao (task 34).
            Wrap(
              spacing: AdminSpacing.md,
              runSpacing: AdminSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _zadnjiDolazak(klijent),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: boje.textSecondary),
                ),
                Text(
                  '${klijent.visitCount} dolazaka',
                  style: AdminText.dataInline.copyWith(
                    color: boje.textSecondary,
                  ),
                ),
                _Oznaka(klijent: klijent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zajednička prazna i greška stanja
// ---------------------------------------------------------------------------

class _Prazno extends ConsumerWidget {
  const _Prazno();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pretraga = ref.watch(clientsPretragaProvider).trim();
    final filter = ref.watch(clientsFilterProvider);
    final boje = context.adminColors;

    // Tri prazna stanja, jer tri različita razloga traže tri različita sljedeća koraka.
    final poruka = pretraga.isNotEmpty
        ? 'Nema klijenta koji odgovara pretrazi „$pretraga".'
        : filter == ClientsFilter.svi
        ? 'Adresar je još prazan. Klijent se upiše kad zakaže prvi termin.'
        : 'Nema klijenta u grupi „${filter.label}".';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxl),
        child: Text(
          poruka,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: boje.textSecondary),
        ),
      ),
    );
  }
}

class _Greska extends StatelessWidget {
  const _Greska({required this.poruka, this.ponovo});

  final String poruka;
  final VoidCallback? ponovo;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(poruka, textAlign: TextAlign.center),
          if (ponovo != null)
            TextButton(onPressed: ponovo, child: const Text('Pokušaj ponovo')),
        ],
      ),
    ),
  );
}
