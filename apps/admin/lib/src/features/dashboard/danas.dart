/// Šta Danas ekran (`6a`–`6m`) računa iz termina — **čiste funkcije**, bez widgeta.
///
/// Uz `dashboard_summary.dart`, koji računa zauzetost, smjene i rupe. Ovdje je ono što je
/// redizajn dodao: redoslijed zahtjeva, „Sljedeći", termine bez oznake i stavke rasporeda
/// sa linijom „Sad". Odvojeno iz istog razloga: blok koji pogrešno broji izgleda na ekranu
/// isto kao blok koji broji tačno.
///
/// Sve funkcije primaju `sada` kao parametar. `DateTime.now()` u funkciji bi značio test
/// koji prolazi samo u određeno doba dana.
library;

import 'package:core_api/core_api.dart' show workingHoursFor;
import 'package:core_domain/core_domain.dart';

import '../appointments/appointment_card.dart' show terminUToku;
import 'dashboard_summary.dart';

/// Minute od ponoći.
int minutaDana(DateTime sada) => sada.hour * 60 + sada.minute;

bool _istiDan(LocalDate dan, DateTime sada) =>
    dan.year == sada.year && dan.month == sada.month && dan.day == sada.day;

/// Zahtjevi po **vremenu termina**, danas prije sutra — ne po tome koliko čekaju.
///
/// Handoff je tražio „najstariji prvi". Zahtjev za danas u 18:00 koji čeka sat i po je
/// ipak hitniji od onog za sutra koji čeka dva: prvi ističe prije nego što salon stigne
/// odgovoriti. Starost ostaje na redu („čeka 1 h 21 min") i u zaglavlju bloka.
List<Appointment> zahtjeviPoTerminu(List<Appointment> zahtjevi) =>
    [...zahtjevi]..sort((a, b) {
      final poDanu = a.date.compareTo(b.date);
      if (poDanu != 0) return poDanu;
      return a.startTime.minutesFromMidnight.compareTo(
        b.startTime.minutesFromMidnight,
      );
    });

/// Prvi potvrđen termin koji tek počinje — kartica „Sljedeći".
///
/// Zahtjev na čekanju nije „sljedeći": klijent možda neće ni doći ako salon ne odgovori.
Appointment? sljedeciTermin(List<Appointment> danas, DateTime sada) {
  final minuta = minutaDana(sada);
  Appointment? najblizi;
  for (final termin in danas) {
    if (termin.status != AppointmentStatus.confirmed) continue;
    if (!_istiDan(termin.date, sada)) continue;
    final pocetak = termin.startTime.minutesFromMidnight;
    if (pocetak <= minuta) continue;
    if (najblizi == null || pocetak < najblizi.startTime.minutesFromMidnight) {
      najblizi = termin;
    }
  }
  return najblizi;
}

/// Termini koji upravo traju, po početku.
List<Appointment> uTokuSada(List<Appointment> danas, DateTime sada) => [
  for (final termin in danas)
    if (terminUToku(termin, sada)) termin,
]..sort(_poPocetku);

/// Potvrđeni termini kojima je vrijeme prošlo — „Ime — je li došao?".
///
/// Status u bazi im je i dalje `confirmed`: salon nije rekao ni da su završeni ni da
/// klijent nije došao, pa ih dan ne smije tiho brojati ni kao jedno ni kao drugo.
List<Appointment> bezOznake(List<Appointment> danas, DateTime sada) {
  final minuta = minutaDana(sada);
  return [
    for (final termin in danas)
      if (termin.status == AppointmentStatus.confirmed &&
          _istiDan(termin.date, sada) &&
          termin.endTime.minutesFromMidnight <= minuta)
        termin,
  ]..sort(_poPocetku);
}

/// Da li je termin prošao — u rasporedu je stišan na pola.
bool terminProsao(Appointment termin, DateTime sada) =>
    termin.endTime.minutesFromMidnight <= minutaDana(sada);

int _poPocetku(Appointment a, Appointment b) =>
    a.startTime.minutesFromMidnight.compareTo(b.startTime.minutesFromMidnight);

// ---------------------------------------------------------------------------
// Raspored dana
// ---------------------------------------------------------------------------

/// Jedan red u „Ostatak dana" / „Moj dan".
sealed class StavkaDana {
  const StavkaDana(this.od);

  /// Minute od ponoći — po njima se stavke ređaju.
  final int od;
}

class TerminStavka extends StavkaDana {
  TerminStavka(this.termin) : super(termin.startTime.minutesFromMidnight);

  final Appointment termin;
}

/// Linija „Sad 13:12".
class SadStavka extends StavkaDana {
  const SadStavka(super.od);
}

/// Slobodan komad radnikove smjene, od sada nadalje (`6d`: „Slobodno · 40 min").
class SlobodnoStavka extends StavkaDana {
  const SlobodnoStavka(super.od, this.doMinute);

  final int doMinute;
  int get minuta => doMinute - od;
}

/// Pauza iz smjene (`6d`: „Pauza · 30 min").
class PauzaStavka extends StavkaDana {
  const PauzaStavka(super.od, this.doMinute);

  final int doMinute;
  int get minuta => doMinute - od;
}

/// Blokirano vrijeme — salonsko ili radnikovo.
class BlokadaStavka extends StavkaDana {
  BlokadaStavka(this.blokada) : super(blokada.startTime.minutesFromMidnight);

  final BlockedSlot blokada;
}

/// Najkraća rupa koja dobija svoj red. Pet minuta između dva termina nije „slobodno" —
/// to je vrijeme da se počisti stolica.
const int kNajkracaRupaMinuta = 15;

/// Stavke dana po vremenu, sa linijom „Sad" na svom mjestu.
///
/// [smjena] je radnikova (`6d`/`6e`): tada se crtaju i slobodni komadi i pauza, **od sada
/// nadalje** — rupa u 10:00 koja je prošla nije vrijeme koje se može popuniti. Vlasnik
/// gleda sve radnike odjednom, pa mu rupe po radniku ne stanu u jednu vremensku liniju;
/// on ih dobija kad filtrira jednog (v. ekran).
///
/// Linija „Sad" se ne crta kad je dan prošao ili još nije počeo: tada bi stajala iznad
/// prvog ili ispod zadnjeg reda i ništa ne bi dijelila.
List<StavkaDana> stavkeDana({
  required List<Appointment> termini,
  required DateTime sada,
  List<BlockedSlot> blokade = const [],
  SmjenaDana? smjena,
}) {
  final minuta = minutaDana(sada);
  final stavke = <StavkaDana>[
    for (final termin in termini) TerminStavka(termin),
    for (final blokada in blokade) BlokadaStavka(blokada),
  ];

  if (smjena != null) {
    final zauzeto = <(int, int)>[
      for (final termin in termini)
        if (terminSeRacuna(termin))
          (
            termin.startTime.minutesFromMidnight,
            termin.endTime.minutesFromMidnight + termin.bufferMinutes,
          ),
      for (final blokada in blokade)
        (
          blokada.startTime.minutesFromMidnight,
          blokada.endTime.minutesFromMidnight,
        ),
      if ((smjena.pauzaOd, smjena.pauzaDo) case (
        final int pocetak,
        final int kraj,
      ))
        (pocetak, kraj),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    var kursor = smjena.od > minuta ? smjena.od : minuta;
    void rupaDo(int granica) {
      final kraj = granica < smjena.doMinute ? granica : smjena.doMinute;
      if (kraj - kursor >= kNajkracaRupaMinuta) {
        stavke.add(SlobodnoStavka(kursor, kraj));
      }
    }

    for (final (pocetak, kraj) in zauzeto) {
      if (pocetak > kursor) rupaDo(pocetak);
      if (kraj > kursor) kursor = kraj;
    }
    rupaDo(smjena.doMinute);

    if ((smjena.pauzaOd, smjena.pauzaDo)
        case (final int pocetak, final int kraj) when kraj > minuta) {
      final od = pocetak > minuta ? pocetak : minuta;
      stavke.add(PauzaStavka(od, kraj));
    }
  }

  stavke.sort((a, b) {
    final poVremenu = a.od.compareTo(b.od);
    if (poVremenu != 0) return poVremenu;
    // Termin i rupa koji počinju u isto vrijeme: termin prvi, jer je on podatak, a rupa
    // je ono što ostaje oko njega.
    return _rang(a).compareTo(_rang(b));
  });

  final imaRanijih = stavke.any((s) => s.od <= minuta);
  final imaKasnijih = stavke.any((s) => s.od > minuta);
  if (imaRanijih && imaKasnijih) {
    final indeks = stavke.indexWhere((s) => s.od > minuta);
    stavke.insert(indeks, SadStavka(minuta));
  }
  return stavke;
}

int _rang(StavkaDana stavka) => switch (stavka) {
  TerminStavka() => 0,
  BlokadaStavka() => 1,
  PauzaStavka() => 2,
  SlobodnoStavka() => 3,
  SadStavka() => 4,
};

/// Šta panel `6b` kaže o zahtjevu prije nego što ga vlasnik potvrdi.
///
/// **Ovo je savjet, ne provjera.** Odluku donosi baza (`appointments_no_overlap`); panel
/// samo kaže ono što ekran već zna iz današnjih termina, da vlasnik ne potvrdi naslijepo.
/// Zahtjev za drugi dan nema provjere — ekran ima samo današnje termine, a „slobodno" bez
/// podatka bi bila tvrdnja koju niko nije provjerio.
sealed class ProvjeraTermina {
  const ProvjeraTermina();
}

/// Termin je slobodan; [prije] i [poslije] su susjedi istog radnika.
class SlobodanTermin extends ProvjeraTermina {
  const SlobodanTermin({this.prije, this.poslije});

  final Appointment? prije;
  final Appointment? poslije;
}

/// Termin pada preko drugog termina ili pauze.
class ZauzetTermin extends ProvjeraTermina {
  const ZauzetTermin({this.sa, this.pauza = false});

  final Appointment? sa;
  final bool pauza;
}

/// `null` kad provjera nema smisla: drugi dan, ili termin bez radnika („bilo ko").
ProvjeraTermina? provjeriZahtjev(
  Appointment zahtjev,
  List<Appointment> danas,
  DateTime sada, {
  SmjenaDana? smjena,
}) {
  if (!_istiDan(zahtjev.date, sada) || zahtjev.employeeId == null) return null;
  final od = zahtjev.startTime.minutesFromMidnight;
  final kraj = zahtjev.endTime.minutesFromMidnight;

  if ((smjena?.pauzaOd, smjena?.pauzaDo)
      case (final int pocetak, final int krajPauze)
      when od < krajPauze && kraj > pocetak) {
    return const ZauzetTermin(pauza: true);
  }

  Appointment? prije;
  Appointment? poslije;
  final kolege = [
    for (final t in danas)
      if (t.id != zahtjev.id &&
          t.employeeId == zahtjev.employeeId &&
          terminSeRacuna(t) &&
          t.status != AppointmentStatus.completed)
        t,
  ]..sort(_poPocetku);
  for (final t in kolege) {
    final tOd = t.startTime.minutesFromMidnight;
    final tKraj = t.endTime.minutesFromMidnight + t.bufferMinutes;
    // Samo potvrđen termin zauzima slot sigurno; drugi zahtjev u isto vrijeme je
    // izbor koji vlasnik pravi sada, pa se pokazuje kao susjed, ne kao sudar.
    if (t.status == AppointmentStatus.confirmed && od < tKraj && kraj > tOd) {
      return ZauzetTermin(sa: t);
    }
    if (tKraj <= od) prije = t;
    if (tOd >= kraj && poslije == null) poslije = t;
  }
  return SlobodanTermin(prije: prije, poslije: poslije);
}

/// Koliko prošlih termina ostaje vidljivo iznad „Još N ranijih termina".
const int kVidljivihRanijih = 2;

// ---------------------------------------------------------------------------
// Brojke
// ---------------------------------------------------------------------------

/// Brojke iz kartice `6a`: naplaćeno, prognoza, termini, nedolasci i otkazi.
class BrojkeDana {
  const BrojkeDana({
    required this.naplaceno,
    required this.zavrsenih,
    required this.prognoza,
    required this.naCekanjuIznos,
    required this.termina,
    required this.nijeDoslo,
    required this.otkazano,
  });

  /// Σ cijena završenih.
  final double naplaceno;
  final int zavrsenih;

  /// Σ cijena završenih, potvrđenih i onih na čekanju — svih koji drže slot.
  final double prognoza;

  /// Dio prognoze koji još nije siguran: zahtjevi na čekanju.
  final double naCekanjuIznos;

  /// Završeni, potvrđeni i na čekanju.
  final int termina;
  final int nijeDoslo;
  final int otkazano;

  factory BrojkeDana.izracunaj(
    List<Appointment> termini,
    Map<String, double> cijene,
  ) {
    var naplaceno = 0.0;
    var zavrsenih = 0;
    var prognoza = 0.0;
    var naCekanju = 0.0;
    var termina = 0;
    var nijeDoslo = 0;
    var otkazano = 0;

    for (final termin in termini) {
      final cijena = termin.servicePrice ?? cijene[termin.serviceId] ?? 0;
      switch (termin.status) {
        case AppointmentStatus.completed:
          naplaceno += cijena;
          zavrsenih++;
          prognoza += cijena;
          termina++;
        case AppointmentStatus.confirmed:
          prognoza += cijena;
          termina++;
        case AppointmentStatus.pending:
          prognoza += cijena;
          naCekanju += cijena;
          termina++;
        case AppointmentStatus.noShow:
          nijeDoslo++;
        case AppointmentStatus.cancelled:
          otkazano++;
        case AppointmentStatus.unknown:
          termina++;
      }
    }

    return BrojkeDana(
      naplaceno: naplaceno,
      zavrsenih: zavrsenih,
      prognoza: prognoza,
      naCekanjuIznos: naCekanju,
      termina: termina,
      nijeDoslo: nijeDoslo,
      otkazano: otkazano,
    );
  }
}

/// Prvi dan poslije [danas] u kojem salon radi — `6h`.
///
/// `null` kad salon ne radi nijedan dan u sedmici: to je salon bez rasporeda, i „sljedeći
/// radni dan" bi bio izmišljen.
({DateTime dan, LocalTime otvara})? sljedeciRadniDan(
  List<WorkingHour> raspored,
  DateTime danas,
) {
  for (var i = 1; i <= 7; i++) {
    final dan = DateTime(danas.year, danas.month, danas.day + i);
    final red = workingHoursFor(raspored, dayOfWeek: dan.weekday);
    if (red != null && !red.isClosed) return (dan: dan, otvara: red.startTime);
  }
  return null;
}

/// Da li salon danas radi — salonski red, ne smjene.
bool salonRadi(List<WorkingHour> raspored, DateTime dan) {
  final red = workingHoursFor(raspored, dayOfWeek: dan.weekday);
  return red != null && !red.isClosed;
}

// ---------------------------------------------------------------------------
// Tekst
// ---------------------------------------------------------------------------

/// `26 min`, `1 h 40 min`, `3 h`, `2 dana`.
String trajanjeCekanja(Duration koliko) {
  final minuta = koliko.inMinutes;
  if (minuta < 1) return 'manje od minute';
  if (minuta < 60) return '$minuta min';
  if (koliko.inHours < 24) {
    final ostatak = minuta % 60;
    return ostatak == 0
        ? '${koliko.inHours} h'
        : '${koliko.inHours} h $ostatak min';
  }
  final dana = koliko.inDays;
  return dana == 1 ? '1 dan' : '$dana dana';
}

/// `čeka 26 min` — `null` kad red nema `created_at`.
String? cekaKoliko(DateTime? poslan, DateTime sada) => poslan == null
    ? null
    : 'čeka ${trajanjeCekanja(sada.difference(poslan.toLocal()))}';

/// `za 18 min`, `za 1 h 18 min`.
String zaKoliko(Appointment termin, DateTime sada) {
  final razlika = termin.startTime.minutesFromMidnight - minutaDana(sada);
  return 'za ${trajanjeCekanja(Duration(minutes: razlika))}';
}

/// `danas`, `sutra`, `srijeda`, a dalje od sedmice `24.05.`.
String danZahtjeva(LocalDate dan, DateTime sada) {
  final razlika = DateTime(
    dan.year,
    dan.month,
    dan.day,
  ).difference(DateTime(sada.year, sada.month, sada.day)).inDays;
  return switch (razlika) {
    0 => 'danas',
    1 => 'sutra',
    > 1 && < 7 => _daniMalo[DateTime(dan.year, dan.month, dan.day).weekday - 1],
    _ =>
      '${dan.day.toString().padLeft(2, '0')}.'
          '${dan.month.toString().padLeft(2, '0')}.',
  };
}

const _daniMalo = [
  'ponedjeljak',
  'utorak',
  'srijeda',
  'četvrtak',
  'petak',
  'subota',
  'nedjelja',
];

/// Minute od ponoći kao `17:20`.
String hhmm(int minuta) =>
    '${(minuta ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuta % 60).toString().padLeft(2, '0')}';

/// „1 zahtjev", „3 zahtjeva", „12 zahtjeva".
String zahtjevaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return '$broj zahtjeva';
  return broj % 10 == 1 ? '$broj zahtjev' : '$broj zahtjeva';
}

/// „Još 1 raniji termin", „Još 3 ranija termina", „Još 5 ranijih termina".
String josRanijih(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) {
    return 'Još $broj ranijih termina';
  }
  if (zadnja == 1) return 'Još $broj raniji termin';
  if (zadnja >= 2 && zadnja <= 4) return 'Još $broj ranija termina';
  return 'Još $broj ranijih termina';
}

/// „3 završena termina", „1 završen termin".
String zavrsenihTekst(int broj) {
  final zadnjeDvije = broj % 100;
  final zadnja = broj % 10;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return '$broj završenih termina';
  if (zadnja == 1) return '$broj završen termin';
  if (zadnja >= 2 && zadnja <= 4) return '$broj završena termina';
  return '$broj završenih termina';
}

/// Prvo ime — „Emir" iz „Emir Barucija".
String prvoIme(String punoIme) {
  final dijelovi = punoIme.trim().split(RegExp(r'\s+'));
  return dijelovi.isEmpty || dijelovi.first.isEmpty ? punoIme : dijelovi.first;
}
