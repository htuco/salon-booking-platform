# Task 45 — Kreiranje naloga za osoblje

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | — |
| **Blokira** | [46](46-uloga-employee-i-izolacija.md), [47](47-admin-ljuska-za-radnika.md) |
| **Reference** | `packages/core_api/lib/src/auth/staff_repository.dart` · `.claude/docs/security.md` |

## Cilj
Danas **ne postoji nijedan način da se napravi nalog za osoblje** — ni za `salon_admin`. Oba
postojeća naloga su upisana ručno u SQL-u. Bez ovoga Faza 2 nema ulaza.

## Definicija gotovog
- [ ] Salon iz admina poziva člana osoblja na email; nastaje `auth.users` + `public.users` red
- [ ] Uloga se dodjeljuje eksplicitno, iz zatvorene liste; pozivalac ne može dodijeliti `super_admin`
- [ ] `app_metadata.role` i `app_metadata.salon_id` se postavljaju **na serveru**, nikad iz klijenta
- [ ] Poziv ističe i može se povući
- [ ] pgTAP: admin salona A ne može napraviti nalog u salonu B; klijent ne može napraviti nijedan
- [ ] Zapisano šta se dešava kad se nalog ukloni — pristup prestaje, istorija ostaje

## Zamke
- **Radnik nije nalog** (zamka iz taska 33): `employees` je osoblje salona, `public.users` +
  `auth_identities` su prijava. Ovaj task pravi nalog; vezivanje na `employees` red je task 46.
- **JWT uloga sama po sebi ne znači ništa** — traži se i red u `public.users`. Oboje mora nastati
  atomarno, inače postoji nalog koji prolazi guard a nema prava, ili obrnuto.
- Potvrda emaila i SMTP limit su stvarna prepreka: hostovani projekat danas odbija `signup` poslije
  dva pokušaja. Odluči ide li poziv kroz Supabase invite ili kroz vlastiti tok, i zapiši.
- Service role ključ ne smije u klijentski build ni u repo.

## Status

Nije počet.
