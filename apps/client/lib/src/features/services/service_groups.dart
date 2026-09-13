/// Grupisanje cjenovnika po `Service.category` — DoD taska 19.
///
/// Stoji kao čista funkcija izvan widgeta, jer je ovo jedino mjesto na ekranu `/services`
/// koje ima pravilo. Logika u `build` metodi se testira samo kroz `pumpWidget`, pa se u
/// praksi testira površno; ovdje se svaki rubni slučaj (prazna kategorija, jedna grupa,
/// nepoznato ime) provjerava direktno.
library;

import 'package:core_domain/core_domain.dart';

/// Jedna kategorija i njene usluge.
class ServiceGroup {
  const ServiceGroup({required this.category, required this.services});

  /// Ime kategorije kako ga je salon upisao. **Prazan string znači bez kategorije** —
  /// to je uredno stanje, ne nedostajući podatak (`category` je `@Default('')`).
  final String category;

  final List<Service> services;

  bool get isUncategorized => category.isEmpty;
}

/// Usluge razvrstane po kategoriji, **u redoslijedu u kojem su stigle**.
///
/// ## Zašto se ovdje ne sortira
///
/// `ServiceRepository.forSalon` već vraća uzlazno po `category` pa po `name`, pa je
/// dovoljno proći listu jednom i otvarati grupu pri prvom viđenju imena. Drugo sortiranje
/// ovdje bi značilo dva izvora istine za isti poredak — i prvo neslaganje bi izašlo kao
/// „lista je ispravna u testu, a naopaka na ekranu".
///
/// Posljedica koju treba znati: uzlazno sortiranje stavlja **usluge bez kategorije na
/// vrh**, jer prazan string sortira prije svakog imena. To je ispravno i namjerno — red
/// bez zaglavlja iznad imenovanih grupa se čita kao „ostalo, pa onda kategorije", što je
/// tačan opis podatka.
///
/// ## Kategorija je slobodan tekst
///
/// Salon je mijenja iz admina (task 19, „Zamke"), pa se ovdje **ništa ne pretpostavlja**:
/// nepoznata vrijednost je samo naslov, a prazna je vlastita grupa. Enum bi ovdje značio
/// da salon koji doda kategoriju mora čekati novi store submission.
///
/// Poređenje imena je **doslovno**, ne case-insensitive: „Brada" i „brada" upisane iz
/// admina su dvije grupe, jer jesu dva različita podatka — spajanje bi sakrilo grešku u
/// unosu umjesto da je pokaže salonu.
List<ServiceGroup> groupByCategory(List<Service> services) {
  final redoslijed = <String>[];
  final poKategoriji = <String, List<Service>>{};

  for (final service in services) {
    final kategorija = service.category.trim();
    final lista = poKategoriji.putIfAbsent(kategorija, () {
      redoslijed.add(kategorija);
      return <Service>[];
    });
    lista.add(service);
  }

  return [
    for (final kategorija in redoslijed)
      ServiceGroup(
        category: kategorija,
        services: List.unmodifiable(poKategoriji[kategorija]!),
      ),
  ];
}
