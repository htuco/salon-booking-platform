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
    required this.primaryColor,
    required this.secondaryColor,
    required this.themeName,
    required this.authProviders,
  });

  final String flavor;
  final String salonId;
  final String slug;
  final String vertical;
  final String displayName;

  /// ARGB, ne heks string — app ne parsira boju pri startu.
  /// Izvor: `branding.primaryColor` iz `tenant.yaml`.
  final int primaryColor;
  final int secondaryColor;

  /// Imenovana tema (`AppTheme` u `core_ui`); bira svjetlinu, neutralnu
  /// paletu i pismo dok backend ne odgovori.
  final String themeName;

  /// Provideri iz `auth.providers` u `tenant.yaml`, kao imena koja
  /// `AuthProvider.fromWire` poznaje. Parsira se u `AuthConfig.fromNames`;
  /// filtriranje po platformi radi `AuthConfig.forPlatform`.
  final List<String> authProviders;
}

const Map<String, TenantConfig> kTenants = <String, TenantConfig>{
  '63679dd5-6ac8-4061-b4d6-d3ef181c9baa': TenantConfig(
    flavor: 'amkobarber',
    salonId: '63679dd5-6ac8-4061-b4d6-d3ef181c9baa',
    slug: 'amkobarber',
    vertical: 'barber',
    displayName: 'Amko Barbershop',
    primaryColor: 0xFFE3B23C,
    secondaryColor: 0xFF0D0D0D,
    themeName: 'modern_barber',
    authProviders: <String>['apple', 'google', 'email'],
  ),
  '550e8400-e29b-41d4-a716-446655440000': TenantConfig(
    flavor: 'barberstudiovitez',
    salonId: '550e8400-e29b-41d4-a716-446655440000',
    slug: 'barberstudiovitez',
    vertical: 'barber',
    displayName: 'Barber Studio Vitez',
    primaryColor: 0xFFC6A667,
    secondaryColor: 0xFF171717,
    themeName: 'modern_barber',
    authProviders: <String>['apple', 'google', 'email'],
  ),
  '550e8400-e29b-41d4-a716-446655440001': TenantConfig(
    flavor: 'beautystudiotravnik',
    salonId: '550e8400-e29b-41d4-a716-446655440001',
    slug: 'beautystudiotravnik',
    vertical: 'beauty',
    displayName: 'Beauty Studio Travnik',
    primaryColor: 0xFFB76E79,
    secondaryColor: 0xFFFFF5F5,
    themeName: 'elegant_beauty',
    authProviders: <String>['apple', 'google', 'email'],
  ),
  '550e8400-e29b-41d4-a716-446655440003': TenantConfig(
    flavor: 'fiziozenica',
    salonId: '550e8400-e29b-41d4-a716-446655440003',
    slug: 'fiziozenica',
    vertical: 'health',
    displayName: 'Fizio Centar Zenica',
    primaryColor: 0xFF2F6F6D,
    secondaryColor: 0xFFE6F0EF,
    themeName: 'clinical_calm',
    authProviders: <String>['apple', 'google', 'email'],
  ),
  '550e8400-e29b-41d4-a716-446655440002': TenantConfig(
    flavor: 'masazamostar',
    salonId: '550e8400-e29b-41d4-a716-446655440002',
    slug: 'masazamostar',
    vertical: 'health',
    displayName: 'Studio Masaže Mostar',
    primaryColor: 0xFF56664F,
    secondaryColor: 0xFFEEF0E9,
    themeName: 'warm_wellness',
    authProviders: <String>['apple', 'google', 'email'],
  ),
};
