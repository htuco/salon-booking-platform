import 'package:core_api/core_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `customers.id` korisnika koji rezerviše, ili `null` dok nije poznat.
///
/// ## Šta se ovdje stvarno dešava
///
/// Od taska 13 ovo nije konstanta nego **upit u bazu**: `CustomerRepository` čita
/// `customers` red prijavljenog korisnika pod politikom `own_customer`, koja ga presijeca
/// po identitetu iz JWT-a i po `x-salon-id` headeru. Neprijavljen korisnik nema red i
/// dobija `null` — isto kao prijavljen kojem red još nije napravljen.
///
/// **Red pravi [task 14](../../../../../tasks/sprint-2/14-identitet-i-klijent-upsert.md)**,
/// kroz `security definer` funkciju; `insert` sa klijenta ne postoji i neće postojati
/// (`.claude/docs/security.md`). Do tada je odgovor redovno `null`, ali to je izmjereno
/// stanje baze, a ne zaglavljena vrijednost: isti kod počne vraćati `id` čim upsert stigne,
/// bez izmjene ijednog ekrana.
///
/// ## Zašto sinhroni `String?`, a ne `AsyncValue`
///
/// Pozivalac je `BookingSubmitNotifier`, koji identitet čita **u trenutku slanja**, ne
/// dok crta ekran. `AsyncValue` bi ga natjerao da bira između čekanja i pretpostavke usred
/// jedinog upisa u sistem. Asinhroni izvor je [currentCustomerIdProvider] u `core_api`;
/// ovdje se čita njegova zadnja poznata vrijednost, koju prijava i odjava same osvježavaju.
///
/// Override-uje ga test (da bi `409` putanja uopšte mogla da se izazove) i `demo_main.dart`
/// (da bi se flow mogao vidjeti i snimiti bez backenda).
final bookingCustomerIdProvider = Provider<String?>(
  (ref) => ref.watch(currentCustomerIdProvider).valueOrNull,
);
