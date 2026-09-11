import 'package:client/src/core/env/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ovaj fajl se pokrece **sa** `--dart-define=SALON_ID=...` i bez Supabase vrijednosti —
/// tacno onako kako `flutter build web` za preview i `flutter run` bez backenda rade:
///
///   flutter test test/app_env_test.dart \
///     --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
///
/// Regresija: dok su Supabase vrijednosti bile obavezne, `AppEnv.fromDefines()` je bacao
/// prije `runApp`, pa je web build sa ispravnim SALON_ID-om davao **praznu bijelu stranicu**
/// bez poruke. Widget testovi to nisu vidjeli jer svi ubacuju env kroz override i nikad ne
/// pozovu pravi `fromDefines()`.
void main() {
  const salonId = String.fromEnvironment('SALON_ID');

  test('sa samo SALON_ID-om env se cita bez greske', () {
    final env = AppEnv.fromDefines();

    expect(env.salonId, salonId);
    expect(
      env.hasSupabase,
      isFalse,
      reason: 'bez SUPABASE_* definea klijent se ne smije dizati',
    );
  }, skip: salonId.isEmpty ? 'traži --dart-define=SALON_ID' : null);

  test('MissingEnvError poruka imenuje varijablu koja fali', () {
    // Ime varijable je jedino sto popravlja pogresno konfigurisan build.
    expect(MissingEnvError('SALON_ID').toString(), contains('SALON_ID'));
    expect(
      MissingEnvError('SALON_ID').toString(),
      contains('build_tenant.sh'),
      reason: 'poruka mora reci i kako se build ispravno pokrece',
    );
  });

  test('hasSupabase trazi obje vrijednosti', () {
    const samoUrl = AppEnv(
      salonId: 'x',
      supabaseUrl: 'https://x.supabase.co',
      supabaseAnonKey: '',
      apiUrl: '',
    );
    expect(samoUrl.hasSupabase, isFalse);

    const obje = AppEnv(
      salonId: 'x',
      supabaseUrl: 'https://x.supabase.co',
      supabaseAnonKey: 'kljuc',
      apiUrl: '',
    );
    expect(obje.hasSupabase, isTrue);
  });
}
