/// Repozitoriji nad Supabaseom — jedini sloj koji zna za HTTP i imena tabela.
///
/// Ekran ne zove `Supabase.instance` i ne zna za `from('salons')`. Sve što ekranu treba
/// dolazi kao model iz `core_domain`, kroz repozitorij i Riverpod provider.
library;

export 'src/vertical/vertical_repository.dart';
