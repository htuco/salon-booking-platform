import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Placeholderi u tijelu pravnog teksta (task 21, ADR-0009).
///
/// Ovo nije kozmetika nego jedini razlog zbog kojeg tekst uopšte ima placeholdere:
/// `salon_settings.min_cancel_hours` je 3 za barbera i 6 za beauty, `cancel_appointment`
/// taj rok stvarno provodi, a handoff piše 2. Upisana cifra bi bila tvrdnja koju baza
/// demantuje čim salon promijeni postavku.
void main() {
  PolicySection sekcija(String body) => PolicySection(
    id: 'p1',
    sortOrder: 20,
    title: 'Otkazivanje',
    body: body,
    updatedAt: DateTime.utc(2026, 9, 14),
  );

  group('applyPolicyPlaceholders', () {
    test('popunjava sve poznate vrijednosti', () {
      final tekst = applyPolicyPlaceholders(
        'Otkažite {appointmentSingular} {minCancelHours} h prije. '
        'Kontakt: {phone} ili {email}.',
        const PolicyPlaceholders(
          minCancelHours: 6,
          phone: '030 711 000',
          email: 'kontakt@salon.ba',
          appointmentSingular: 'Termin',
        ),
      );

      expect(
        tekst,
        'Otkažite Termin 6 h prije. Kontakt: 030 711 000 ili kontakt@salon.ba.',
      );
    });

    // Ovo je asercija koja čuva odluku iz ADR-a, ne rub slučaj. Tiho brisanje bi dalo
    // „Termin možete otkazati najkasnije h prije početka" — rečenicu koja izgleda
    // ispravno a ne znači ništa, i koju niko ne prijavi.
    test('nepoznat placeholder ostaje vidljiv', () {
      final tekst = applyPolicyPlaceholders(
        'Rok je {minCancelHours} h, a popust {nepostojeci}.',
        const PolicyPlaceholders(minCancelHours: 3),
      );

      expect(tekst, 'Rok je 3 h, a popust {nepostojeci}.');
    });

    test('prazna vrijednost se tretira kao da je nema', () {
      // Beauty tenant u seedu ima `phone = ''`. Prazan string bi dao „Javite se na ."
      final tekst = applyPolicyPlaceholders(
        'Javite se na {phone}.',
        const PolicyPlaceholders(phone: '   '),
      );

      expect(tekst, 'Javite se na {phone}.');
    });

    test('tekst bez placeholdera prolazi nepromijenjen', () {
      const original = 'Cijene u aplikaciji su informativne.';
      expect(
        applyPolicyPlaceholders(original, const PolicyPlaceholders()),
        original,
      );
    });
  });

  group('paragraphs', () {
    test('prazan red razdvaja paragrafe', () {
      final dijelovi = sekcija('Prvi red.\n\nDrugi red.').paragraphs;
      expect(dijelovi, ['Prvi red.', 'Drugi red.']);
    });

    test('višak praznih redova i razmaka ne pravi prazan paragraf', () {
      final dijelovi = sekcija('Prvi.\n\n   \n\nDrugi.\n\n').paragraphs;
      expect(dijelovi, ['Prvi.', 'Drugi.']);
    });

    test('jedan prelom reda ostaje unutar istog paragrafa', () {
      final dijelovi = sekcija('Prva\nrečenica.').paragraphs;
      expect(dijelovi, ['Prva\nrečenica.']);
    });
  });

  group('isPlatform', () {
    test('sekcija bez salon_id je platformska', () {
      expect(sekcija('Tekst.').isPlatform, isTrue);
    });

    test('sekcija sa salon_id pripada salonu', () {
      final salonska = PolicySection(
        id: 'p2',
        salonId: '550e8400-e29b-41d4-a716-446655440000',
        sortOrder: 20,
        title: 'Otkazivanje',
        body: 'Tekst.',
        updatedAt: DateTime.utc(2026, 9, 14),
      );

      expect(salonska.isPlatform, isFalse);
    });
  });

  group('PolicyDocument', () {
    // Vrijednost koja ide u upit se ne izvodi iz `name`: preimenovanje konstante ne smije
    // tiho promijeniti `eq('document', ...)` i vratiti prazan dokument.
    test('wireValue odgovara enumu u bazi', () {
      expect(PolicyDocument.terms.wireValue, 'terms');
      expect(PolicyDocument.privacy.wireValue, 'privacy');
    });
  });
}
