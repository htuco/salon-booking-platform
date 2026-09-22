/// Brojke koje „Danas" pokazuje — **čista funkcija nad listom termina**, bez widgeta.
///
/// Odvojeno od ekrana da bi se moglo testirati bez `pumpWidget`: metrika koja pogrešno
/// broji izgleda na ekranu tačno kao metrika koja broji ispravno.
///
/// ## Kapacitet dolazi iz smjena
///
/// Do ADR-0020 su ovdje stajale tri kartice i traka bez procenta, uz obrazloženje da smjene
/// i `created_at` ne postoje. Obje tvrdnje su bile netačne: `working_hours` od init
/// migracije nosi red **po radniku** (sa pauzom), a `appointments.created_at` postoji od
/// prvog dana. Kapacitet je zato smjena radnika minus pauza — ne „otvoreno salona puta broj
/// ljudi", što bi brojalo i radnika koji danas ne radi.
library;

import 'package:core_api/core_api.dart' show workingHoursFor;
import 'package:core_domain/core_domain.dart';

/// Sažetak jednog dana.
class DashboardSazetak {
  const DashboardSazetak({
    required this.ukupno,
    required this.zavrseno,
    required this.predstoji,
    required this.otkazano,
    required this.prometDoSada,
    required this.prometPrognoza,
  });

  /// Termini dana koji **drže slot** — otkazani i nedolasci se ne broje u „14 termina".
  final int ukupno;

  final int zavrseno;

  /// Ono što tek dolazi: potvrđeno i na čekanju.
  final int predstoji;

  final int otkazano;

  /// Zbir cijena **završenih** termina. To je novac koji je salon danas stvarno naplatio.
  final double prometDoSada;

  /// Zbir cijena svih termina koji drže slot — završenih, potvrđenih i onih na čekanju.
  ///
  /// Canvas ga zove „prognoza" i to je tačna riječ: zahtjev na čekanju može biti odbijen, a
  /// potvrđen termin otkazan.
  final double prometPrognoza;

  /// Računa sažetak iz termina dana i cjenovnika.
  ///
  /// [cijene] su `serviceId → cijena`. Termin čija usluga nije u mapi ulazi u brojanje, ali
  /// ne u promet — usluga obrisana iz cjenovnika ne smije obrisati termin iz rasporeda.
  factory DashboardSazetak.izracunaj(
    List<Appointment> termini,
    Map<String, double> cijene,
  ) {
    var ukupno = 0;
    var zavrseno = 0;
    var predstoji = 0;
    var otkazano = 0;
    var doSada = 0.0;
    var prognoza = 0.0;

    for (final termin in termini) {
      final cijena = termin.servicePrice ?? cijene[termin.serviceId] ?? 0;

      switch (termin.status) {
        case AppointmentStatus.completed:
          ukupno++;
          zavrseno++;
          doSada += cijena;
          prognoza += cijena;
        case AppointmentStatus.confirmed:
        case AppointmentStatus.pending:
          ukupno++;
          predstoji++;
          prognoza += cijena;
        case AppointmentStatus.cancelled:
        case AppointmentStatus.noShow:
          // Nedolazak stoji uz otkazivanje: slot je prošao prazan. Razlika između to dvoje
          // je za izvještaj o klijentu, ne za brojku na dashboardu.
          otkazano++;
        case AppointmentStatus.unknown:
          ukupno++;
      }
    }

    return DashboardSazetak(
      ukupno: ukupno,
      zavrseno: zavrseno,
      predstoji: predstoji,
      otkazano: otkazano,
      prometDoSada: doSada,
      prometPrognoza: prognoza,
    );
  }
}

/// Da li se termin **broji u dan** — sve osim otkazanog i nedolaska.
///
/// Namjerno **nije** `status.blocksSlot`. Ono odgovara na pitanje availability enginea
/// („drži li ovaj red slot") i zato isključuje `completed`: završen termin slot više ne
/// drži. Ali on se u devet ujutro **desio**, i mora ući i u „14 termina" i u zauzetost
/// majstora. Prva verzija ovog ekrana je koristila `blocksSlot` i tiho gubila svaki
/// obavljen termin — brojka je izgledala uredno, samo je bila manja nego što je dan bio.
bool terminSeRacuna(Appointment termin) =>
    termin.status != AppointmentStatus.cancelled &&
    termin.status != AppointmentStatus.noShow;

/// Koliko je jedan radnik danas zauzet.
class ZauzetostRadnika {
  const ZauzetostRadnika({
    required this.radnikId,
    required this.ime,
    required this.termina,
    required this.minuta,
    this.kapacitetMinuta,
  });

  final String radnikId;
  final String ime;
  final int termina;

  /// Zbir trajanja termina koji se broje u dan, u minutama.
  final int minuta;

  /// Dužina današnje smjene bez pauze; `null` kad radnik danas nema smjenu.
  final int? kapacitetMinuta;

  /// `82` za 82% — zauzeto u odnosu na smjenu, odrezano na 100.
  ///
  /// `null` bez smjene: termin upisan radniku koji danas ne radi je greška u rasporedu, a
  /// procenat „∞" ili „0%" bi je sakrio. Tada ekran piše minute, kao prije.
  int? get procenat {
    final kapacitet = kapacitetMinuta;
    if (kapacitet == null || kapacitet <= 0) return null;
    return (minuta * 100 / kapacitet).round().clamp(0, 100);
  }
}

/// Zauzetost po radniku, najzauzetiji prvi — `3b`: „6 termina · 82%".
///
/// [smjene] daju kapacitet. Radnik sa smjenom a bez ijednog termina **ulazi u listu** sa
/// 0%: slobodan majstor je upravo ono što vlasnik u ovoj kartici traži. Bez [smjene] je
/// traka relativna (najzauzetiji je pun), kao prije ADR-0020.
///
/// [imena] su `employeeId → ime`. Termin bez radnika (`employee_id` je nullable — salon
/// pušta „bilo ko") se ne broji nikome; takav red se vidi u rasporedu, a ne u zauzetosti.
List<ZauzetostRadnika> zauzetostPoRadniku(
  List<Appointment> termini,
  Map<String, String> imena, {
  List<SmjenaDana> smjene = const [],
}) {
  final termina = <String, int>{
    for (final smjena in smjene) smjena.radnikId: 0,
  };
  final minuta = <String, int>{for (final smjena in smjene) smjena.radnikId: 0};
  final kapacitet = {
    for (final smjena in smjene) smjena.radnikId: smjena.minuta,
  };

  for (final termin in termini) {
    if (!terminSeRacuna(termin)) continue;
    final id = termin.employeeId;
    if (id == null) continue;

    termina[id] = (termina[id] ?? 0) + 1;
    minuta[id] = (minuta[id] ?? 0) + termin.durationMinutes;
  }

  final lista =
      [
        for (final id in termina.keys)
          ZauzetostRadnika(
            radnikId: id,
            ime: imena[id] ?? 'Radnik',
            termina: termina[id]!,
            minuta: minuta[id]!,
            kapacitetMinuta: kapacitet[id],
          ),
      ]..sort((a, b) {
        final poMinutama = b.minuta.compareTo(a.minuta);
        // Isti broj minuta se dalje razvrstava po imenu, da redoslijed ne zavisi od toga kojim
        // je redom baza vratila termine — lista koja se premeće pri svakom osvježavanju
        // izgleda kao da se podaci mijenjaju.
        return poMinutama != 0 ? poMinutama : a.ime.compareTo(b.ime);
      });

  return lista;
}

/// Smjena jednog radnika na jedan dan, u minutama od ponoći.
class SmjenaDana {
  const SmjenaDana({
    required this.radnikId,
    required this.od,
    required this.doMinute,
    this.pauzaOd,
    this.pauzaDo,
  });

  final String radnikId;
  final int od;
  final int doMinute;
  final int? pauzaOd;
  final int? pauzaDo;

  /// Radno vrijeme bez pauze.
  int get minuta {
    final pauza = switch ((pauzaOd, pauzaDo)) {
      (final int pocetak, final int kraj) => kraj - pocetak,
      _ => 0,
    };
    return doMinute - od - pauza;
  }
}

/// Ko danas radi i od kad do kad.
///
/// Pravilo je [workingHoursFor]: radnikov red nadjačava salonski, a bez ijednog salon taj
/// dan ne radi. Neradni dan (`is_closed`) nije smjena — i to je razlog zašto se broj „u
/// smjeni" ne smije čitati iz broja aktivnih radnika.
List<SmjenaDana> smjeneDana(
  List<WorkingHour> raspored,
  Iterable<String> radnici,
  int isoDan,
) => [
  for (final id in radnici)
    if (workingHoursFor(raspored, dayOfWeek: isoDan, employeeId: id)
        case final red? when !red.isClosed)
      SmjenaDana(
        radnikId: id,
        od: red.startTime.minutesFromMidnight,
        doMinute: red.endTime.minutesFromMidnight,
        pauzaOd: red.breakStartTime?.minutesFromMidnight,
        pauzaDo: red.breakEndTime?.minutesFromMidnight,
      ),
];

/// Neprekinut slobodan komad jednog radnika.
class Rupa {
  const Rupa({
    required this.radnikId,
    required this.od,
    required this.doMinute,
  });

  final String radnikId;
  final int od;
  final int doMinute;

  int get minuta => doMinute - od;
}

/// Slobodno vrijeme **od sada do kraja smjena** — kartica „Slobodno vrijeme".
class SlobodnoVrijeme {
  const SlobodnoVrijeme({required this.minuta, this.najvecaRupa});

  /// Zbir slobodnih minuta svih radnika u smjeni.
  final int minuta;

  /// `null` kad više nema nijednog slobodnog komada.
  final Rupa? najvecaRupa;
}

/// Koliko je danas još slobodno, i gdje je najveći komad.
///
/// **Od sada, ne od otvaranja.** Rupa u 10:00 koja je prošla nije vrijeme koje vlasnik
/// može popuniti; kartica odgovara na pitanje „ima li još mjesta danas".
///
/// Zauzeto je: pauza iz smjene, termin koji se broji u dan (plus njegov `buffer_minutes`,
/// koji i availability engine drži zauzetim), i blokada — radnikova ili salonska.
SlobodnoVrijeme slobodnoVrijeme({
  required List<SmjenaDana> smjene,
  required List<Appointment> termini,
  required int sadaMinuta,
  List<BlockedSlot> blokade = const [],
}) {
  var ukupno = 0;
  Rupa? najveca;

  for (final smjena in smjene) {
    final zauzeto = <(int, int)>[
      if ((smjena.pauzaOd, smjena.pauzaDo) case (
        final int pocetak,
        final int kraj,
      ))
        (pocetak, kraj),
      for (final termin in termini)
        if (termin.employeeId == smjena.radnikId && terminSeRacuna(termin))
          (
            termin.startTime.minutesFromMidnight,
            termin.endTime.minutesFromMidnight + termin.bufferMinutes,
          ),
      for (final blokada in blokade)
        if (blokada.employeeId == null || blokada.employeeId == smjena.radnikId)
          (
            blokada.startTime.minutesFromMidnight,
            blokada.endTime.minutesFromMidnight,
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    var kursor = smjena.od > sadaMinuta ? smjena.od : sadaMinuta;

    void rupaDo(int granica) {
      final kraj = granica < smjena.doMinute ? granica : smjena.doMinute;
      if (kraj <= kursor) return;
      ukupno += kraj - kursor;
      final kandidat = Rupa(
        radnikId: smjena.radnikId,
        od: kursor,
        doMinute: kraj,
      );
      if (najveca == null || kandidat.minuta > najveca!.minuta) {
        najveca = kandidat;
      }
    }

    for (final (pocetak, kraj) in zauzeto) {
      rupaDo(pocetak);
      if (kraj > kursor) kursor = kraj;
    }
    rupaDo(smjena.doMinute);
  }

  return SlobodnoVrijeme(minuta: ukupno, najvecaRupa: najveca);
}

/// Stanje salona sada — tačka i tekst desno od podnaslova u `3b`.
enum StanjeSalona { otvoreno, uskoroOtvara, zatvoreno }

/// „Otvoreno do 20:00" / „Otvara u 09:00" / „Danas zatvoreno" / „Zatvoreno".
///
/// Čita **salonski** red (`employee_id is null`), ne smjene: salon je otvoren i kad je
/// jedan majstor na pauzi.
({StanjeSalona stanje, String tekst}) otvorenoDo(
  List<WorkingHour> raspored,
  int isoDan,
  int sadaMinuta,
) {
  final red = workingHoursFor(raspored, dayOfWeek: isoDan);
  if (red == null || red.isClosed) {
    return (stanje: StanjeSalona.zatvoreno, tekst: 'Danas zatvoreno');
  }
  if (sadaMinuta < red.startTime.minutesFromMidnight) {
    return (
      stanje: StanjeSalona.uskoroOtvara,
      tekst: 'Otvara u ${red.startTime.format()}',
    );
  }
  if (sadaMinuta < red.endTime.minutesFromMidnight) {
    return (
      stanje: StanjeSalona.otvoreno,
      tekst: 'Otvoreno do ${red.endTime.format()}',
    );
  }
  return (stanje: StanjeSalona.zatvoreno, tekst: 'Zatvoreno');
}

/// `prije 26 min`, `prije 3 h`, `prije 2 dana` — koliko zahtjev čeka.
///
/// `null` bez [poslan]: red iz upita koji ne bira `created_at` nema starost, a „prije 0
/// min" bi tvrdilo da je upravo stigao.
String? prijeKoliko(DateTime? poslan, DateTime sada) {
  if (poslan == null) return null;
  final razlika = sada.difference(poslan.toLocal());
  if (razlika.inMinutes < 1) return 'upravo';
  if (razlika.inMinutes < 60) return 'prije ${razlika.inMinutes} min';
  if (razlika.inHours < 24) return 'prije ${razlika.inHours} h';
  final dana = razlika.inDays;
  return dana == 1 ? 'prije 1 dan' : 'prije $dana dana';
}

/// Najstariji zahtjev koji još čeka — „najstariji prije 26 min" u kartici „Čeka potvrdu".
DateTime? najstarijiZahtjev(List<Appointment> zahtjevi) {
  DateTime? najstariji;
  for (final zahtjev in zahtjevi) {
    final poslan = zahtjev.createdAt;
    if (zahtjev.status != AppointmentStatus.pending || poslan == null) continue;
    if (najstariji == null || poslan.isBefore(najstariji)) najstariji = poslan;
  }
  return najstariji;
}
