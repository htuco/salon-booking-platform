import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/admin_verzal.dart';
import 'appointments_providers.dart';

/// Pita za obrazloženje odbijanja ili otkazivanja; `null` znači da je korisnik odustao.
///
/// Javno jer isti dijalog troše i kartice zahtjeva (`zahtjev_kartica.dart`) — drugi dijalog
/// za istu radnju bi se prvi put razišao kad se promijeni tekst koji klijent vidi.
Future<String?> pitajZaRazlog(
  BuildContext context, {
  required String naslov,
  required String opis,
  required String potvrda,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _RazlogDijalog(naslov: naslov, opis: opis, potvrda: potvrda),
);

/// Greška iz baze prevedena u rečenicu koju vlasnik može iskoristiti.
///
/// `ConflictError` je ovdje **očekivan ishod, ne kvar**: neko je već promijenio termin
/// (drugi uređaj, ili je `pending` istekao). Generička poruka bi vlasnika poslala da
/// ponovo tapne isto dugme.
String tekstGreskeAkcije(ApiError greska) => switch (greska) {
  ConflictError() => 'Termin je u međuvremenu promijenjen. Osvježite listu.',
  NotFoundError() => 'Termin više ne postoji.',
  _ => 'Akcija nije uspjela. Pokušajte ponovo.',
};

/// Radnja koju handoff crta, a iza koje još nema podatka ni RPC-a.
///
/// Dugme stoji da raspored bude onaj iz `adminv2`, ali tap kaže istinu umjesto da glumi
/// radnju.
void pokaziUskoro(BuildContext context, String sta) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('$sta — uskoro.')));
}

/// Akcije nad jednim terminom, ispod njegovog reda u listi.
///
/// **Koje se akcije nude zavisi od statusa**, i to nije kozmetika: „Potvrdi" nad otkazanim
/// terminom baza odbija sa `PT409`, pa dugme koje bi ga ponudilo vodi u grešku koja se mogla
/// izbjeći. Isto vrijedi obrnuto — termin koji čeka nema šta da se „završi" prije nego je
/// potvrđen.
///
/// Zatvoren termin (`cancelled`, `completed`, `no_show`) nema nijednu akciju i traka se ne
/// crta. Prazan red dugmadi ispod svakog završenog termina bi listu produžio bez razloga.
class AppointmentActionsBar extends ConsumerStatefulWidget {
  const AppointmentActionsBar({
    required this.termin,
    this.veliko = false,
    super.key,
  });

  final Appointment termin;

  /// Traka u dnu ekrana detalja (`3n`), umjesto reda dugmadi u kartici.
  ///
  /// Isti skup akcija i isti dijalozi — mijenja se **samo raspored**: prva radnja preko
  /// cijele širine, ostale u redu ispod nje. Druga implementacija istih akcija bi značila
  /// dva mjesta na kojima se pita za obrazloženje odbijanja, i dva koja se raziđu.
  final bool veliko;

  @override
  ConsumerState<AppointmentActionsBar> createState() =>
      _AppointmentActionsBarState();
}

class _AppointmentActionsBarState extends ConsumerState<AppointmentActionsBar> {
  /// Sprječava drugi tap dok prvi traje.
  ///
  /// Baza je idempotentna pa dupli tap ne bi pokvario podatak, ali bi poslao drugi zahtjev
  /// i kratko pokazao dvije poruke. Zaključavanje je u stanju widgeta, ne u provideru: dvije
  /// kartice u istoj listi se zaključavaju nezavisno.
  bool _uToku = false;

  @override
  Widget build(BuildContext context) {
    final termin = widget.termin;

    // Zatvoren termin nema akcija. `isClosed` je na modelu, pa se pravilo ne prepisuje
    // ovdje — kad dođe novi zatvoreni status, ova traka nestane sama.
    if (termin.status.isClosed) return const SizedBox.shrink();

    final akcije = _akcije(termin);
    if (akcije.isEmpty) return const SizedBox.shrink();

    if (widget.veliko) {
      // `3n`: prva radnja preko cijele širine (54), ostale u redu ispod (50), razmak 10.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 54, child: akcije.first),
          if (akcije.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final akcija in akcije.skip(1)) ...[
                  Expanded(child: SizedBox(height: 50, child: akcija)),
                  if (akcija != akcije.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ],
      );
    }

    // **Bez vlastitog paddinga.** Do taska 30 je traka stajala ispod `ListTile`-a i
    // poravnavala se uvlakom od 72 px; sada je podnožje kartice, koja svoj padding već
    // ima. Zatečena uvlaka je na 402 px izlazila 48 px van kartice.
    return Wrap(spacing: 9, runSpacing: 9, children: akcije);
  }

  /// Koje radnje status dopušta, istaknuta prva.
  List<_Akcija> _akcije(Appointment termin) => switch (termin.status) {
    // Zahtjev koji čeka: potvrdi ili odbij. Dvije jedine radnje koje na njemu imaju
    // smisla, i razlog zbog kojeg cijeli task postoji.
    AppointmentStatus.pending => [
      _Akcija(
        ikona: Icons.check,
        labela: 'Potvrdi',
        istaknuta: true,
        veliko: widget.veliko,
        onTap: _uToku ? null : () => _potvrdi(termin),
      ),
      _Akcija(
        ikona: Icons.close,
        labela: 'Odbij',
        destruktivna: true,
        veliko: widget.veliko,
        onTap: _uToku ? null : () => _odbij(termin),
      ),
    ],
    // Potvrđen termin: prošao je (završen / nije došao) ili ga salon mora otkazati.
    AppointmentStatus.confirmed => [
      _Akcija(
        ikona: Icons.done_all,
        // `3n` piše cijelu rečenicu na velikom dugmetu; u kartici nema mjesta za nju.
        labela: widget.veliko ? 'Označi kao završeno' : 'Završen',
        istaknuta: true,
        veliko: widget.veliko,
        onTap: _uToku ? null : () => _zavrsen(termin),
      ),
      // `3n` crta „Pomjeri"; pomjeranje nema RPC putanju, pa je placeholder.
      if (widget.veliko)
        _Akcija(
          ikona: Icons.schedule,
          labela: 'Pomjeri',
          veliko: true,
          onTap: () => pokaziUskoro(context, 'Pomjeranje termina'),
        ),
      _Akcija(
        ikona: Icons.person_off_outlined,
        labela: 'Nije došao',
        veliko: widget.veliko,
        onTap: _uToku ? null : () => _nijeDosao(termin),
      ),
      _Akcija(
        ikona: Icons.event_busy_outlined,
        labela: 'Otkaži',
        destruktivna: true,
        veliko: widget.veliko,
        onTap: _uToku ? null : () => _otkazi(termin),
      ),
    ],
    _ => const [],
  };

  Future<void> _potvrdi(Appointment termin) => _izvrsi(
    () => ref.read(appointmentActionsProvider).potvrdi(termin.id),
    uspjeh: 'Termin je potvrđen.',
  );

  Future<void> _zavrsen(Appointment termin) => _izvrsi(
    () => ref.read(appointmentActionsProvider).zavrsen(termin.id),
    uspjeh: 'Termin je označen kao završen.',
  );

  /// Odbijanje i otkazivanje traže **obrazloženje**, jer ga klijent vidi.
  ///
  /// Polje nije obavezno: salon koji odbija zbog bolesti radnika nema šta objašnjavati u
  /// tri sata ujutro, a prisilno polje bi ga natjeralo da upiše tačku. Prazno se u bazi
  /// normalizuje u `null`.
  Future<void> _odbij(Appointment termin) async {
    final razlog = await _pitajZaRazlog(
      naslov: 'Odbij zahtjev',
      opis:
          'Klijent ${termin.customerName} će dobiti obavijest da termin nije prihvaćen.',
      potvrda: 'Odbij',
    );
    if (razlog == null) return;

    await _izvrsi(
      () =>
          ref.read(appointmentActionsProvider).odbij(termin.id, razlog: razlog),
      uspjeh: 'Zahtjev je odbijen.',
    );
  }

  Future<void> _otkazi(Appointment termin) async {
    final razlog = await _pitajZaRazlog(
      naslov: 'Otkaži termin',
      opis:
          'Termin je već potvrđen. ${termin.customerName} će dobiti obavijest o otkazivanju.',
      potvrda: 'Otkaži termin',
    );
    if (razlog == null) return;

    await _izvrsi(
      () => ref
          .read(appointmentActionsProvider)
          .otkazi(termin.id, razlog: razlog),
      uspjeh: 'Termin je otkazan.',
    );
  }

  Future<void> _nijeDosao(Appointment termin) async {
    final potvrdjeno = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klijent se nije pojavio?'),
        content: Text(
          '${termin.customerName} će biti zabilježen kao nedolazak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nije došao'),
          ),
        ],
      ),
    );
    if (potvrdjeno != true) return;

    await _izvrsi(
      () => ref.read(appointmentActionsProvider).nijeDosao(termin.id),
      uspjeh: 'Zabilježen nedolazak.',
    );
  }

  /// Vraća obrazloženje, ili `null` ako je korisnik odustao.
  ///
  /// **Prazan string i `null` nisu isto**: prazan znači „bez obrazloženja, ali izvrši",
  /// `null` znači „odustao sam". Da su isto, zatvaranje dijaloga tapom pored bi otkazalo
  /// termin.
  Future<String?> _pitajZaRazlog({
    required String naslov,
    required String opis,
    required String potvrda,
  }) => pitajZaRazlog(context, naslov: naslov, opis: opis, potvrda: potvrda);

  /// Zajedničko izvršavanje: zaključaj, pozovi, javi ishod.
  ///
  /// **Greška se prikazuje, ne guta.** Akcija koja tiho ne uradi ništa ostavlja vlasnika u
  /// uvjerenju da je termin potvrđen — a klijent i dalje čeka.
  Future<void> _izvrsi(
    Future<Appointment?> Function() poziv, {
    required String uspjeh,
  }) async {
    setState(() => _uToku = true);
    try {
      await poziv();
      if (!mounted) return;
      _poruka(uspjeh);
    } on ApiError catch (greska) {
      if (!mounted) return;
      _poruka(tekstGreskeAkcije(greska), greska: true);
    } finally {
      // `mounted` prije `setState`: lista se u međuvremenu osvježila i ovaj widget je
      // možda već zamijenjen novim.
      if (mounted) setState(() => _uToku = false);
    }
  }

  void _poruka(String tekst, {bool greska = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(tekst),
          // `error`, ne `errorContainer`: snackbar tekst dolazi iz teme i pisan je za
          // tamnu podlogu (`context.adminColors.ground` na `ink`). Na svijetlom `errorContainer`
          // tintu bi bio nevidljiv — 1,06:1.
          backgroundColor: greska ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }
}

/// Dijalog koji traži obrazloženje za odbijanje ili otkazivanje.
///
/// **Vlastiti widget, ne `builder` zatvoren nad kontrolerom iz `State`-a.** Prva verzija je
/// pravila `TextEditingController` prije `showDialog` i dispose-ovala ga u `finally`; taj
/// `finally` se izvrši čim `showDialog` vrati vrijednost, a dijalog je tada još na ekranu
/// jedan frame dok animacija zatvaranja traje — `TextField` se ponovo izgradi nad već
/// dispose-ovanim kontrolerom i baci „A TextEditingController was used after being disposed".
/// Ovako kontroler živi tačno koliko i widget koji ga koristi.
class _RazlogDijalog extends StatefulWidget {
  const _RazlogDijalog({
    required this.naslov,
    required this.opis,
    required this.potvrda,
  });

  final String naslov;
  final String opis;
  final String potvrda;

  @override
  State<_RazlogDijalog> createState() => _RazlogDijalogState();
}

class _RazlogDijalogState extends State<_RazlogDijalog> {
  final _kontroler = TextEditingController();

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.naslov),
      // `SingleChildScrollView` oko sadržaja: sa `maxLength` brojačem i tastaturom na malom
      // ekranu dijalog prelazi raspoloživu visinu, a `AlertDialog` je ne ograničava sam.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.opis),
            const SizedBox(height: 16),
            TextField(
              controller: _kontroler,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Razlog (nije obavezno)',
                hintText: 'npr. radnik na bolovanju',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // Bez argumenta → `null` → „odustao sam". Prazan string bi značio „izvrši bez
          // obrazloženja", pa bi tap na „Odustani" otkazao termin.
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_kontroler.text),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: Text(widget.potvrda),
        ),
      ],
    );
  }
}

/// Jedno dugme u traci akcija.
///
/// U kartici: ikona **i** tekst, nikad samo ikona — „✓" i „✕" jedno pored drugog se
/// razlikuju samo oblikom. Na velikoj traci (`3n`) ikone nema, jer tamo tekst stoji sam i
/// dovoljno je krupan.
///
/// Primarna radnja je koralna i **u verzalu** (`adminv2`); sporedna ostaje u rečenici.
class _Akcija extends StatelessWidget {
  const _Akcija({
    required this.ikona,
    required this.labela,
    required this.onTap,
    this.istaknuta = false,
    this.destruktivna = false,
    this.veliko = false,
  });

  final IconData ikona;
  final String labela;
  final VoidCallback? onTap;
  final bool istaknuta;
  final bool destruktivna;
  final bool veliko;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tekst = Theme.of(context).textTheme;

    if (istaknuta) {
      // `3n`: natpis velikog dugmeta je 16 px, u kartici 14.
      final stil = FilledButton.styleFrom(
        textStyle: veliko
            ? AdminText.actionLabel.copyWith(fontSize: 16)
            : AdminText.actionLabel,
        visualDensity: veliko ? null : VisualDensity.compact,
      );
      if (veliko) {
        return FilledButton(
          onPressed: onTap,
          style: stil,
          child: AdminVerzal(labela),
        );
      }
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(ikona, size: 18),
        label: AdminVerzal(labela),
        style: stil,
      );
    }

    final stil = OutlinedButton.styleFrom(
      textStyle: veliko
          ? tekst.labelLarge?.copyWith(fontSize: 16)
          : tekst.labelLarge,
      visualDensity: veliko ? null : VisualDensity.compact,
      foregroundColor: destruktivna ? boje.destructive : null,
      // `3n`: „Otkaži" nosi blijedi crveni obrub, ne sivi — boja teksta sama je premalo
      // za radnju koja se ne da vratiti.
      side: destruktivna && veliko
          ? BorderSide(
              color: boje.destructive.withValues(alpha: 0.3),
              width: AdminSize.hairline,
            )
          : null,
      padding: veliko
          ? const EdgeInsets.symmetric(horizontal: AdminSpacing.sm)
          : null,
    );

    if (veliko) {
      return OutlinedButton(
        onPressed: onTap,
        style: stil,
        child: Text(labela, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(ikona, size: 18),
      label: Text(labela),
      style: stil,
    );
  }
}
