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

/// Istorija dolazaka jednog klijenta, najskoriji termin prvi.
final klijentIstorijaProvider =
    FutureProvider.family<List<Appointment>, String>((ref, customerId) async {
      final salonId = ref.watch(adminSalonIdProvider);
      if (salonId == null) return const [];

      return ref
          .watch(staffCustomerRepositoryProvider)
          .istorija(salonId: salonId, customerId: customerId);
    });

/// Zbir cijena **održanih** termina — „Potrošeno" iz `3e`.
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
