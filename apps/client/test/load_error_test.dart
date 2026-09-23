import 'package:client/src/core/router/app_router.dart';
import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// FE-501: **greška nije prazno stanje.** Galerija, recenzije i pravila su pad upita
/// crtali kao „nema slika", „još nema recenzija" i „pravila nisu objavljena". Svaka od
/// tih rečenica je netačna kad podaci postoje, i nijedna nije nudila izlaz.
void main() {
  const mreza = NetworkError('Nema veze sa serverom');
  const server = ServerError('Greška baze (42P01)');

  for (final (ruta, prazno) in [
    (ClientRoute.gallery.path, 'Salon još nije dodao fotografije.'),
    (ClientRoute.reviews.path, 'Još nema recenzija.'),
    (
      ClientRoute.terms.path,
      'Tekst trenutno nije dostupan. Pokušajte ponovo za koji trenutak.',
    ),
  ]) {
    testWidgets('$ruta: pao upit nudi „Pokušaj ponovo", ne prazno stanje', (
      tester,
    ) async {
      await pumpEkran(tester, ruta: ruta, greskaIzvora: mreza);

      expect(find.text('Nema veze s internetom.'), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
      // Naslov ekrana ostaje; tvrdnja „nema podataka" ne.
      expect(find.text(prazno), findsNothing);
    });
  }

  testWidgets('tehnička poruka i kod ne idu korisniku', (tester) async {
    await pumpEkran(
      tester,
      ruta: ClientRoute.gallery.path,
      greskaIzvora: server,
    );

    expect(
      find.text('Nešto je pošlo naopako. Pokušaj ponovo.'),
      findsOneWidget,
    );
    expect(find.textContaining('42P01'), findsNothing);
  });

  testWidgets('„Pokušaj ponovo" ponovo traži od izvora', (tester) async {
    final container = await pumpEkran(
      tester,
      ruta: ClientRoute.gallery.path,
      greskaIzvora: mreza,
    );
    var citanja = 0;
    container.listen(salonGalleryProvider, (_, _) => citanja++);

    await tester.tap(find.widgetWithText(AppButton, 'Pokušaj ponovo'));
    await tester.pump();

    // Invalidacija ponovo pokreće provider — keširana greška bi ostala bez promjene.
    expect(citanja, greaterThan(0));
  });
}
