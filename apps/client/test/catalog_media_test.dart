import 'package:client/src/features/booking/employee_step_screen.dart';
import 'package:client/src/features/booking/service_step_screen.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/catalog_harness.dart';

/// Fotografija usluge i staž radnika na ekranu — task 22.
///
/// **Prava fotografija se ovdje ne učitava i ne može se učitati.** Seed nosi
/// `images.demo.invalid` URL-ove, jer stvarne fotografije salona ne postoje do onboardinga;
/// widget test nad mrežnom slikom bi mjerio `cached_network_image`, ne naš kod. Ono što se
/// mjeri jeste da **URL stigne do komponente** — odatle nadalje je to tuđa biblioteka.
void main() {
  testWidgets(
    'korak 1 prosljeđuje fotografiju usluge, i podnosi njeno odsustvo',
    (tester) async {
      final container = await pumpKorak1(
        tester,
        usluge: const [
          Service(
            id: 's1',
            salonId: salonId,
            name: 'Fade',
            price: 20,
            durationMinutes: 40,
            imageUrl: 'https://images.demo.invalid/barber/fade.jpg',
          ),
          Service(
            id: 's2',
            salonId: salonId,
            name: 'Brada',
            price: 10,
            durationMinutes: 20,
          ),
        ],
      );

      expect(find.byType(ServiceStepScreen), findsOneWidget);

      final redovi = tester
          .widgetList<SelectableRow>(find.byType(SelectableRow))
          .toList();

      expect(redovi, hasLength(2));
      expect(redovi[0].imageUrl, 'https://images.demo.invalid/barber/fade.jpg');
      // Prazan okvir je **predviđeno stanje**, ne rupa: salon bez fotografija radi.
      expect(redovi[1].imageUrl, isNull);

      container.dispose();
    },
  );

  testWidgets(
    'korak 2 piše „Barber · 9 godina", a radnika bez staža ostavlja na tituli',
    (tester) async {
      final container = await pumpKorak2(
        tester,
        radnici: const [
          Employee(
            id: 'e1',
            salonId: salonId,
            name: 'Emir',
            role: 'Barber',
            experienceYears: 9,
          ),
          Employee(
            id: 'e2',
            salonId: salonId,
            name: 'Lejla',
            role: 'Stilistica',
          ),
        ],
      );

      expect(find.byType(EmployeeStepScreen), findsOneWidget);
      expect(find.text('Barber · 9 godina'), findsOneWidget);
      // Bez staža nema ni separatora — red ne smije izgledati kao da mu fali podatak.
      expect(find.text('Stilistica'), findsOneWidget);
      expect(find.textContaining('Stilistica ·'), findsNothing);

      container.dispose();
    },
  );

  testWidgets('bosanski plural: 1 godina, 2 godine, 5 godina', (tester) async {
    // ICU `few` pokriva 2–4 po CLDR pravilima za `bs`. Da je ključ napisan bez plural
    // oblika, ovo bi svuda ispisalo „godina" i greška bi se vidjela tek u prodavnici.
    final container = await pumpKorak2(
      tester,
      radnici: const [
        Employee(
          id: 'e1',
          salonId: salonId,
          name: 'A',
          role: 'Barber',
          experienceYears: 1,
        ),
        Employee(
          id: 'e2',
          salonId: salonId,
          name: 'B',
          role: 'Barber',
          experienceYears: 2,
        ),
        Employee(
          id: 'e3',
          salonId: salonId,
          name: 'C',
          role: 'Barber',
          experienceYears: 5,
        ),
      ],
    );

    expect(find.text('Barber · 1 godina'), findsOneWidget);
    expect(find.text('Barber · 2 godine'), findsOneWidget);
    expect(find.text('Barber · 5 godina'), findsOneWidget);

    container.dispose();
  });
}
