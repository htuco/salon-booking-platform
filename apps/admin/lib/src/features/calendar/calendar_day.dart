/// Dan kalendara kao podatak — **čista funkcija nad terminima, rasporedom i blokadama**.
///
/// Odvojeno od ekrana iz istog razloga kao `dashboard_summary.dart`: blok koji je na
/// pogrešnom mjestu na osi izgleda tačno kao blok koji je na pravom. Razlika se vidi tek
/// kad se uporedi sa satom sa strane, a to test radi pouzdanije od oka.
///
/// ## Dva pogleda, jedan model
///
/// Desktop (`3c`) crta **kolonu po radniku** sa vremenskom osom, telefon (`3l`) **listu po
/// vremenu** za jednog radnika. To nisu dva modela nego dva čitanja istog: [izgradiDan]
/// vraća kolone, a [redoviKolone] jednu od njih izravna u listu. Miješanje ta dva pogleda
/// je zamka zapisana u tasku 31 — `get_available_slots` vraća red po radniku, i svako
/// spajanje „po radniku" sa „po vremenu" daje ili duplikate ili izgubljene termine.
///
/// ## Vrijeme je uvijek `int` minuta od ponoći
///
/// Ne `DateTime` i ne [LocalTime]. Osa je linija od 0 do 1440 i sve na njoj je oduzimanje;
/// `DateTime` bi u tu aritmetiku uveo zonu i ljetno računanje vremena, kojih u rasporedu
/// salona nema (v. doc [LocalTime]).
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';

import '../dashboard/dashboard_summary.dart';

/// Minuta u danu. Gornja granica ose i jedini dozvoljen „kraj dana".
const int kMinutaUDanu = 24 * 60;

/// Visina jednog sata u pikselima — canvas `3c` crta satnu mrežu na 80 px.
const double kVisinaSata = 80;

/// Osa kad dan nema **ništa**: ni raspored, ni termin, ni blokadu.
///
/// Namjerno nije `09:00–17:00` iz baze. Te vrijednosti su default kolone `working_hours` i
/// stoje i u redu koji kaže `is_closed`, pa bi ih čitanje kao rasporeda pretvorilo
/// zatvoren dan u radni (v. doc [WorkingHour.isClosed]). Ovo je prozor za *gledanje*
/// praznog dana, ne tvrdnja o radnom vremenu.
const int kPodrazumijevanPocetak = 8 * 60;

/// Kraj podrazumijevanog prozora — v. [kPodrazumijevanPocetak].
const int kPodrazumijevanKraj = 20 * 60;

/// Šta stoji na osi.
enum VrstaStavke {
  /// Termin iz `appointments`.
  termin,

  /// Pauza unutar smjene — `working_hours.break_start_time`.
  pauza,

  /// Blokirano vrijeme — `blocked_slots`.
  blokada,

  /// Vrijeme van radnog vremena tog radnika, unutar prikazane ose.
  neradno,

  /// Rupa između zauzeća jednog radnika. Postoji **samo** u listi jednog radnika —
  /// v. [redoviKolone].
  slobodno,
}

/// Jedno zauzeće na osi jedne kolone.
///
/// [traka] i [brojTraka] postoje zbog preklapanja. Dva termina istog radnika u isto vrijeme
/// **jesu** moguća i bez greške u availability engineu: otkazan termin ostaje u listi
/// (`StaffAppointmentRepository.forDay`), pa novi termin u istom slotu legitimno stoji
/// preko njega. Bez traka bi gornji prekrio donji i raspored bi izgledao rjeđe nego što
/// jeste.
class StavkaKalendara {
  const StavkaKalendara({
    required this.vrsta,
    required this.odMinuta,
    required this.doMinuta,
    this.termin,
    this.tekst,
    this.traka = 0,
    this.brojTraka = 1,
    this.cijeliSalon = false,
  });

  final VrstaStavke vrsta;

  /// Minuta od ponoći, uključivo.
  final int odMinuta;

  /// Minuta od ponoći, isključivo. Uvijek `> odMinuta` — v. `_raspon`.
  final int doMinuta;

  /// Postavljen samo za [VrstaStavke.termin].
  final Appointment? termin;

  /// Razlog blokade ili tekst neradnog pojasa.
  final String? tekst;

  /// Koja traka unutar kolone, kad se termini preklapaju.
  final int traka;

  /// Koliko traka kolona ima na mjestu ove stavke.
  final int brojTraka;

  /// Blokada koja vrijedi za **cijeli salon**, ne za jednog radnika.
  ///
  /// Postoji zbog mobilne liste sa „Svi": ista salonska blokada stoji u svakoj koloni i
  /// tamo se mora ispisati jednom. Prepoznavanje po vremenu i tekstu ne bi bilo dovoljno —
  /// dvije radnikove blokade u isto vrijeme sa istim razlogom su dvije blokade.
  final bool cijeliSalon;

  int get trajanjeMinuta => doMinuta - odMinuta;

  /// Da li je ovo pozadinski pojas (pauza, blokada, neradno), a ne termin.
  ///
  /// Pozadina se crta **preko cijele širine kolone i ispod termina**: pauza koja bi ušla u
  /// trake pomjerila bi termin u stranu, a pauza i termin u isto vrijeme su sudar koji
  /// vlasnik mora vidjeti kao sudar.
  bool get jePozadina =>
      vrsta == VrstaStavke.pauza ||
      vrsta == VrstaStavke.blokada ||
      vrsta == VrstaStavke.neradno;

  StavkaKalendara uTraci(int traka, int brojTraka) => StavkaKalendara(
    vrsta: vrsta,
    odMinuta: odMinuta,
    doMinuta: doMinuta,
    termin: termin,
    tekst: tekst,
    traka: traka,
    brojTraka: brojTraka,
    cijeliSalon: cijeliSalon,
  );
}

/// Vremenska osa dana — od punog sata do punog sata.
class KalendarOsa {
  const KalendarOsa({required this.pocetakMinuta, required this.krajMinuta});

  /// Puni sat, uključivo.
  final int pocetakMinuta;

  /// Puni sat, isključivo.
  final int krajMinuta;

  int get trajanjeMinuta => krajMinuta - pocetakMinuta;

  /// Visina cijele ose u pikselima.
  double get visina => trajanjeMinuta / 60 * kVisinaSata;

  /// Puni sati na osi, kao minute od ponoći. [krajMinuta] je isključen.
  List<int> get sati => [
    for (var m = pocetakMinuta; m < krajMinuta; m += 60) m,
  ];

  /// Piksela od vrha ose do [minuta].
  ///
  /// Vrijednost izvan ose se **ne odsijeca ovdje** — odsijecanje radi `_presjek` prije nego
  /// što stavka uopšte nastane. `clamp` na ovom mjestu bi sakrio grešku u građenju dana.
  double yZa(int minuta) => (minuta - pocetakMinuta) / 60 * kVisinaSata;

  /// Visina bloka od [odMinuta] do [doMinuta].
  double visinaZa(int odMinuta, int doMinuta) =>
      (doMinuta - odMinuta) / 60 * kVisinaSata;
}

/// Jedna kolona `3c` — jedan radnik i sve što mu stoji u danu.
class KolonaRadnika {
  const KolonaRadnika({
    required this.radnikId,
    required this.ime,
    required this.stavke,
    this.raspored,
  });

  /// `null` za kolonu „Bez radnika" — v. [kBezRadnikaIme].
  final String? radnikId;

  final String ime;

  /// Raspored koji za tog radnika stvarno vrijedi (radnikov red nadjačava salonski).
  /// `null` kad salon taj dan nema nijedan red — tada je cijeli dan neradan.
  final WorkingHour? raspored;

  /// Pozadinski pojasevi i termini, po vremenu početka.
  final List<StavkaKalendara> stavke;

  Iterable<StavkaKalendara> get termini =>
      stavke.where((s) => s.vrsta == VrstaStavke.termin);

  Iterable<StavkaKalendara> get pozadina => stavke.where((s) => s.jePozadina);

  /// Termini koji se broje u dan — otkazani i nedolasci ne ulaze u „6 termina".
  ///
  /// Isto pravilo kao `terminSeRacuna` na dashboardu, i iz istog razloga: `blocksSlot` bi
  /// izbacilo završen termin, koji se ujutro desio.
  int get brojTermina =>
      termini.where((s) => s.termin != null && _seRacuna(s.termin!)).length;

  /// Da li radnik taj dan uopšte radi.
  bool get radi => raspored != null && !raspored!.isClosed;

  /// `09:00–20:00 · 6 termina`, ili `Ne radi` — podnaslov zaglavlja kolone iz `3c`.
  String get podnaslov {
    final raspored = this.raspored;
    if (raspored == null || raspored.isClosed) return 'Ne radi';

    final smjena =
        '${vrijemeOse(raspored.startTime.minutesFromMidnight)}–'
        '${vrijemeOse(raspored.endTime.minutesFromMidnight)}';
    return '$smjena · ${terminaTekst(brojTermina)}';
  }
}

/// Ime kolone u koju idu termini bez radnika.
///
/// `appointments.employee_id` je nullable — salon smije pustiti „bilo ko". Takav termin
/// **nema svoju kolonu u canvasu**, a ne smije ni nestati: raspored koji tiho izostavi
/// termin je gori od rasporeda sa kolonom viška.
const String kBezRadnikaIme = 'Bez radnika';

/// Cijeli dan: osa i kolone.
class KalendarDan {
  const KalendarDan({
    required this.dan,
    required this.osa,
    required this.kolone,
  });

  final DateTime dan;
  final KalendarOsa osa;
  final List<KolonaRadnika> kolone;

  bool get prazan => kolone.every((k) => k.termini.isEmpty);

  /// Ukupno termina koji se broje u dan, kroz sve kolone.
  int get brojTermina =>
      kolone.fold(0, (zbir, kolona) => zbir + kolona.brojTermina);

  /// Minuta „sada", ako je [dan] današnji i ako sat pada unutar ose.
  ///
  /// `null` znači **ne crtaj liniju** — za jučer, sutra, i za danas prije otvaranja ili
  /// poslije zatvaranja. Linija zalijepljena za rub ose bi tvrdila da je sad devet, a
  /// zapravo je pola osam.
  double? yLinijeSada(DateTime sada) {
    if (dan.year != sada.year ||
        dan.month != sada.month ||
        dan.day != sada.day) {
      return null;
    }
    final minuta = sada.hour * 60 + sada.minute;
    if (minuta < osa.pocetakMinuta || minuta > osa.krajMinuta) return null;
    return osa.yZa(minuta);
  }
}

/// Gradi dan iz onoga što baza vrati.
///
/// [radnici] daju kolone i njihov redoslijed — kalendar pokazuje **sve** radnike salona, i
/// one bez ijednog termina. Radnik bez termina je informacija („Emir je danas slobodan"), a
/// kolona koja se pojavljuje i nestaje zavisno od rasporeda je nečitljiva.
///
/// Termin čiji radnik nije u [radnici] — obrisan radnik, ili lista koja se još učitava —
/// ide u istu kolonu kao termin bez radnika, iz istog razloga: ne smije nestati.
KalendarDan izgradiDan({
  required DateTime dan,
  required List<Employee> radnici,
  required List<Appointment> termini,
  required List<WorkingHour> radnoVrijeme,
  required List<BlockedSlot> blokade,
}) {
  final danBezVremena = DateTime(dan.year, dan.month, dan.day);
  final rasporedi = <String, WorkingHour?>{
    for (final radnik in radnici)
      radnik.id: workingHoursFor(
        radnoVrijeme,
        dayOfWeek: danBezVremena.weekday,
        employeeId: radnik.id,
      ),
  };
  final salonski = workingHoursFor(
    radnoVrijeme,
    dayOfWeek: danBezVremena.weekday,
  );

  final osa = _osa(
    rasporedi: [...rasporedi.values, salonski],
    termini: termini,
    blokade: blokade,
  );

  final poznati = {for (final radnik in radnici) radnik.id};
  final niciji = termini
      .where((t) => t.employeeId == null || !poznati.contains(t.employeeId))
      .toList(growable: false);

  return KalendarDan(
    dan: danBezVremena,
    osa: osa,
    kolone: [
      for (final radnik in radnici)
        _kolona(
          radnikId: radnik.id,
          ime: radnik.name,
          raspored: rasporedi[radnik.id],
          osa: osa,
          termini: termini.where((t) => t.employeeId == radnik.id),
          blokade: blokade.where(
            (b) => b.isSalonWide || b.employeeId == radnik.id,
          ),
        ),
      if (niciji.isNotEmpty)
        _kolona(
          radnikId: null,
          ime: kBezRadnikaIme,
          // Salonski raspored, jer termin bez radnika drži vrijeme salona, ne ničije.
          raspored: salonski,
          osa: osa,
          termini: niciji,
          blokade: blokade.where((b) => b.isSalonWide),
        ),
    ],
  );
}

/// Kolona izravnata u listu po vremenu — mobilni `3l`.
///
/// **Slobodne rupe postoje samo ovdje, i samo za jednog radnika.** „Slobodno 80 min" preko
/// cijelog salona bi bila ista izmišljotina kao kartica „Slobodno vrijeme" izostavljena iz
/// `3b` (v. `dashboard_summary.dart`): kad u smjeni radi troje, slobodno nije „otvoreno
/// minus zauzeto". Rupa u koloni jednog radnika je, naprotiv, tačno ono što jeste.
///
/// Rupa kraća od [najkracaRupa] se ne crta — između dva termina uvijek ostane po koja
/// minuta, a red „Slobodno 5 min" je šum, ne ponuda.
List<StavkaKalendara> redoviKolone(
  KolonaRadnika kolona, {
  int najkracaRupa = 15,
}) {
  final zauzeca =
      kolona.stavke
          .where((s) => s.vrsta != VrstaStavke.neradno)
          .toList(growable: false)
        ..sort((a, b) => a.odMinuta.compareTo(b.odMinuta));

  final raspored = kolona.raspored;
  if (raspored == null || raspored.isClosed) return zauzeca;

  final redovi = <StavkaKalendara>[];
  var kursor = raspored.startTime.minutesFromMidnight;
  final krajSmjene = raspored.endTime.minutesFromMidnight;

  for (final stavka in zauzeca) {
    // Rupa se **odsijeca na kraj smjene**. Termin upisan poslije zatvaranja (ručni unos to
    // smije) bi inače rastegao „slobodno" preko zatvorenog salona — red koji nudi da se
    // zakaže u vrijeme kad se ne radi. Našao snimak: subota se zatvara u 14:00, a termin u
    // 14:20 je prijavio „Slobodno 2h 20m".
    final krajRupe = stavka.odMinuta < krajSmjene
        ? stavka.odMinuta
        : krajSmjene;
    if (krajRupe - kursor >= najkracaRupa && kursor < krajSmjene) {
      redovi.add(
        StavkaKalendara(
          vrsta: VrstaStavke.slobodno,
          odMinuta: kursor,
          doMinuta: krajRupe,
        ),
      );
    }
    redovi.add(stavka);
    // `max`, ne dodjela: termin koji je cijeli unutar prethodnog (preklapanje) bi inače
    // vratio kursor unazad i otvorio lažnu rupu.
    if (stavka.doMinuta > kursor) kursor = stavka.doMinuta;
  }

  if (krajSmjene - kursor >= najkracaRupa) {
    redovi.add(
      StavkaKalendara(
        vrsta: VrstaStavke.slobodno,
        odMinuta: kursor,
        doMinuta: krajSmjene,
      ),
    );
  }

  return redovi;
}

/// Jedan red mobilne liste — stavka i, kad lista miješa radnike, čiji je.
class RedListe {
  const RedListe({required this.stavka, this.radnik});

  final StavkaKalendara stavka;

  /// Ime radnika. `null` u listi jednog radnika, gdje bi ga svaki red ponavljao.
  final String? radnik;
}

/// Cijeli dan kao jedna lista — mobilni `3l` sa izabranim „Svi".
///
/// **Bez slobodnih rupa.** Rupa u koloni jednog radnika je podatak; „slobodno" preko
/// cijelog salona nije, jer kad u smjeni radi troje, slobodno nije „otvoreno minus
/// zauzeto". Isti razlog zbog kojeg kartica „Slobodno vrijeme" nije ušla u `3b`
/// (`dashboard_summary.dart`).
///
/// **Salonska blokada se pojavljuje jednom**, iako stoji u svakoj koloni. Pet puta
/// ispisana „Inventura" bi izgledalo kao pet blokada.
List<RedListe> redoviDana(KalendarDan dan) {
  final redovi = <RedListe>[];
  final vidjeneSalonske = <String>{};

  for (final kolona in dan.kolone) {
    for (final stavka in kolona.stavke) {
      if (stavka.vrsta == VrstaStavke.neradno) continue;

      // Pauza je po radniku i smije se ponoviti; salonska blokada stoji u svakoj koloni i
      // ispisuje se jednom, bez imena radnika — ona nije ničija.
      if (stavka.cijeliSalon) {
        if (!vidjeneSalonske.add(
          '${stavka.odMinuta}-${stavka.doMinuta}-${stavka.tekst}',
        )) {
          continue;
        }
        redovi.add(RedListe(stavka: stavka));
        continue;
      }

      redovi.add(RedListe(stavka: stavka, radnik: kolona.ime));
    }
  }

  return redovi..sort((a, b) {
    final poVremenu = a.stavka.odMinuta.compareTo(b.stavka.odMinuta);
    return poVremenu != 0
        ? poVremenu
        : (a.radnik ?? '').compareTo(b.radnik ?? '');
  });
}

/// Osa koja pokriva **sve** što dan sadrži, zaokružena na pune sate.
///
/// Termin van radnog vremena nije greška nego stvarnost (ručni unos ga smije upisati), i
/// mora se vidjeti. Osa koja staje na radnom vremenu bi ga gurnula van vidnog polja, a
/// jedini trag bi bio da brojka „6 termina" ne odgovara onome što se broji na ekranu.
KalendarOsa _osa({
  required List<WorkingHour?> rasporedi,
  required List<Appointment> termini,
  required List<BlockedSlot> blokade,
}) {
  var pocetak = kMinutaUDanu;
  var kraj = 0;

  void uzmi(int od, int do_) {
    if (od < pocetak) pocetak = od;
    if (do_ > kraj) kraj = do_;
  }

  for (final raspored in rasporedi) {
    // `isClosed` red nosi default `09:00–17:00` u kolonama koje ne znače ništa — v. doc
    // `WorkingHour.isClosed`. Čitanje tih vrijednosti bi zatvorenoj nedjelji nacrtalo
    // radno vrijeme.
    if (raspored == null || raspored.isClosed) continue;
    uzmi(
      raspored.startTime.minutesFromMidnight,
      raspored.endTime.minutesFromMidnight,
    );
  }
  for (final termin in termini) {
    final raspon = _raspon(
      termin.startTime.minutesFromMidnight,
      termin.endTime.minutesFromMidnight,
    );
    uzmi(raspon.$1, raspon.$2);
  }
  for (final blokada in blokade) {
    final raspon = _raspon(
      blokada.startTime.minutesFromMidnight,
      blokada.endTime.minutesFromMidnight,
    );
    uzmi(raspon.$1, raspon.$2);
  }

  if (kraj <= pocetak) {
    return const KalendarOsa(
      pocetakMinuta: kPodrazumijevanPocetak,
      krajMinuta: kPodrazumijevanKraj,
    );
  }

  // Pun sat dolje, pun sat gore: mreža `3c` je satna, a blok koji počinje u 09:20 na osi
  // koja počinje u 09:20 stoji uz sam vrh i izgleda kao da je odsječen.
  final zaokruzenPocetak = ((pocetak ~/ 60) * 60).clamp(0, kMinutaUDanu - 60);
  final zaokruzenKraj = (((kraj + 59) ~/ 60) * 60).clamp(
    zaokruzenPocetak + 60,
    kMinutaUDanu,
  );

  return KalendarOsa(
    pocetakMinuta: zaokruzenPocetak,
    krajMinuta: zaokruzenKraj,
  );
}

/// Jedna kolona: pozadinski pojasevi, pa termini razvrstani u trake.
KolonaRadnika _kolona({
  required String? radnikId,
  required String ime,
  required WorkingHour? raspored,
  required KalendarOsa osa,
  required Iterable<Appointment> termini,
  required Iterable<BlockedSlot> blokade,
}) {
  final stavke = <StavkaKalendara>[
    ..._neradniPojasevi(raspored: raspored, osa: osa),
    ..._pauza(raspored: raspored, osa: osa),
    for (final blokada in blokade)
      ?_pojas(
        vrsta: VrstaStavke.blokada,
        odMinuta: blokada.startTime.minutesFromMidnight,
        doMinuta: blokada.endTime.minutesFromMidnight,
        osa: osa,
        tekst: blokadaNaslov(blokada),
        cijeliSalon: blokada.isSalonWide,
      ),
    for (final termin in termini)
      ?_pojas(
        vrsta: VrstaStavke.termin,
        odMinuta: termin.startTime.minutesFromMidnight,
        doMinuta: termin.endTime.minutesFromMidnight,
        osa: osa,
        termin: termin,
      ),
  ];

  return KolonaRadnika(
    radnikId: radnikId,
    ime: ime,
    raspored: raspored,
    stavke: _uTrake(stavke),
  );
}

/// Naslov blokade. Prazan `reason` je dozvoljen u bazi, pa mora imati zamjenu.
String blokadaNaslov(BlockedSlot blokada) {
  final razlog = blokada.reason?.trim();
  return razlog == null || razlog.isEmpty ? 'Blokirano' : razlog;
}

/// Pojasevi „ne radi" prije i poslije smjene, unutar prikazane ose.
List<StavkaKalendara> _neradniPojasevi({
  required WorkingHour? raspored,
  required KalendarOsa osa,
}) {
  // Nema reda za taj dan ili je dan zatvoren: cijela kolona je neradna. Ovo je i jedini
  // način da se **neradni dan vidi**, umjesto da izgleda kao dan bez termina.
  if (raspored == null || raspored.isClosed) {
    return [
      StavkaKalendara(
        vrsta: VrstaStavke.neradno,
        odMinuta: osa.pocetakMinuta,
        doMinuta: osa.krajMinuta,
        tekst: 'Ne radi',
      ),
    ];
  }

  final pocetak = raspored.startTime.minutesFromMidnight;
  final kraj = raspored.endTime.minutesFromMidnight;

  return [
    if (pocetak > osa.pocetakMinuta)
      StavkaKalendara(
        vrsta: VrstaStavke.neradno,
        odMinuta: osa.pocetakMinuta,
        doMinuta: pocetak,
        tekst: 'Ne radi do ${vrijemeOse(pocetak)}',
      ),
    if (kraj < osa.krajMinuta)
      StavkaKalendara(
        vrsta: VrstaStavke.neradno,
        odMinuta: kraj,
        doMinuta: osa.krajMinuta,
        tekst: 'Ne radi od ${vrijemeOse(kraj)}',
      ),
  ];
}

List<StavkaKalendara> _pauza({
  required WorkingHour? raspored,
  required KalendarOsa osa,
}) {
  if (raspored == null || raspored.isClosed || !raspored.hasBreak) {
    return const [];
  }

  final pojas = _pojas(
    vrsta: VrstaStavke.pauza,
    odMinuta: raspored.breakStartTime!.minutesFromMidnight,
    doMinuta: raspored.breakEndTime!.minutesFromMidnight,
    osa: osa,
    tekst: 'Pauza',
  );
  return pojas == null ? const [] : [pojas];
}

/// Jedna stavka, odsječena na osu. `null` kad je potpuno izvan nje.
StavkaKalendara? _pojas({
  required VrstaStavke vrsta,
  required int odMinuta,
  required int doMinuta,
  required KalendarOsa osa,
  Appointment? termin,
  String? tekst,
  bool cijeliSalon = false,
}) {
  final presjek = _presjek(_raspon(odMinuta, doMinuta), osa);
  if (presjek == null) return null;

  return StavkaKalendara(
    vrsta: vrsta,
    odMinuta: presjek.$1,
    doMinuta: presjek.$2,
    termin: termin,
    tekst: tekst,
    cijeliSalon: cijeliSalon,
  );
}

/// Raspon koji je uvijek pozitivan i uvijek unutar jednog dana.
///
/// **Prekoračenje preko ponoći.** `appointments` i `blocked_slots` nose
/// `check(end_time > start_time)`, pa red koji završava sutra u bazi ne može nastati — ali
/// `end_time` jeste `time`, a Postgresov `time` poznaje `24:00:00`, dok `LocalTime` zna
/// sate 0–23. Takav red bi ovdje stigao kao kraj koji nije veći od početka i, bez ovoga,
/// dao blok **negativne visine** — Flutter ga iscrta kao grešku layouta ili ga ne iscrta
/// uopšte, a u oba slučaja termin nestane sa rasporeda. Kraj koji nije poslije početka
/// zato znači „do kraja dana".
(int, int) _raspon(int odMinuta, int doMinuta) {
  final od = odMinuta.clamp(0, kMinutaUDanu);
  final do_ = doMinuta <= od ? kMinutaUDanu : doMinuta.clamp(0, kMinutaUDanu);
  return (od, do_);
}

/// Presjek raspona sa osom, ili `null` ako se ne dodiruju.
(int, int)? _presjek((int, int) raspon, KalendarOsa osa) {
  final od = raspon.$1 < osa.pocetakMinuta ? osa.pocetakMinuta : raspon.$1;
  final do_ = raspon.$2 > osa.krajMinuta ? osa.krajMinuta : raspon.$2;
  return do_ <= od ? null : (od, do_);
}

int _poVremenu(StavkaKalendara a, StavkaKalendara b) {
  final poPocetku = a.odMinuta.compareTo(b.odMinuta);
  if (poPocetku != 0) return poPocetku;
  // Duži prvi, da traka 0 nosi onaj koji pokriva više dana — inače se kratak termin nađe
  // lijevo od dugog koji ga sadrži, pa izgleda kao da je dugi počeo kasnije.
  return b.trajanjeMinuta.compareTo(a.trajanjeMinuta);
}

/// Razvrstava termine koji se preklapaju u trake.
///
/// Pozadina ostaje van traka (v. [StavkaKalendara.jePozadina]). Algoritam je uobičajen
/// „koliko traka treba u grupi koja se dodiruje": grupa se zatvara kad naiđe termin koji
/// počinje poslije kraja svih prethodnih, i svi u njoj dobiju **isti** [StavkaKalendara.brojTraka],
/// da susjedne trake budu jednako široke.
List<StavkaKalendara> _uTrake(List<StavkaKalendara> stavke) {
  final rezultat = stavke.where((s) => s.jePozadina).toList();
  final termini = stavke.where((s) => !s.jePozadina).toList()..sort(_poVremenu);

  // Indeks u `grupa` → traka koju je ta stavka dobila. Lokalno, jer isti dan ima više
  // kolona i svaka broji svoje trake.
  final grupa = <StavkaKalendara>[];
  final trakaStavke = <int>[];
  final krajTrake = <int>[];
  var krajGrupe = -1;

  void zatvoriGrupu() {
    if (grupa.isEmpty) return;
    for (var i = 0; i < grupa.length; i++) {
      rezultat.add(grupa[i].uTraci(trakaStavke[i], krajTrake.length));
    }
    grupa.clear();
    trakaStavke.clear();
    krajTrake.clear();
    krajGrupe = -1;
  }

  for (final stavka in termini) {
    if (stavka.odMinuta >= krajGrupe) zatvoriGrupu();

    var traka = krajTrake.indexWhere((kraj) => kraj <= stavka.odMinuta);
    if (traka == -1) {
      krajTrake.add(stavka.doMinuta);
      traka = krajTrake.length - 1;
    } else {
      krajTrake[traka] = stavka.doMinuta;
    }

    grupa.add(stavka);
    trakaStavke.add(traka);
    if (stavka.doMinuta > krajGrupe) krajGrupe = stavka.doMinuta;
  }
  zatvoriGrupu();

  return rezultat..sort(_poVremenu);
}

bool _seRacuna(Appointment termin) =>
    termin.status != AppointmentStatus.cancelled &&
    termin.status != AppointmentStatus.noShow;

/// `09:00`, iz minuta od ponoći. 1440 se piše kao `24:00` — kraj dana, ne ponoć sljedećeg.
String vrijemeOse(int minuta) {
  final sat = minuta ~/ 60;
  final min = minuta % 60;
  return '${sat.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}
