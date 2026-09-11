import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vertical_provider.dart';

/// Tema aktivnog tenanta — **nikad `null`, nikad `AsyncLoading` na ekranu**.
///
/// Fallback lanac po `docs/02 §16`, tim redom:
///
/// 1. `salons.primary_color`/`secondary_color` sa backenda — izvor istine, mijenja se bez
///    builda;
/// 2. `TenantConfig` iz generisanog registra (`tenants.g.dart`) — boje iz `tenant.yaml`,
///    poznate prije prvog mrežnog poziva;
/// 3. podrazumijevana paleta — samo za build bez tenanta u registru (test, `SALON_ID`
///    koji nije regenerisan).
///
/// **Ovo je mjesto gdje nema bijelog flasha.** `salonProvider` je `FutureProvider`, pa je
/// prvi frame uvijek `AsyncLoading`; da tema čeka njegovu vrijednost, app bi se otvorila u
/// Flutterovoj svijetloj temi i tek onda skočila u tenant paletu — na tamnom barberu je to
/// bijeli bljesak preko cijelog ekrana. Zato se korak 1 uzima kroz `valueOrNull`, a koraci
/// 2–3 su sinhroni.
///
/// Kad odgovor stigne i boje se razlikuju od onih iz `tenant.yaml`, tema se prekomponuje —
/// zato `tenant.yaml` mora nositi iste boje kao red u bazi. Kad se raziđu, baza je u pravu,
/// ali korisnik vidi treptaj boje na startu.
final appThemeProvider = Provider<ThemeData>((ref) {
  final tenant = ref.watch(tenantProvider);
  final salon = ref.watch(salonProvider).valueOrNull;

  final primary = _boja(salon?.primaryColor) ?? tenant?.primaryColor;
  final secondary = _boja(salon?.secondaryColor) ?? tenant?.secondaryColor;
  final themeName = salon?.theme ?? tenant?.themeName;

  return buildAppTheme(
    primary: Color(primary ?? _podrazumijevanaPrimarna),
    secondary: Color(secondary ?? _podrazumijevanaSekundarna),
    themeName: themeName,
  );
});

/// Podrazumijevane boje = `modern_barber` paleta. Vrijede samo dok ni backend ni registar
/// nemaju odgovor.
const int _podrazumijevanaPrimarna = 0xFFC6A667;
const int _podrazumijevanaSekundarna = 0xFF171717;

/// `#RRGGBB` → ARGB. Vraća `null` umjesto da baca.
///
/// Boja stiže iz baze, koju uređuje vlasnik salona kroz admin app. Neispravna vrijednost
/// tamo ne smije biti izuzetak pri startu klijentske aplikacije — pada na sljedeći korak
/// lanca, gdje je boja iz `tenant.yaml` već validirana generatorom.
int? _boja(String? hex) {
  if (hex == null) return null;
  final ocisceno = hex.startsWith('#') ? hex.substring(1) : hex;
  if (ocisceno.length != 6) return null;
  final vrijednost = int.tryParse(ocisceno, radix: 16);
  return vrijednost == null ? null : 0xFF000000 | vrijednost;
}
