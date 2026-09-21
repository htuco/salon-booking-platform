import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/admin_router.dart';
import 'appointments_providers.dart';

/// Ručni unos termina — salon upisuje klijenta koji je nazvao ili došao na vrata.
///
/// ## Zašto ovo nije `insert`
///
/// Do taska 24 je `security.md` ovo vodio kao otvorenu rupu: direktan `insert` sa admin
/// ekrana zaobilazi radno vrijeme, blokade i `min_advance_booking_hours`, jer ih exclusion
/// constraint ne poznaje — hvata samo preklapanje. Salon je mogao upisati termin u nedjelju
/// u 3 ujutro i baza ga ne bi zaustavila.
///
/// Zato ovaj ekran **ne bira vrijeme slobodno**: bira ga iz liste koju je izračunala baza,
/// istom funkcijom kojom prolazi klijent. Jedina razlika je `p_ignore_min_advance`, koji
/// nulira prag od 2 h — salon upisuje klijenta koji stoji pred njim, a to je pravilo prema
/// klijentu, ne fizičko ograničenje salona.
///
/// ## Tok
///
/// Klijent → usluga → radnik → datum → slobodan termin. Isti redoslijed kao klijentski
/// booking flow, jer svaki korak sužava sljedeći: slobodni slotovi ovise o usluzi (trajanje)
/// i radniku (radno vrijeme).
class NewAppointmentScreen extends ConsumerStatefulWidget {
  const NewAppointmentScreen({super.key});

  @override
  ConsumerState<NewAppointmentScreen> createState() =>
      _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends ConsumerState<NewAppointmentScreen> {
  Customer? _klijent;
  Service? _usluga;
  Employee? _radnik;
  DateTime _datum = DateTime.now();

  /// **Vrijeme, ne `AvailableSlot`.** Kad radnik nije izabran, `get_available_slots` vrati po
  /// jedan red za **svakog** slobodnog radnika, pa isto vrijeme dođe više puta — prva verzija
  /// je crtala sirovu listu i na ekranu se vidjelo „09:00 09:00 09:15 09:15…". Korisnik bira
  /// vrijeme; koga dobija odlučuje `book_appointment`, kao i u klijentskom flowu.
  LocalTime? _slot;
  final _napomena = TextEditingController();
  bool _upisujem = false;

  @override
  void dispose() {
    _napomena.dispose();
    super.dispose();
  }

  /// Sve je izabrano i može se upisati.
  ///
  /// Radnik **nije** u ovoj listi: `book_appointment` ga dodijeli sam kad nije izabran, a
  /// izbor „bilo koji" je legitiman i za ručni unos.
  bool get _spremno => _klijent != null && _usluga != null && _slot != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novi termin'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AdminRoute.appointments.path),
          tooltip: 'Zatvori',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Korak(
            broj: 1,
            naslov: 'Klijent',
            child: _IzborKlijenta(
              izabran: _klijent,
              onIzabran: (klijent) => setState(() => _klijent = klijent),
            ),
          ),
          _Korak(
            broj: 2,
            naslov: 'Usluga',
            child: _IzborUsluge(
              izabrana: _usluga,
              onIzabrana: (usluga) => setState(() {
                _usluga = usluga;
                // Promjena usluge mijenja i trajanje i skup radnika, pa slot koji je bio
                // slobodan više ne mora biti. Brisanje je jedini tačan potez — ostavljen
                // slot bi se poslao u `book_appointment` i vratio `PT409` bez objašnjenja.
                _slot = null;
                _radnik = null;
              }),
            ),
          ),
          if (_usluga case final usluga?)
            _Korak(
              broj: 3,
              naslov: 'Radnik',
              child: _IzborRadnika(
                usluga: usluga,
                izabran: _radnik,
                onIzabran: (radnik) => setState(() {
                  _radnik = radnik;
                  _slot = null;
                }),
              ),
            ),
          if (_usluga != null)
            _Korak(
              broj: 4,
              naslov: 'Datum i vrijeme',
              child: _IzborTermina(
                usluga: _usluga!,
                radnik: _radnik,
                datum: _datum,
                izabran: _slot,
                onDatum: (datum) => setState(() {
                  _datum = datum;
                  _slot = null;
                }),
                onSlot: (slot) => setState(() => _slot = slot),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _napomena,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Napomena (nije obavezno)',
              hintText: 'npr. dolazi sa djetetom',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _spremno && !_upisujem ? _upisi : null,
            child: _upisujem
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Upiši termin'),
          ),
          const SizedBox(height: 8),
          // Rečenica koja objašnjava zašto lista vremena izgleda kako izgleda. Bez nje
          // vlasnik koji ne vidi 15:00 misli da je app pokvarena, a slot je zauzet.
          Text(
            'Ponuđena su samo vremena koja su stvarno slobodna — zauzeti termini, '
            'pauze i neradni dani se ne nude.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upisi() async {
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null || !_spremno) return;

    setState(() => _upisujem = true);
    try {
      await ref
          .read(staffAppointmentRepositoryProvider)
          .bookManually(
            salonId: salonId,
            customerId: _klijent!.id,
            serviceId: _usluga!.id,
            date: LocalDate(_datum.year, _datum.month, _datum.day),
            startTime: _slot!,
            // **Radnik iz izbora, ne iz slota** — i `null` kad je „bilo koji". Isto vrijeme
            // stiže po jednom redu za svakog slobodnog radnika, pa bi uzimanje radnika iz
            // prvog reda značilo da ekran tiho bira umjesto korisnika. `book_appointment`
            // sam dodijeli onoga za kojeg je slot i dalje slobodan u trenutku upisa.
            employeeId: _radnik?.id,
            note: _napomena.text.trim().isEmpty ? null : _napomena.text.trim(),
          );

      // Lista termina mora pokazati novi red čim se ekran zatvori.
      ref
        ..invalidate(filtriraniTerminiProvider)
        ..invalidate(danasnjiTerminiProvider)
        ..invalidate(pendingCountProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Termin je upisan.')));
      context.go(AdminRoute.appointments.path);
    } on ApiError catch (greska) {
      if (!mounted) return;
      // `ConflictError` je **očekivan ishod**, ne kvar: između učitavanja liste slotova i
      // ovog poziva je neko drugi mogao uzeti isti slot. Ekran zato briše izbor i tjera na
      // ponovni — isto kao klijentski flow.
      final poruka = greska is ConflictError
          ? 'Termin je upravo zauzet. Izaberite drugo vrijeme.'
          : 'Termin nije upisan. Pokušajte ponovo.';
      if (greska is ConflictError) setState(() => _slot = null);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(poruka)));
    } finally {
      if (mounted) setState(() => _upisujem = false);
    }
  }
}

/// Numerisan korak sa naslovom — ista struktura kao klijentski booking flow.
class _Korak extends StatelessWidget {
  const _Korak({required this.broj, required this.naslov, required this.child});

  final int broj;
  final String naslov;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$broj. $naslov',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Pretraga postojećih klijenata, uz unos telefonskog.
class _IzborKlijenta extends ConsumerStatefulWidget {
  const _IzborKlijenta({required this.izabran, required this.onIzabran});

  final Customer? izabran;
  final ValueChanged<Customer?> onIzabran;

  @override
  ConsumerState<_IzborKlijenta> createState() => _IzborKlijentaState();
}

class _IzborKlijentaState extends ConsumerState<_IzborKlijenta> {
  final _polje = TextEditingController();
  List<Customer> _rezultati = const [];
  bool _trazim = false;

  @override
  void dispose() {
    _polje.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.izabran case final klijent?) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(klijent.name),
          subtitle: Text(
            [
              if (klijent.hasPhone) klijent.phone!,
              // Telefonski klijent je vidljivo označen: salon tako zna da red smije
              // slobodno mijenjati, jer nije vezan za tuđi nalog.
              if (klijent.isWalkin) 'telefonski klijent',
              if (klijent.visitCount > 0) '${klijent.visitCount} posjeta',
            ].join(' · '),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Promijeni klijenta',
            onPressed: () {
              _polje.clear();
              setState(() => _rezultati = const []);
              widget.onIzabran(null);
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _polje,
          decoration: InputDecoration(
            labelText: 'Pretraži po imenu ili telefonu',
            border: const OutlineInputBorder(),
            suffixIcon: _trazim
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: (_) => _trazi(),
        ),
        const SizedBox(height: 8),
        for (final klijent in _rezultati)
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(klijent.name),
            subtitle: klijent.hasPhone ? Text(klijent.phone!) : null,
            onTap: () => widget.onIzabran(klijent),
          ),
        // **Unos novog klijenta stoji uvijek, ne samo kad pretraga ne nađe ništa.** Čovjek
        // koji zove prvi put se ne nalazi pretragom, a vlasnik ne treba prvo pretraživati
        // da bi otkrio da ga nema.
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _noviKlijent,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Novi klijent (telefonski)'),
        ),
      ],
    );
  }

  Future<void> _trazi() async {
    final salonId = ref.read(adminSalonIdProvider);
    final upit = _polje.text.trim();
    if (salonId == null || upit.isEmpty) {
      setState(() => _rezultati = const []);
      return;
    }

    setState(() => _trazim = true);
    try {
      final nadjeni = await ref
          .read(staffAppointmentRepositoryProvider)
          .searchCustomers(salonId: salonId, upit: upit);
      // Polje se u međuvremenu moglo promijeniti: rezultat starijeg upita ne smije
      // prepisati noviji. Poredi se tekst, ne vrijeme — jednostavnije i tačnije od
      // debounce-a za ovu količinu podataka.
      if (!mounted || _polje.text.trim() != upit) return;
      setState(() => _rezultati = nadjeni);
    } on ApiError {
      if (!mounted) return;
      setState(() => _rezultati = const []);
    } finally {
      if (mounted) setState(() => _trazim = false);
    }
  }

  Future<void> _noviKlijent() async {
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null) return;

    final podaci = await showDialog<({String ime, String telefon})>(
      context: context,
      builder: (context) => const _NoviKlijentDijalog(),
    );
    if (podaci == null) return;

    try {
      final klijent = await ref
          .read(staffAppointmentRepositoryProvider)
          .upsertWalkinCustomer(
            salonId: salonId,
            name: podaci.ime,
            phone: podaci.telefon.isEmpty ? null : podaci.telefon,
          );
      if (!mounted) return;
      widget.onIzabran(klijent);
    } on ApiError {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Klijent nije sačuvan. Pokušajte ponovo.'),
          ),
        );
    }
  }
}

/// Unos telefonskog klijenta — ime obavezno, telefon nije.
///
/// **Telefon nije obavezan, ali se traži.** Bez njega se isti čovjek pri sljedećem pozivu ne
/// može prepoznati i nastaje drugi red; sa njim `unique(salon_id, phone)` to spriječi. Polje
/// zato ima objašnjenje, a ne validaciju — salon koji nema broj mora moći upisati termin.
class _NoviKlijentDijalog extends StatefulWidget {
  const _NoviKlijentDijalog();

  @override
  State<_NoviKlijentDijalog> createState() => _NoviKlijentDijalogState();
}

class _NoviKlijentDijalogState extends State<_NoviKlijentDijalog> {
  final _ime = TextEditingController();
  final _telefon = TextEditingController();

  @override
  void dispose() {
    _ime.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novi klijent'),
      // `SingleChildScrollView`: dva polja plus tastatura prelaze raspoloživu visinu na
      // malom ekranu, a `AlertDialog` je sam ne ograničava — ista zamka koja je u
      // `appointment_actions_bar.dart` dala preliv od 99672px.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ime,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ime i prezime',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefon,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                helperText: 'Bez broja se klijent ne prepoznaje sljedeći put',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          // Prazno ime baza odbija sa `PT400`; dugme se gasi da vlasnik do te greške ni ne
          // dođe. Provjera je u obje strane namjerno — ekran zbog udobnosti, baza zbog
          // garancije.
          onPressed: _ime.text.trim().isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop((ime: _ime.text.trim(), telefon: _telefon.text.trim())),
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}

class _IzborUsluge extends ConsumerWidget {
  const _IzborUsluge({required this.izabrana, required this.onIzabrana});

  final Service? izabrana;
  final ValueChanged<Service> onIzabrana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usluge = ref.watch(adminServicesProvider);

    return usluge.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Usluge se ne mogu učitati.'),
      data: (lista) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final usluga in lista)
            ChoiceChip(
              label: Text('${usluga.name} · ${usluga.durationMinutes} min'),
              selected: izabrana?.id == usluga.id,
              onSelected: (_) => onIzabrana(usluga),
            ),
        ],
      ),
    );
  }
}

class _IzborRadnika extends ConsumerWidget {
  const _IzborRadnika({
    required this.usluga,
    required this.izabran,
    required this.onIzabran,
  });

  final Service usluga;
  final Employee? izabran;
  final ValueChanged<Employee?> onIzabran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radnici = ref.watch(adminEmployeesProvider);
    final veze = ref.watch(adminEmployeeLinksProvider);

    if (radnici.isLoading || veze.isLoading) {
      return const LinearProgressIndicator();
    }

    final sviRadnici = radnici.valueOrNull ?? const <Employee>[];
    final sveVeze = veze.valueOrNull ?? const <EmployeeService>[];

    // **Presjek, ne svi radnici.** Isti račun kao u klijentskom booking flowu: radnik koji
    // ne radi izabranu uslugu se ne nudi. Salon sa frizerom i kozmetičarom bi inače mogao
    // upisati kozmetičara za šišanje, a `get_available_slots` bi vratio praznu listu bez
    // objašnjenja.
    final dozvoljeni = sveVeze
        .where((veza) => veza.serviceId == usluga.id)
        .map((veza) => veza.employeeId)
        .toSet();
    final zaUslugu = sviRadnici
        .where((radnik) => radnik.isActive && dozvoljeni.contains(radnik.id))
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // „Bilo koji" je i ovdje legitiman izbor: `book_appointment` dodijeli radnika za
        // kojeg je slot slobodan.
        ChoiceChip(
          label: const Text('Bilo koji'),
          selected: izabran == null,
          onSelected: (_) => onIzabran(null),
        ),
        for (final radnik in zaUslugu)
          ChoiceChip(
            label: Text(radnik.name),
            selected: izabran?.id == radnik.id,
            onSelected: (_) => onIzabran(radnik),
          ),
      ],
    );
  }
}

/// Datum i lista slobodnih vremena.
class _IzborTermina extends ConsumerStatefulWidget {
  const _IzborTermina({
    required this.usluga,
    required this.radnik,
    required this.datum,
    required this.izabran,
    required this.onDatum,
    required this.onSlot,
  });

  final Service usluga;
  final Employee? radnik;
  final DateTime datum;
  final LocalTime? izabran;
  final ValueChanged<DateTime> onDatum;
  final ValueChanged<LocalTime> onSlot;

  @override
  ConsumerState<_IzborTermina> createState() => _IzborTerminaState();
}

class _IzborTerminaState extends ConsumerState<_IzborTermina> {
  List<AvailableSlot>? _slotovi;
  bool _ucitavam = false;

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  @override
  void didUpdateWidget(_IzborTermina stari) {
    super.didUpdateWidget(stari);
    // Usluga, radnik ili datum su se promijenili — lista slotova više ne vrijedi.
    if (stari.usluga.id != widget.usluga.id ||
        stari.radnik?.id != widget.radnik?.id ||
        !_istiDan(stari.datum, widget.datum)) {
      _ucitaj();
    }
  }

  static bool _istiDan(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _ucitaj() async {
    final salonId = ref.read(adminSalonIdProvider);
    if (salonId == null) return;

    setState(() => _ucitavam = true);
    try {
      final slotovi = await ref
          .read(staffAppointmentRepositoryProvider)
          .slotsForManualBooking(
            salonId: salonId,
            serviceId: widget.usluga.id,
            date: LocalDate(
              widget.datum.year,
              widget.datum.month,
              widget.datum.day,
            ),
            employeeId: widget.radnik?.id,
          );
      if (!mounted) return;
      setState(() => _slotovi = slotovi);
    } on ApiError {
      if (!mounted) return;
      setState(() => _slotovi = const []);
    } finally {
      if (mounted) setState(() => _ucitavam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final izabran = await showDatePicker(
              context: context,
              initialDate: widget.datum,
              // Unazad se ne ide: ručni termin je termin koji tek treba biti. Prošli dan
              // bi `get_available_slots` ionako odbio, ali dugme koje vodi u praznu listu
              // je gore od dugmeta kojeg nema.
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (izabran != null) widget.onDatum(izabran);
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_datumTekst(widget.datum)),
        ),
        const SizedBox(height: 12),
        if (_ucitavam)
          const LinearProgressIndicator()
        else if (_slotovi case final slotovi?)
          if (slotovi.isEmpty)
            Text(
              'Nema slobodnih termina ovog dana. Provjerite radno vrijeme, '
              'blokade i već zauzete termine.',
              style: theme.textTheme.bodySmall,
            )
          else
            // **`distinctTimes`, ne sirova lista.** Kad radnik nije izabran, funkcija vrati
            // po jedan red za svakog slobodnog radnika, pa je prva verzija crtala
            // „09:00 09:00 09:15 09:15…" — vidjelo se tek na ekranu, jer je i takva lista
            // ispravan izlaz iz baze. Isti pomoćnik koristi i klijentski korak 3
            // (`slot_step_screen.dart`); dvije kopije istog grupisanja bile bi dvije
            // prilike da se raziđu.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final vrijeme in slotovi.distinctTimes)
                  ChoiceChip(
                    label: Text(_vrijeme(vrijeme)),
                    selected: widget.izabran == vrijeme,
                    onSelected: (_) => widget.onSlot(vrijeme),
                  ),
              ],
            ),
      ],
    );
  }

  static String _vrijeme(LocalTime vrijeme) =>
      '${vrijeme.hour.toString().padLeft(2, '0')}:'
      '${vrijeme.minute.toString().padLeft(2, '0')}';

  static String _datumTekst(DateTime dan) =>
      '${dan.day}.${dan.month}.${dan.year}.';
}
