# Task 41 — Zakazivanje bez prijave se uklanja

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | [ADR-0011](../../docs/adr/0011-facebook-login-se-ne-implementira.md) · task [26](../sprint-2/26-guest-flow-i-facebook.md) |

## Cilj
Svaki klijent se prijavljuje — email, Google ili Apple. Zakazivanje bez prijave se uklanja iz koda,
postavki i ugovora.

## Definicija gotovog
- [x] `AuthConfig.allowGuest` i `AuthRepository.continueAsGuest` **uklonjeni**, ne ostavljeni iza
      flaga — isti obrazac kao ADR-0011 za Facebook
- [x] `salon_settings.allow_guest_booking` uklonjen ili trajno `false` uz `check`; odluka zapisana
- [x] `book_appointment` odbija poziv bez identiteta
- [x] pgTAP: anonimna rezervacija ne prolazi
- [x] Postavke ne nude prekidač koji ništa ne radi

## Zamke
- **Anonimna Supabase sesija nije isto što i gost.** `is_anonymous` korisnik ima sesiju i `customers`
  red; ako se negdje koristi, ukloni i to svjesno, ne usput.
- Uklanjanje kolone iz `salon_settings` dira RPC iz taska 36 — v. njegov potpis.

## Status (2026-09-23) — ✅ zatvoren

Svaki klijent se prijavljuje; gost ne postoji ni u kodu, ni u postavkama, ni u ugovoru
([PR #100](https://github.com/htuco/salon-booking-platform/pull/100)).

- `AuthConfig.allowGuest`, `AuthRepository.continueAsGuest` i `allowGuestBooking` iz
  `tenant.yaml`/generatora su **uklonjeni**, ne skriveni iza flaga.
- Migracija `20260923160000_ukloni_guest_zakazivanje.sql` briše `salon_settings.allow_guest_booking`
  i mijenja potpis `update_salon_settings` (stari overload uklonjen). Odluka — kolona se briše, ne
  drži se trajno `false` — zapisana je u migraciji, po obrascu ADR-0011.
- `private.is_client()` sada traži aktivan, **neanoniman** `auth_identities` red, pa isti guard zatvara
  `book_appointment`, `ensure_customer`, otkazivanje i klijentske politike.
- Admin postavke više nemaju gost prekidač.

**Dokazano** (lokalno, Docker): `supabase test db` → `Files=17, Tests=478 … Result: PASS` (novi `017`
dokazuje da anonimna sesija nije klijent i da termin ne nastaje); svih 9 REST testova iz CI-ja
prolazi; `gen_flavors --check`, `melos run analyze` i `melos run test` zeleni. CI na PR-u zelen na oba
joba.

**Zamka nađena pri zatvaranju:** `register_device` je koristio `is_client()`, pa bi strožiji guard
ugasio registraciju push uređaja prije prijave (`009_push_devices` pao). Registracija uređaja nije
zakazivanje — funkcija je redefinisana u istoj migraciji sa starom provjerom uloge.

**Svjesno ostavljeno:** enum vrijednost `appointment_source.guest` (i admin labela „gost") ostaje kao
oznaka eventualnih starih redova; nijedan put je ne upisuje. `AuthSession.isAnonymous` ostaje kao
odbrana: `SupabaseAuthRepository` anonimnog korisnika mapira u „nije prijavljen".

**Ostalo:** nakon merge-a primijeniti migraciju na hostovani projekat (`supabase db push`).
