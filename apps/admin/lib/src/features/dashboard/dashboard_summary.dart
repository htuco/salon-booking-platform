/// Brojke koje „Danas" pokazuje — **čista funkcija nad listom termina**, bez widgeta.
///
/// Odvojeno od ekrana da bi se moglo testirati bez `pumpWidget`: metrika koja pogrešno
/// broji izgleda na ekranu tačno kao metrika koja broji ispravno.
///
/// ## Šta canvas traži, a ovdje ne postoji
///
/// `3b` crta četiri kartice; ovdje ih ima **tri**. Izostavljena je „Slobodno vrijeme
/// (2h 40m · najveća rupa 17:20–19:20)", jer bi bila izmišljena: slobodno vrijeme salona
/// nije „otvoreno minus zauzeto" kad u smjeni radi troje ljudi, a smjene radnika dobijaju
/// svoj ekran tek u tasku 33. Broj koji izgleda tačno, a računa se po pogrešnom modelu, je
/// gori od kartice koje nema — vlasnik po njemu planira dan.
///
/// Iz istog razloga „Čeka potvrdu" nema podnaslov „najstariji prije 26 min": `appointments`
/// nema `created_at` kolonu, pa se starost zahtjeva **ne može** izračunati.
library;

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
      final cijena = cijene[termin.serviceId] ?? 0;

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
  });

  final String radnikId;
  final String ime;
  final int termina;

  /// Zbir trajanja termina koji se broje u dan, u minutama.
  final int minuta;
}

/// Zauzetost po radniku, najzauzetiji prvi.
///
/// **Bez procenta, za razliku od canvasa.** `3b` crta „6 termina · 82%" i traku te dužine;
/// procenat traži kapacitet, tj. smjenu radnika, a smjene dolaze tek u tasku 33. Ovdje je
/// mjera **relativna**: traka najzauzetijeg je puna, ostale su u odnosu na nju. Ta traka
/// odgovara na pitanje „ko je danas najopterećeniji", što je ono zbog čega vlasnik u nju i
/// gleda, a ne tvrdi koliko je kapaciteta iskorišteno.
///
/// [imena] su `employeeId → ime`. Termin bez radnika (`employee_id` je nullable — salon
/// pušta „bilo ko") se ne broji nikome; takav red se vidi u rasporedu, a ne u zauzetosti.
List<ZauzetostRadnika> zauzetostPoRadniku(
  List<Appointment> termini,
  Map<String, String> imena,
) {
  final termina = <String, int>{};
  final minuta = <String, int>{};

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

/// `2h 40m`, `45m`, `0m` — trajanje kako ga canvas piše.
String trajanjeKratko(int minuta) {
  final sati = minuta ~/ 60;
  final ostatak = minuta % 60;
  if (sati == 0) return '${ostatak}m';
  if (ostatak == 0) return '${sati}h';
  return '${sati}h ${ostatak}m';
}

/// Iznos u konvertibilnim markama, bez decimala kad ih nema.
///
/// Cijene u seedu su cijeli brojevi (`15 KM`), ali kolona je `numeric` i salon smije
/// upisati `12.50`. Zaokruživanje bi u izvještaju o prometu bilo tiha greška.
String iznosKm(double iznos) {
  final zaokruzen = iznos.roundToDouble();
  final tekst = (iznos - zaokruzen).abs() < 0.005
      ? zaokruzen.toStringAsFixed(0)
      : iznos.toStringAsFixed(2);
  return '$tekst KM';
}

/// `1 termin`, `2 termina`, `14 termina` — bosanski plural po zadnjoj cifri.
///
/// Izuzetak za 11–14 nije kozmetika: po samoj zadnjoj cifri bi „21 termin" bilo tačno, a
/// „11 termin" ne bi. Stoji ovdje, a ne u ekranu, jer isti broj piše i „Danas" i zaglavlje
/// kolone u kalendaru (`3c`); dvije kopije znače da se jedna popravi, a druga ne.
String terminaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return '$broj termina';
  return broj % 10 == 1 ? '$broj termin' : '$broj termina';
}
