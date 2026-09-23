# FE-605 — Kalendar: sticky zaglavlje, linija vremena, povlačenje termina

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana (+ ADR za povlačenje) |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupe 1 i 3), [FE-403](FE-403-kalendar-termina.md) |
| **Blokira** | — |
| **Reference** | `calendar/calendar_screen.dart` · `calendar/calendar_providers.dart` |

## Cilj
Kalendar postaje glavni radni ekran.

## Zatečeno stanje
`sadaProvider` već postoji (`calendar_screen.dart:225`), pa linija vremena ima izvor. Sedmični prikaz ne postoji (izostavljen u FE-403). Povlačenja nema; pomjeranje ide kroz detalj termina.

## Definicija gotovog
- [ ] Linija trenutnog vremena, samo na današnjem danu, osvježava se iz `sadaProvider`
- [ ] Zaglavlje sa radnicima ostaje vidljivo pri vertikalnom skrolu
- [ ] **Povlačenje termina — tek uz svoj ADR**: server presuđuje (exclusion constraint, `buffer_minutes` sa termina), klijent dobija obavijest, greška vraća blok na staro mjesto
- [ ] Povlačenje ima alternativu bez miša (WCAG 2.5.7)

## Zamke
- Povlačenje je **funkcionalnost**, ne redizajn: dira upit i RLS, pa traži `rls-auditor` i pgTAP.
- Optimističan prikaz bez vraćanja na grešku ostavlja lažan kalendar.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
