/// Terminologija po vertikali — **„Majstor" nije univerzalna riječ.**
///
/// `prototype/adminv2/` je crtan za barber salon, pa mu svaki ekran piše „Majstori". U
/// zubarskoj ordinaciji to je „Doktor", u beauty salonu „Kozmetičar". Riječ zato dolazi iz
/// `vertical.terms`, ne iz canvasa — isto pravilo koje klijentska aplikacija već provodi
/// (`CLAUDE.md`: „Tekst se ne uzima").
///
/// **Dok vertikala stiže, vraća se [Vertical.fallback]**, a ne spinner i ne prazan string:
/// generički „Radnik" u zaglavlju kolone je bolji od praznine koja izgleda kao greška u
/// učitavanju. Isti obrazac kao `verticalOf` u klijentskoj app-i.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vertikala salona kojim admin upravlja; nikad `null`, nikad `throw`.
Vertical vertikalaAdmina(WidgetRef ref) =>
    ref.watch(adminVerticalProvider).valueOrNull ?? Vertical.fallback;

/// Kako se u ovoj vertikali zove **jedan** radnik („Majstor", „Doktor", „Kozmetičar").
///
/// Koristi se za zaglavlje kolone i labelu polja, gdje stoji jednina.
///
/// Množine (`terms.staffPlural`) ovdje namjerno nema: u fallbacku je to „Naš tim", fraza
/// pisana za **klijentski** ekran („Upoznajte naš tim"), a ne riječ koja se da ubaciti u
/// admin rečenicu tipa „3 aktivna radnika". Kad zatreba, dodaje se uz svoj `terms` ključ,
/// ne prenamjenom postojećeg.
String radnikJednina(WidgetRef ref) => vertikalaAdmina(ref).terms.staffSingular;
