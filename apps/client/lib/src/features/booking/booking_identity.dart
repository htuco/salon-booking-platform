import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `customers.id` korisnika koji rezerviše, ili `null` dok nije poznat.
///
/// **Danas je uvijek `null` u pravoj aplikaciji, i to nije privremena rupa nego tačan
/// opis stanja sistema.** `book_appointment` traži da klijent **već postoji**
/// (`.claude/docs/security.md`, "Šta još nije zatvoreno"), a upis u `customers` nema
/// validiranu funkciju dok ne stigne auth (Sprint 2). Uz to je sama funkcija grantovana
/// samo roli `authenticated`, pa bi poziv bez tokena vratio `NotFoundError` — RLS
/// odbijanje je namjerno neraspoznatljivo od nepostojećeg reda.
///
/// Zato zadnji korak flowa **ne šalje zahtjev bez ovoga**, nego vodi na prijavu
/// (`docs/06 §1.1`: login se traži tek na kraju). Kad Sprint 2 donese `AuthIdentity` i
/// upsert klijenta, ovaj provider dobije pravu implementaciju i **nijedan ekran se ne
/// mijenja** — struktura poziva je već ista.
///
/// Override-uje ga test (da bi 409 putanja uopšte mogla da se izazove) i `demo_main.dart`
/// (da bi se flow mogao vidjeti i snimiti bez backenda).
final bookingCustomerIdProvider = Provider<String?>((ref) => null);
