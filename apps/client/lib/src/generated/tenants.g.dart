// GENERISANO — ne editovati ručno. Pokreni: dart run tool/gen_flavors.dart
//
// Build-time registar tenanata. Runtime izvor istine je backend —
// ovdje su samo fallback vrijednosti dostupne prije prvog odgovora.

class TenantConfig {
  const TenantConfig({
    required this.flavor,
    required this.salonId,
    required this.slug,
    required this.vertical,
    required this.displayName,
  });

  final String flavor;
  final String salonId;
  final String slug;
  final String vertical;
  final String displayName;
}

const Map<String, TenantConfig> kTenants = <String, TenantConfig>{
  '550e8400-e29b-41d4-a716-446655440000': TenantConfig(
    flavor: 'barberstudiovitez',
    salonId: '550e8400-e29b-41d4-a716-446655440000',
    slug: 'barberstudiovitez',
    vertical: 'barber',
    displayName: 'Barber Studio Vitez',
  ),
  '550e8400-e29b-41d4-a716-446655440001': TenantConfig(
    flavor: 'beautystudiotravnik',
    salonId: '550e8400-e29b-41d4-a716-446655440001',
    slug: 'beautystudiotravnik',
    vertical: 'beauty',
    displayName: 'Beauty Studio Travnik',
  ),
};
