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

/// Jedan dan sedmice — jedna kolona sedmičnog prikaza.
///
/// [kolona] je ista [KolonaRadnika] kao u dnevnom prikazu, samo što ne pripada jednom
/// radniku nego **danu**: u njoj su termini svih radnika (ili samo filtriranog), u trakama.
class DanSedmice {
  const DanSedmice({required this.dan, required this.kolona});

  final DateTime dan;
  final KolonaRadnika kolona;

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
  });

  /// Ponedjeljak, u ponoć.
  final DateTime pocetak;

  /// **Jedna osa za svih sedam kolona.** Kolone sa svojom osom ne bi stale u isti red:
  /// 10:00 u ponedjeljak i 10:00 u subotu moraju biti na istoj visini, inače se sedmica
  /// ne može čitati vodoravno.
  final KalendarOsa osa;

  /// Tačno sedam, ponedjeljak prvi.
  final List<DanSedmice> dani;

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
/// jedan radnik. Salonska blokada ulazi uvijek.
///
/// [termini] i [blokade] smiju nositi i dane izvan sedmice; svaki dan uzima samo svoje.
KalendarSedmica izgradiSedmicu({
  required DateTime dan,
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

  return KalendarSedmica(
    pocetak: pocetak,
    osa: osa,
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
        ),
    ],
  );
}

/// Sedmica kao lista po danima — telefon (`7b`).
///
/// Svaki dan nosi svoje redove po vremenu, bez neradnih pojaseva (kao [redoviKolone]).
/// Salonska blokada je u koloni dana samo jednom, pa ovdje ne treba prepoznavanje po `id`
/// kao u [redoviDana].
List<(DanSedmice, List<StavkaKalendara>)> redoviSedmice(
  KalendarSedmica sedmica,
) => [for (final d in sedmica.dani) (d, redoviKolone(d.kolona))];
