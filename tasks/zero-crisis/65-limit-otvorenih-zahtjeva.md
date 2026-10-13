# Task 65 — Limit otvorenih zahtjeva po klijentu

| | |
|---|---|
| **Procjena** | 0,5 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | `docs/research/auth-krajnji-korisnik.md` §6 · `book_appointment` (`20260922100000_automatsko_potvrdjivanje.sql`) |

## Cilj
Zaštita od spama bez 2FA (ADR-0029): jedan račun ne može zatrpati salon zahtjevima.
`book_appointment` danas nema nikakav limit.

## Definicija gotovog
- [x] Najviše **2** `pending` termina po klijentu po salonu (broj u `salon_settings`, default 2)
- [x] Prekoračenje vraća vlastiti kod (`PT429`) i poruku „Već imate zahtjeve koji čekaju potvrdu"
- [x] Admin ručno zakazivanje nije ograničeno
- [x] `p_note` ograničen dužinom (npr. 500 znakova)
- [x] pgTAP: treći pending pada, potvrđeni se ne broje, drugi salon ima svoj brojač
- [x] Klijent: `ApiError` mapiranje i poruka na koraku 4

## Status (2026-10-13) — 🟡 kod dokazan lokalno, čeka deploy

Grana `feat/limit-zahtjeva`. Migracija `20261013120000_limit_otvorenih_zahtjeva.sql`: kolona
`salon_settings.max_pending_per_customer` (default 2, `check` 1–20) i `book_appointment` sa istim
potpisom. Broje se samo `pending` koji još vrijede (rok nije prošao), po `customer_id`, uz `for update`
nad redom klijenta protiv utrke. Admin i `auto` mod nisu ograničeni. `p_note` je najviše 500 znakova
(`PT400`). `mapError`: `PT429` → `RateLimitError`, a `displayMessage` vraća poruku iz baze (vrijedi
i za `report_content`). Korak 4 prikazuje `bookingTooManyPending`, a izbor termina ostaje.

Postavka **nije** u admin postavkama: `update_salon_settings` bi morao dobiti novi potpis, a to je
preopterećenje (v. task 37). Granica se zasad mijenja SQL-om; u Meluru je može dodati task 71.

**Dokazano:** `./tool/test_supabase.sh` — pgTAP PASS (nov `028`, 13 asercija), svi REST i `deno`
testovi PASS. Mutacije: bez limita padaju 4 asercije, uz brojanje potvrđenih 2, uz limit i za admina 1.
`core_api` 142, klijent 632 testova PASS; `flutter analyze` čist na `core_api`, klijentu i adminu.

**Ostalo za sljedećeg:**
- Hamza poslije merge-a: `supabase db push`. Provjera: `select max_pending_per_customer from
  salon_settings` vraća 2 za svaki salon.
- Poruka viđena na uređaju (treći zahtjev u istom salonu).
