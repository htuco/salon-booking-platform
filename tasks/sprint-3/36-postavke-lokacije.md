# Task 36 — Postavke lokacije

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3i` `3t` · [21](../sprint-2/21-obavijesti-i-pravni-ekrani.md) |

## Cilj
Salon mijenja svoje podatke i booking pravila bez novog builda i bez nas.

## Definicija gotovog
- [ ] `/settings` po `3i`; „Još" (`3t`) je mobilni ulaz u module izvan četiri navigacijske ćelije
- [ ] Osnovni podaci: naziv, adresa, grad, telefon, email, Instagram, Facebook **stranica**
- [ ] Booking pravila iz `salon_settings`: način potvrde, buffer, min/max unaprijed, granularnost,
      `min_cancel_hours`, `allow_guest_booking`
- [ ] Salonski dio pravila (`salon_policies`) — otkazivanje, kašnjenje, kontakt
- [ ] **`app_policies` se ne dira iz admina.** Zakazivanje, Cijene i „Vaši podaci" obavezuju firmu
      i iste su u svakoj brandiranoj app-i
      ([ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md))
- [ ] pgTAP: `salon_admin` nema pisanje nad `app_policies`
- [ ] Promjena `min_cancel_hours` odmah mijenja ponašanje klijentskog otkazivanja

## Koraci
1. RPC + pgTAP, pa ekran
2. Provjera kroz klijentsku app-u: promjena pravila se vidi bez novog builda
3. Commit: `feat(admin): postavke lokacije i booking pravila`

## Zamke
- **Facebook stranica salona nije Facebook prijava.** `salons.facebook_url` je kontakt i ostaje;
  prijava preko Facebooka ne postoji
  ([ADR-0011](../../docs/adr/0011-facebook-login-se-ne-implementira.md)).
- **Branding ne ide ovdje.** Boje i logo dolaze iz `tenant.yaml` kroz generator; polje za boju u
  adminu bi napravilo drugi izvor istine za isti podatak.
- **Negativan test iz taska 21 mora ostati zelen**: `salon_admin` nad `app_policies`. Upravo je
  NULL grana u guardu pustila zahtjev bez `x-salon-id` headera u tasku 14.
- Sekcije pravila se crtaju dinamično `01..NN`. `PostgrestTransformBuilder.order` ima
  `ascending = false` kao **default** — ista zamka je dvaput dala obrnut redoslijed (taskovi 21 i
  23) i vidi se tek na ekranu.

## Status

Nije počet.
