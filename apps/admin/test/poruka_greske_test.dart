import 'package:admin/src/core/poruka_greske.dart';
import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// FE-501: vlasnik salona ne smije vidjeti SQL kod ni ime tabele.
void main() {
  test('validacija iz SQL-a (PT400) stiže na ekran', () {
    final greska = mapError(
      const PostgrestException(
        message: 'Pauza mora biti unutar radnog vremena',
        code: 'PT400',
      ),
    );
    expect(porukaGreske(greska), 'Pauza mora biti unutar radnog vremena');
  });

  test('greška baze bez PT koda dobija opštu rečenicu, ne kod', () {
    final greska = mapError(
      const PostgrestException(
        message: 'relation "public.working_hours" does not exist',
        code: '42P01',
      ),
    );
    final tekst = porukaGreske(greska, opsta: 'Radno vrijeme nije sačuvano.');
    expect(tekst, 'Radno vrijeme nije sačuvano.');
    expect(tekst, isNot(contains('42P01')));
    expect(tekst, isNot(contains('working_hours')));
  });

  test('izuzetak koji nije ApiError nikad ne ide na ekran', () {
    expect(porukaGreske(StateError('boom')), opstaPorukaGreske);
  });
}
