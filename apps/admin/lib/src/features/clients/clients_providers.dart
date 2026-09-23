import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter nad adresarom — karticama „Svi · Redovni · Neaktivni · Nedolasci" iz `3e`.
///
/// **Pragovi su ovdje, ne u bazi, i to je namjerno.** „Redovan" i „neaktivan" nisu
/// podatak nego način na koji salon gleda svoj adresar; `customers` nema kolonu koja ih
/// nosi. Držati ih u Dartu znači da se mogu promijeniti bez migracije — i, važnije, da se
/// **ne pretvore u pravilo**. Prag nedolazaka koji bi zabranjivao zakazivanje je pravilo
/// vertikale (`vertical.features.noShowTracking`) i task 35 ga izričito **ne uvodi**:
/// ovaj filter samo *pokazuje* ko ne dolazi, ne sprječava ga ni u čemu.
enum ClientsFilter {
  svi('Svi'),
  redovni('Redovni'),
  neaktivni('Neaktivni'),
  nedolasci('Nedolasci');

  const ClientsFilter(this.label);

  final String label;

  /// Klijent sa bar ovoliko dolazaka je „redovan".
  static const int pragRedovnog = 5;

  /// Bez dolaska ovoliko dana klijent je „neaktivan".
  static const int danaDoNeaktivnog = 180;

  /// Bar jedan nedolazak dovoljan je da klijent uđe u listu „Nedolasci".
  ///
  /// Nije prag nego filter: vlasnik traži *koga* da nazove prije termina, a ne koga da
  /// kazni. Prvi nedolazak je već razlog za taj poziv.
  static const int pragNedolaska = 1;

  bool prima(Customer klijent, DateTime sada) => switch (this) {
    ClientsFilter.svi => true,
    ClientsFilter.redovni => klijent.visitCount >= pragRedovnog,
    ClientsFilter.neaktivni => _neaktivan(klijent, sada),
    ClientsFilter.nedolasci => klijent.noShowCount >= pragNedolaska,
  };

  /// Klijent koji dugo nije bio, **ili nikad nije došao**.
  ///
  /// Drugi slučaj se lako ispusti: `lastVisitAt == null` nije „nema podatka" nego „nijedan
  /// termin nije održan". Upisan klijent koji se nikad nije pojavio je baš onaj kojeg
  /// lista „Neaktivni" treba pokazati, a poređenje sa `null`-om bi ga tiho izostavilo.
  static bool _neaktivan(Customer klijent, DateTime sada) {
    final zadnji = klijent.lastVisitAt;
    if (zadnji == null) return true;
    return sada.difference(zadnji).inDays >= danaDoNeaktivnog;
  }
}

/// Izabrana kartica filtera.
final clientsFilterProvider = NotifierProvider<_FilterNotifier, ClientsFilter>(
  _FilterNotifier.new,
);

class _FilterNotifier extends Notifier<ClientsFilter> {
  @override
  ClientsFilter build() => ClientsFilter.svi;

  void postavi(ClientsFilter filter) => state = filter;
}

/// Tekst iz polja za pretragu.
final clientsPretragaProvider = NotifierProvider<_PretragaNotifier, String>(
  _PretragaNotifier.new,
);

class _PretragaNotifier extends Notifier<String> {
  @override
  String build() => '';

  void postavi(String izraz) => state = izraz;
}

/// Adresar salona, filtriran karticom i pretragom.
///
/// **Pretraga ide u bazu, filter ostaje ovdje.** Ime i telefon su kolone, pa ih `ilike`
/// presijeca prije nego što PostgREST odreže odgovor na `max_rows` — pretraga filtrirana
/// u Dartu bi nad velikim adresarom tiho tražila samo po prvoj stranici. „Redovan" i
/// „neaktivan" nisu kolone, pa se računaju nad onim što je stiglo.
final adminKlijentiProvider = FutureProvider<List<Customer>>((ref) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return const [];

  final pretraga = ref.watch(clientsPretragaProvider);
  final filter = ref.watch(clientsFilterProvider);

  final redovi = await ref
      .watch(staffCustomerRepositoryProvider)
      .list(salonId: salonId, pretraga: pretraga);

  if (filter == ClientsFilter.svi) return redovi;

  final sada = DateTime.now();
  return redovi
      .where((klijent) => filter.prima(klijent, sada))
      .toList(growable: false);
});

/// `customers.id` klijenta otvorenog u profilu, ili `null` dok nijedan nije izabran.
///
/// Desktop `3e` drži profil uz listu, telefon `3o` ga otvara preko nje — ista vrijednost
/// nosi oba, pa se izbor ne gubi pri promjeni širine prozora.
final izabraniKlijentProvider = NotifierProvider<_IzborNotifier, String?>(
  _IzborNotifier.new,
);

class _IzborNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void izaberi(String? customerId) => state = customerId;
}

/// Jedan klijent iz baze, po `id`-u.
///
/// Čita se **nanovo**, a ne uzima iz već učitane liste: lista je filtrirana i odrezana na
/// `limit`, pa bi profil otvoren iz pretrage nestao čim se pretraga očisti. Uz to je ovo
/// ista adresa koja jednog dana treba raditi iz bookmarka.
final klijentProvider = FutureProvider.family<Customer?, String>((
  ref,
  customerId,
) async {
  final salonId = ref.watch(adminSalonIdProvider);
  if (salonId == null) return null;

  return ref
      .watch(staffCustomerRepositoryProvider)
      .byId(salonId: salonId, customerId: customerId);
});

/// Gornja granica istorije koju upit vraća (`StaffCustomerRepository.istorija`, `limit`).
///
/// Ekran je mora znati: brojač izračunat nad odrezanom listom bi tvrdio manje dolazaka
/// nego što ih je bilo. Kad lista dosegne granicu, v. [brojDolazaka].
const int kLimitIstorije = 50;

/// Istorija termina jednog klijenta, najskoriji termin prvi.
///
/// **Sadrži i buduće termine.** Upit ne filtrira po datumu — sortira `date desc`, pa su
/// zakazani termini baš na vrhu liste i granica [kLimitIstorije] ih ne odsiječe. Iz iste
/// liste se zato računa i [sljedeciTermin].
final klijentIstorijaProvider =
    FutureProvider.family<List<Appointment>, String>((ref, customerId) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return const [];

      return ref
          .watch(staffCustomerRepositoryProvider)
          .istorija(salonId: salonId, customerId: customerId);
    });

/// Najbliži termin koji klijent ima pred sobom, ili `null`.
///
/// Broji se samo termin koji **drži slot** (`pending`, `confirmed`) — otkazan termin u
/// budućnosti nije termin na koji klijent dolazi. Termin koji upravo traje (počeo, nije
/// završio) je i dalje „sljedeći": klijent je u stolici i salon to treba vidjeti.
///
/// Datum i vrijeme su zidno vrijeme salona (v. `LocalDate`), pa se porede sa lokalnim
/// `DateTime`-om uređaja — admin se koristi u salonu, u istoj zoni.
Appointment? sljedeciTermin(List<Appointment> istorija, DateTime sada) {
  Appointment? najblizi;
  DateTime? pocetakNajblizeg;

  for (final termin in istorija) {
    if (!termin.blocksSlot) continue;
    final d = termin.date;
    final kraj = DateTime(
      d.year,
      d.month,
      d.day,
      termin.endTime.hour,
      termin.endTime.minute,
    );
    if (!kraj.isAfter(sada)) continue;

    final pocetak = DateTime(
      d.year,
      d.month,
      d.day,
      termin.startTime.hour,
      termin.startTime.minute,
    );
    if (pocetakNajblizeg == null || pocetak.isBefore(pocetakNajblizeg)) {
      najblizi = termin;
      pocetakNajblizeg = pocetak;
    }
  }
  return najblizi;
}

/// Broj dolazaka (`completed`) i nedolazaka (`no_show`) iz istorije klijenta.
///
/// **Kad istorija dosegne [kLimitIstorije], lista je odrezana** i brojanje nad njom bi
/// dalo premalo. Tada se uzima veći od dva broja: izračunati, ili brojač iz reda
/// `customers` ([Customer.visitCount], [Customer.noShowCount]), koji broji sve termine.
({int dolasci, int nedolasci}) brojDolazaka(
  List<Appointment> istorija,
  Customer klijent,
) {
  var dolasci = 0;
  var nedolasci = 0;
  for (final termin in istorija) {
    if (termin.status == AppointmentStatus.completed) dolasci++;
    if (termin.status == AppointmentStatus.noShow) nedolasci++;
  }

  if (istorija.length >= kLimitIstorije) {
    if (klijent.visitCount > dolasci) dolasci = klijent.visitCount;
    if (klijent.noShowCount > nedolasci) nedolasci = klijent.noShowCount;
  }
  return (dolasci: dolasci, nedolasci: nedolasci);
}

/// Zbir cijena **održanih** termina — „Potrošeno" iz `3e`.
///
/// **Ekran ga više ne crta**: vlasnik proizvoda je tražio da se „KM ukupno" i kolona
/// „Potrošeno" sklone. Funkcija ostaje dok je `test/clients_screen_test.dart` koristi.
///
/// **Broji se samo `completed`.** Canvas crta jednu brojku bez objašnjenja, a zbir preko
/// svih termina bi u nju uračunao i otkazane i nedošle — vlasnik bi vidio novac koji nije
/// naplaćen. Otkazan termin nije prihod.
///
/// Cijena dolazi iz `appointments.service_price`, snapshot-a iz taska 32, ne iz današnjeg
/// cjenovnika: termin od prošle godine je plaćen po tadašnjoj cijeni, i poskupljenje
/// usluge ne smije unazad promijeniti koliko je neko potrošio.
///
/// `null` znači **„ne zna se"**, ne nula: stariji termin može nositi `service_price` bez
/// vrijednosti, a nula bi tvrdila da je usluga bila besplatna.
double? potroseno(List<Appointment> istorija) {
  var zbir = 0.0;
  var imaPodatka = false;

  for (final termin in istorija) {
    if (termin.status != AppointmentStatus.completed) continue;
    final cijena = termin.servicePrice;
    if (cijena == null) continue;
    zbir += cijena;
    imaPodatka = true;
  }

  return imaPodatka ? zbir : null;
}
