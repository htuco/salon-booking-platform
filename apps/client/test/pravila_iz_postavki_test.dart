/// Pravila rezervacije dolaze iz `salon_settings`, vertikala je samo rezerva (task 44).
///
/// Prije taska 44 su `bookingDateOnlyProvider`, `bookingRequiresStaffChoiceProvider`,
/// raspon trake datuma i prikaz cijena čitali **samo vertikalu**, pa prekidači u admin
/// Postavkama nisu mijenjali ništa na ekranu klijenta. Svaki test ovdje postavlja vertikalu
/// i postavke **suprotno**, da bi pao ako provider opet pročita pogrešan izvor.
library;

import 'package:client/src/core/prikaz_cijena.dart';
import 'package:client/src/features/booking/booking_flow_provider.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

/// Vertikala sa svim vrijednostima suprotnim od postavki ispod.
const _vertikala = Vertical(
  key: 'health',
  displayName: 'Ordinacija',
  terms: VerticalTerms.fallback,
  rules: BookingRules(
    mode: BookingMode.manual,
    granularity: BookingGranularity.dateOnly,
    slotStepMinutes: 30,
    bufferMinutes: 10,
    minAdvanceBookingHours: 4,
    maxAdvanceBookingDays: 60,
    minCancelHours: 6,
    pendingExpiryHours: 24,
    requireStaffChoice: true,
    showPricesInApp: true,
  ),
  features: VerticalFeatures.fallback,
  defaultTheme: 'clinical_calm',
);

const _postavke = SalonSettings(
  id: 's1',
  salonId: _salonId,
  bookingGranularity: 'exact_slot',
  maxAdvanceBookingDays: 14,
  requireStaffChoice: false,
  showPricesInApp: false,
);

Future<ProviderContainer> _kontejner({
  SalonSettings? postavke,
  Vertical vertikala = _vertikala,
}) async {
  final c = ProviderContainer(
    overrides: [
      verticalProvider.overrideWith((ref) async => vertikala),
      salonSettingsProvider.overrideWith((ref) async {
        if (postavke == null) throw const NetworkError('nema mreže');
        return postavke;
      }),
    ],
  );
  addTearDown(c.dispose);
  await c.read(verticalProvider.future);
  try {
    await c.read(salonSettingsProvider.future);
  } catch (_) {}
  return c;
}

void main() {
  test('postavke salona nadjačavaju vertikalu', () async {
    final c = await _kontejner(postavke: _postavke);

    expect(c.read(bookingDateOnlyProvider), isFalse);
    expect(c.read(bookingRequiresStaffChoiceProvider), isFalse);
    expect(c.read(bookingMaxAdvanceDaysProvider), 14);
    expect(c.read(prikaziCijeneProvider), isFalse);
  });

  test('bez postavki odlučuje vertikala', () async {
    final c = await _kontejner();

    expect(c.read(bookingDateOnlyProvider), isTrue);
    expect(c.read(bookingRequiresStaffChoiceProvider), isTrue);
    expect(c.read(bookingMaxAdvanceDaysProvider), 60);
    expect(c.read(prikaziCijeneProvider), isTrue);
  });

  test('vertikala bez cijena ih ne pokazuje ni kad ih salon uključi', () async {
    const bezCijena = Vertical(
      key: 'health',
      displayName: 'Ordinacija',
      terms: VerticalTerms.fallback,
      rules: BookingRules.fallback,
      features: VerticalFeatures(
        gallery: false,
        prices: false,
        anyStaff: true,
        team: true,
        socialLinks: true,
        noShowTracking: true,
        recall: false,
      ),
      defaultTheme: 'clinical_calm',
    );
    final c = await _kontejner(
      postavke: _postavke.copyWith(showPricesInApp: true),
      vertikala: bezCijena,
    );

    expect(c.read(prikaziCijeneProvider), isFalse);
  });
}
