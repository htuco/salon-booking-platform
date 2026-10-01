/// Terminologija koju vertikala (i, iznad nje, pojedini salon) nameće aplikaciji.
///
/// Svaki string koji se razlikuje između frizera, beauty salona i ordinacije živi ovdje —
/// nikad u `.dart` fajlu ekrana. Razlog nije stil nego distribucija: string u ekranu se ne
/// može promijeniti bez novog store submissiona, a ovaj se mijenja `update`-om jednog reda.
///
/// Oblik mora ostati identičan `vertical_packs.terminology` JSONB-u iz
/// `supabase/migrations/20260910090000_init_schema.sql`. Tabela svih vrijednosti po
/// vertikali: `docs/05-vertical-packs.md` §3.
class VerticalTerms {
  const VerticalTerms({
    required this.businessSingular,
    required this.customerSingular,
    required this.customerPlural,
    required this.serviceSingular,
    required this.servicePlural,
    this.serviceAccusative = 'uslugu',
    required this.staffSingular,
    required this.staffPlural,
    required this.appointmentSingular,
    required this.bookCta,
    required this.noteLabel,
    required this.myAppointments,
    required this.priceLabel,
    required this.durationLabel,
  });

  /// Vrijednosti koje se koriste kad ih baza ne pošalje. Namjerno su `generic` iz
  /// `docs/05 §3`, a ne prazni stringovi: app starija od baze mora prikazati smislen
  /// tekst, a prazan `Text('')` je bug koji se vidi tek na ekranu korisnika.
  static const VerticalTerms fallback = VerticalTerms(
    businessSingular: 'Firma',
    customerSingular: 'Klijent',
    customerPlural: 'Klijenti',
    serviceSingular: 'Usluga',
    servicePlural: 'Usluge',
    staffSingular: 'Radnik',
    staffPlural: 'Naš tim',
    appointmentSingular: 'Termin',
    bookCta: 'Zakaži termin',
    noteLabel: 'Napomena',
    myAppointments: 'Moji termini',
    priceLabel: 'Cijena',
    durationLabel: 'Trajanje',
  );

  /// "Barbershop" · "Salon" · "Ordinacija"
  final String businessSingular;

  /// "Klijent" · "Klijentica" · "Pacijent" — rod je dio proizvoda, v. `docs/05 §3`.
  final String customerSingular;
  final String customerPlural;

  /// "Usluga" · "Tretman" · "Pregled"
  final String serviceSingular;
  final String servicePlural;

  /// Usluga u akuzativu, malim slovom: "uslugu" · "tretman" · "terapiju". Naslov prvog
  /// koraka je „Izaberite …"; bez ovog ključa bi masaža pisala „Izaberite uslugu"
  /// (`prototype/masaza/`, ADR-0026). Nema default-a u packu barbera ni beautyja, pa oni
  /// ostaju na „uslugu" — barber je 1:1 sa handoffom.
  final String serviceAccusative;

  /// "Barber" · "Stilistica" · "Doktor"
  final String staffSingular;
  final String staffPlural;

  /// "Termin" · "Pregled"
  final String appointmentSingular;

  /// Tekst na glavnom dugmetu: "Zakaži termin" · "Rezerviši termin" · "Zakaži pregled".
  final String bookCta;

  /// "Napomena" · "Razlog dolaska"
  final String noteLabel;
  final String myAppointments;
  final String priceLabel;
  final String durationLabel;

  /// Čita terminologiju iz JSONB mape, uz [fallback] za svaki ključ koji nedostaje.
  ///
  /// Nedostajući ključ **nije** greška: baza smije dodati vertikalu ili ključ prije nego
  /// što izađe nova verzija app-e, a app iz storea mora nastaviti raditi. Isto vrijedi za
  /// vrijednost pogrešnog tipa — uzima se fallback umjesto `CastError`-a na ekranu.
  factory VerticalTerms.fromJson(Map<String, dynamic> json) {
    String read(String key, String fallbackValue) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : fallbackValue;
    }

    return VerticalTerms(
      businessSingular: read('businessSingular', fallback.businessSingular),
      customerSingular: read('customerSingular', fallback.customerSingular),
      customerPlural: read('customerPlural', fallback.customerPlural),
      serviceSingular: read('serviceSingular', fallback.serviceSingular),
      servicePlural: read('servicePlural', fallback.servicePlural),
      serviceAccusative: read('serviceAccusative', fallback.serviceAccusative),
      staffSingular: read('staffSingular', fallback.staffSingular),
      staffPlural: read('staffPlural', fallback.staffPlural),
      appointmentSingular: read(
        'appointmentSingular',
        fallback.appointmentSingular,
      ),
      bookCta: read('bookCta', fallback.bookCta),
      noteLabel: read('noteLabel', fallback.noteLabel),
      myAppointments: read('myAppointments', fallback.myAppointments),
      priceLabel: read('priceLabel', fallback.priceLabel),
      durationLabel: read('durationLabel', fallback.durationLabel),
    );
  }

  /// Sloji `salons.terminology_override` **preko** vertikalnog default-a, ključ po ključ.
  ///
  /// Ovo je razlog zašto override nije obična zamjena objekta: beauty salon koji želi samo
  /// "Klijentica" umjesto "Klijent" šalje jedan ključ i mora zadržati ostalih dvanaest.
  /// Zamjena cijelog objekta bi mu ostatak terminologije vratila na generic.
  VerticalTerms mergeOverride(Map<String, dynamic>? override) {
    if (override == null || override.isEmpty) return this;
    return VerticalTerms.fromJson({...toJson(), ...override});
  }

  Map<String, dynamic> toJson() => {
    'businessSingular': businessSingular,
    'customerSingular': customerSingular,
    'customerPlural': customerPlural,
    'serviceSingular': serviceSingular,
    'servicePlural': servicePlural,
    'serviceAccusative': serviceAccusative,
    'staffSingular': staffSingular,
    'staffPlural': staffPlural,
    'appointmentSingular': appointmentSingular,
    'bookCta': bookCta,
    'noteLabel': noteLabel,
    'myAppointments': myAppointments,
    'priceLabel': priceLabel,
    'durationLabel': durationLabel,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerticalTerms &&
          other.businessSingular == businessSingular &&
          other.customerSingular == customerSingular &&
          other.customerPlural == customerPlural &&
          other.serviceSingular == serviceSingular &&
          other.servicePlural == servicePlural &&
          other.serviceAccusative == serviceAccusative &&
          other.staffSingular == staffSingular &&
          other.staffPlural == staffPlural &&
          other.appointmentSingular == appointmentSingular &&
          other.bookCta == bookCta &&
          other.noteLabel == noteLabel &&
          other.myAppointments == myAppointments &&
          other.priceLabel == priceLabel &&
          other.durationLabel == durationLabel;

  @override
  int get hashCode => Object.hash(
    businessSingular,
    customerSingular,
    customerPlural,
    serviceSingular,
    servicePlural,
    serviceAccusative,
    staffSingular,
    staffPlural,
    appointmentSingular,
    bookCta,
    noteLabel,
    myAppointments,
    priceLabel,
    durationLabel,
  );
}
