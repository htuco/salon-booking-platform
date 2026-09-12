/// Repozitoriji nad Supabaseom — jedini sloj koji zna za HTTP i imena tabela.
///
/// Ekran ne zove `Supabase.instance` i ne zna za `from('salons')`. Sve što ekranu treba
/// dolazi kao model iz `core_domain`, kroz repozitorij i Riverpod provider.
///
/// ## Tri pravila ovog sloja
///
/// 1. **Van ovog paketa ne izlazi `Map`.** Repozitorij vraća model iz `core_domain` ili
///    baca — nikad sirovi red.
/// 2. **Van ovog paketa ne izlazi `PostgrestException`.** Sve greške prolaze kroz
///    `mapError` i izlaze kao `ApiError`, koji je `sealed` pa ga `switch` provjerava na
///    iscrpnost. Ekran hvata `ApiError`, nikad tuđi tip.
/// 3. **Modeli žive u `core_domain`, ne ovdje.** Obrazloženje:
///    `docs/adr/0006-modeli-u-core-domain.md`.
///
/// Upisi (termin, customer, device) idu isključivo kroz validiranu RPC funkciju —
/// `book_appointment` iz taska 05. Nema `insert` sa klijenta; v. `.claude/docs/security.md`.
library;

export 'src/auth/auth_platform_mapper.dart';
export 'src/auth/auth_repository.dart';
export 'src/auth/customer_repository.dart';
export 'src/auth/supabase_auth_repository.dart';
export 'src/booking/booking_repository.dart';
export 'src/catalog/employee_repository.dart';
export 'src/catalog/salon_repository.dart';
export 'src/catalog/service_repository.dart';
export 'src/catalog/settings_repository.dart';
export 'src/catalog/working_hours_repository.dart';
export 'src/errors/errors.dart';
export 'src/providers.dart';
export 'src/vertical/vertical_repository.dart';
