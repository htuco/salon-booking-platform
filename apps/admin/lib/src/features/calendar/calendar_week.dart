part of 'calendar_day.dart';

// Sedmica kalendara (task 69, skica `prototype/adminv2/sedmica/`).
//
// **`part`, ne zaseban library, i to je namjerno.** Sedmica je sedam kolona istog oblika
// kao kolona dana: ista osa, isti neradni pojasevi, ista pauza, iste trake za preklapanje.
// Kao `part` koristi `_osa`, `_kolona` i `_uTrake` direktno; zaseban fajl bi ih morao
// ili otvoriti kao javni API ili prepisati, a prepisan raspored traka je mjesto gdje se dva
// prikaza istog dana tiho raziđu.

/// Ponedjeljak sedmice u kojoj je [dan], u ponoć.
///
/// Po kalendaru, ne po trajanju — isti razlog kao `KalendarDatumNotifier.pomjeri`:
/// `subtract(Duration(days: n))` preko promjene ljetnog vremena padne u 23:00 dana prije.
DateTime pocetakSedmice(DateTime dan) =>
    DateTime(dan.year, dan.month, dan.day - (dan.weekday - DateTime.monday));

/// Radnik koji je uz „Svi" van posla, cijeli dan ili dio dana — red u zaglavlju dana.
///
/// Postoji zato što kolona svih radnika crta **salonski** raspored: bez ovoga vlasnik iz
/// sedmice ne bi mogao pročitati da Emir u četvrtak ne radi, ni da je Vedad od 12 do 13
/// blokiran. Radnikova blokada se ne crta u koloni (tvrdila bi da je salon zatvoren), pa
/// se kaže ovdje.
class OdsutnostRadnika {
  const OdsutnostRadnika({required this.radnik, this.blokada});

  final Employee radnik;

  /// `null` = radnik taj dan ne radi uopšte (nema smjene ili je dan zatvoren).
  final BlockedSlot? blokada;

  bool get cijeliDan => blokada == null;

  /// `Emir ne radi`, ili `Vedad 12:00–13:00 · Doktor`.
  String get tekst {
    final blokada = this.blokada;
    if (blokada == null) return '${radnik.name} ne radi';
    return '${radnik.name} '
        '${vrijemeOse(blokada.startTime.minutesFromMidnight)}–'
        '${vrijemeOse(blokada.endTime.minutesFromMidnight)} · '
        '${blokadaNaslov(blokada)}';
  }
}

/// Jedan dan sedmice — jedna kolona sedmičnog prikaza.
///
/// [kolona] je ista [KolonaRadnika] kao u dnevnom prikazu, samo što ne pripada jednom
/// radniku nego **danu**: u njoj su termini svih radnika (ili samo filtriranog), u trakama.
class DanSedmice {
  const DanSedmice({
    required this.dan,
    required this.kolona,
    this.odsutni = const [],
  });

  final DateTime dan;
  final KolonaRadnika kolona;

  /// Ko je uz „Svi" van posla taj dan: prvo oni koji ne rade cijeli dan, pa blokade po
  /// vremenu. Prazno za filtriranog radnika (njegova smjena i blokade su već u koloni) i
  /// za dan kad salon ne radi (tada ne radi niko, i to kaže kolona).
  final List<OdsutnostRadnika> odsutni;

  /// Da li salon (ili filtrirani radnik) taj dan radi.
  bool get radi => kolona.radi;

  int get brojTermina => kolona.brojTermina;

  /// `09:00–20:00 · 6 termina`, ili `Ne radi` — isti tekst kao zaglavlje kolone dana.
  String get podnaslov => kolona.podnaslov;
}

/// Sedmica: zajednička osa i sedam dana, ponedjeljak–nedjelja.
class KalendarSedmica {
  const KalendarSedmica({
    required this.pocetak,
    required this.osa,
    required this.dani,
    this.radnici = const [],
    this.boje = const {},
  });

  /// Ponedjeljak, u ponoć.
  final DateTime pocetak;

  /// **Jedna osa za svih sedam kolona.** Kolone sa svojom osom ne bi stale u isti red:
  /// 10:00 u ponedjeljak i 10:00 u subotu moraju biti na istoj visini, inače se sedmica
  /// ne može čitati vodoravno.
  final KalendarOsa osa;

  /// Tačno sedam, ponedjeljak prvi.
  final List<DanSedmice> dani;

  /// Aktivni radnici, redom za čipove `Svi · Emir · …`. Neaktivni ne dobijaju čip, ali
  /// njihovi stari termini i dalje stoje u koloni.
  final List<Employee> radnici;

  /// `employees.id` → indeks u `AdminPalette.radnici`, i za neaktivne — v. [bojeRadnika].
  final Map<String, int> boje;

  /// Nedjelja, u ponoć.
  DateTime get kraj => dani.last.dan;

  int get brojTermina => dani.fold(0, (zbir, d) => zbir + d.brojTermina);

  /// Indeks današnjeg dana u [dani], ili `null` kad danas nije u ovoj sedmici.
  int? indeksDana(DateTime sada) {
    for (var i = 0; i < dani.length; i++) {
      final d = dani[i].dan;
      if (d.year == sada.year && d.month == sada.month && d.day == sada.day) {
        return i;
      }
    }
    return null;
  }

  /// Gdje na osi stoji „sada", ili `null` — isto pravilo kao [KalendarDan.yLinijeSada].
  /// Linija se crta samo u koloni [indeksDana].
  double? yLinijeSada(DateTime sada) {
    if (indeksDana(sada) == null) return null;
    final minuta = sada.hour * 60 + sada.minute;
    if (minuta < osa.pocetakMinuta || minuta > osa.krajMinuta) return null;
    return osa.yZa(minuta);
  }
}

/// Gradi sedmicu u kojoj je [dan].
///
/// [radnikId] je filter: `null` = svi radnici (vlasnik sa „Svi"), inače samo taj radnik —
/// i izbor vlasnika i radnik koji gleda svoj kalendar (task 47).
///
/// **Raspored je salonski za „Svi", radnikov za filtriranog.** Kolona dana sa svim
/// radnicima nema jednog radnika čija bi se smjena crtala, pa crta salon. Filtrirana kolona
/// crta smjenu tog radnika, uz salonski red kao rezervu (`workingHoursFor`).
///
/// **Radnikova blokada ulazi samo kad je taj radnik filtriran.** U koloni svih radnika ona
/// bi se nacrtala preko cijele širine i tvrdila da je salon zatvoren, a zatvoren je samo
/// jedan radnik. Salonska blokada ulazi uvijek. Uz „Svi" se radnikova blokada i njegov
/// slobodan dan kažu u zaglavlju — [DanSedmice.odsutni].
///
/// [radnici] daju čipove, boje i [DanSedmice.odsutni]; kolone ne zavise od njih, pa termin
/// obrisanog radnika ne nestaje.
///
/// [termini] i [blokade] smiju nositi i dane izvan sedmice; svaki dan uzima samo svoje.
KalendarSedmica izgradiSedmicu({
  required DateTime dan,
  required List<Employee> radnici,
  required List<Appointment> termini,
  required List<WorkingHour> radnoVrijeme,
  required List<BlockedSlot> blokade,
  String? radnikId,
}) {
  final pocetak = pocetakSedmice(dan);
  final dani = [
    for (var i = 0; i < 7; i++)
      DateTime(pocetak.year, pocetak.month, pocetak.day + i),
  ];

  LocalDate datum(DateTime d) => LocalDate(d.year, d.month, d.day);

  final rasporedi = [
    for (final d in dani)
      workingHoursFor(radnoVrijeme, dayOfWeek: d.weekday, employeeId: radnikId),
  ];
  final terminiDana = [
    for (final d in dani)
      termini
          .where(
            (t) =>
                t.date == datum(d) &&
                (radnikId == null || t.employeeId == radnikId),
          )
          .toList(growable: false),
  ];
  final blokadeDana = [
    for (final d in dani)
      blokade
          .where(
            (b) =>
                b.date == datum(d) &&
                (b.isSalonWide ||
                    (radnikId != null && b.employeeId == radnikId)),
          )
          .toList(growable: false),
  ];

  final osa = _osa(
    rasporedi: rasporedi,
    termini: [for (final t in terminiDana) ...t],
    blokade: [for (final b in blokadeDana) ...b],
  );

  final aktivni = [
    for (final r in radnici)
      if (r.isActive) r,
  ];

  List<OdsutnostRadnika> odsutniDana(int i) {
    final raspored = rasporedi[i];
    if (radnikId != null || raspored == null || raspored.isClosed) {
      return const [];
    }

    final d = dani[i];
    final cijeliDan = <OdsutnostRadnika>[];
    final djelimicno = <OdsutnostRadnika>[];
    for (final r in aktivni) {
      final smjena = workingHoursFor(
        radnoVrijeme,
        dayOfWeek: d.weekday,
        employeeId: r.id,
      );
      if (smjena == null || smjena.isClosed) {
        cijeliDan.add(OdsutnostRadnika(radnik: r));
        continue;
      }
      for (final b in blokade) {
        if (b.date == datum(d) && b.employeeId == r.id) {
          djelimicno.add(OdsutnostRadnika(radnik: r, blokada: b));
        }
      }
    }
    djelimicno.sort(
      (a, b) => a.blokada!.startTime.minutesFromMidnight.compareTo(
        b.blokada!.startTime.minutesFromMidnight,
      ),
    );
    return [...cijeliDan, ...djelimicno];
  }

  return KalendarSedmica(
    pocetak: pocetak,
    osa: osa,
    radnici: aktivni,
    boje: bojeRadnika([for (final r in radnici) r.id]),
    dani: [
      for (var i = 0; i < 7; i++)
        DanSedmice(
          dan: dani[i],
          kolona: _kolona(
            radnikId: radnikId,
            ime: '',
            raspored: rasporedi[i],
            osa: osa,
            termini: terminiDana[i],
            blokade: blokadeDana[i],
          ),
          odsutni: odsutniDana(i),
        ),
    ],
  );
}

/// Koliko boja ima `AdminPalette.radnici`. Model ne zna za temu, pa se jednakost drži
/// testom (`calendar_week_test.dart`), ne importom.
const int kBrojBojaRadnika = 8;

/// Dodjeljuje radnicima boje: `employees.id` → indeks u `AdminPalette.radnici`.
///
/// **Nasumično, ali stabilno.** Boju niko ne bira (odluka 2026-10-16), pa je izvor id
/// radnika: isti radnik ima istu boju na svakom uređaju, poslije odjave i poslije novog
/// builda. Prava slučajnost bi mu boju mijenjala pri svakom pokretanju, a vlasnik boju
/// pamti umjesto imena.
///
/// Dok ima slobodnih boja, dva radnika ne dijele boju: id koji padne na zauzetu ide na
/// sljedeću slobodnu. Ids se obrađuju sortirani, da redoslijed liste iz baze ne mijenja
/// ishod. Kad radnika ima više od [brojBoja], boje se ponavljaju po hešu.
///
/// Heš je ručni, a ne `String.hashCode`: taj Dart ne garantuje između VM-a i weba, a
/// admin se builda za oba.
Map<String, int> bojeRadnika(
  Iterable<String> ids, {
  int brojBoja = kBrojBojaRadnika,
}) {
  int hes(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      // Mod prost broj ispod 2^31: međurezultat ostaje ispod 2^53, pa web računa tačno.
      h = (h * 31 + c) % 2147483647;
    }
    return h;
  }

  final rezultat = <String, int>{};
  final zauzete = <int>{};
  for (final id in ids.toSet().toList()..sort()) {
    var boja = hes(id) % brojBoja;
    if (zauzete.length < brojBoja) {
      while (zauzete.contains(boja)) {
        boja = (boja + 1) % brojBoja;
      }
    }
    zauzete.add(boja);
    rezultat[id] = boja;
  }
  return rezultat;
}

/// Sedmica kao lista po danima — telefon (`7b`).
///
/// Svaki dan nosi svoje redove po vremenu, bez neradnih pojaseva (kao [redoviKolone]).
/// Salonska blokada je u koloni dana samo jednom, pa ovdje ne treba prepoznavanje po `id`
/// kao u [redoviDana].
List<(DanSedmice, List<StavkaKalendara>)> redoviSedmice(
  KalendarSedmica sedmica,
) => [for (final d in sedmica.dani) (d, redoviKolone(d.kolona))];
