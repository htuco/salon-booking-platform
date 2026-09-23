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
- [x] Salon iz admina poziva člana osoblja na email; nastaje `auth.users` + `public.users` red
- [x] Uloga se dodjeljuje eksplicitno, iz zatvorene liste; pozivalac ne može dodijeliti `super_admin`
- [x] `app_metadata.role` i `app_metadata.salon_id` se postavljaju **na serveru**, nikad iz klijenta
- [x] Poziv ističe i može se povući
- [x] pgTAP: admin salona A ne može napraviti nalog u salonu B; klijent ne može napraviti nijedan
- [x] Zapisano šta se dešava kad se nalog ukloni — pristup prestaje, istorija ostaje

## Zamke
- **Radnik nije nalog** (zamka iz taska 33): `employees` je osoblje salona, `public.users` +
  `auth_identities` su prijava. Ovaj task pravi nalog; vezivanje na `employees` red je task 46.
- **JWT uloga sama po sebi ne znači ništa** — traži se i red u `public.users`. Oboje mora nastati
  atomarno, inače postoji nalog koji prolazi guard a nema prava, ili obrnuto.
- Potvrda emaila i SMTP limit su stvarna prepreka: hostovani projekat danas odbija `signup` poslije
  dva pokušaja. Odluči ide li poziv kroz Supabase invite ili kroz vlastiti tok, i zapiši.
- Service role ključ ne smije u klijentski build ni u repo.

## Status (2026-09-24)

Gotov — [PR #105](https://github.com/htuco/salon-booking-platform/pull/105).

- **Odluka (ADR-0023):** poziv je **kod/link**, ne email. Vlasnik upiše ime i ulogu i pošalje
  poruku kako hoće; hostovani projekat nema SMTP i puca poslije dva emaila na sat. Zamka „odluči
  invite ili vlastiti tok" je time zatvorena.
- Baza (`20260924140000_pozivi_za_osoblje.sql`): `staff_invites` (sha256 koda, 7 dana, povlačenje),
  `create/revoke_staff_invite`, `list_staff_users`, `remove_staff_user`; `peek/accept_staff_invite`
  samo za `service_role`. Edge Function `accept-staff-invite` pravi `auth.users` sa `app_metadata`
  **iz poziva** i briše ga ako upis `public.users` padne.
- Lista osoblja kroz RPC, ne politiku: `membership()` čita `public.users` bez filtera.
- Uklanjanje briše samo `public.users` red — pristup prestaje odmah, istorija ostaje.
- Dokaz: `supabase test db` **551 PASS** (`020` nosi 37; sabotaža obara tačno aserciju „kod radi
  jednom"). `rest_pozivi_osoblja.ts` **17 PASS** kroz GoTrue i Edge Function (uloga iz tijela
  zahtjeva ignorisana, zauzet email 409, uklonjen nalog sa starim tokenom ne vidi ništa).
  `melos run test` PASS (admin 428), analyze čist.
- **Viđeno uživo 2026-09-24:** vlasnik na 1440 → Pristup → „Selma Hodžić", Vlasnik → kod
  `3F3TK3NMN5`, Selma odmah u listi. Na 402 link `/pozivnica?kod=…` popunio kod, Selma upisala
  email i lozinku → početna, prijavljena; baza: `salon_admin`, salon Vitez, poziv zatvoren. Poziv
  za radnika → nalog napravljen, ekran kaže da radnički pristup stiže uskoro.

**Ostalo:** CI ne pokreće Edge Functions, pa REST test ide samo lokalno (`tool/test_supabase.sh`).
Hostovani: `supabase db push`, pa `supabase functions deploy accept-staff-invite`.

