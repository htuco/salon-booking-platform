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
- [ ] `AuthConfig.allowGuest` i `AuthRepository.continueAsGuest` **uklonjeni**, ne ostavljeni iza
      flaga — isti obrazac kao ADR-0011 za Facebook
- [ ] `salon_settings.allow_guest_booking` uklonjen ili trajno `false` uz `check`; odluka zapisana
- [ ] `book_appointment` odbija poziv bez identiteta
- [ ] pgTAP: anonimna rezervacija ne prolazi
- [ ] Postavke ne nude prekidač koji ništa ne radi

## Zamke
- **Anonimna Supabase sesija nije isto što i gost.** `is_anonymous` korisnik ima sesiju i `customers`
  red; ako se negdje koristi, ukloni i to svjesno, ne usput.
- Uklanjanje kolone iz `salon_settings` dira RPC iz taska 36 — v. njegov potpis.

## Status

Nije počet.
