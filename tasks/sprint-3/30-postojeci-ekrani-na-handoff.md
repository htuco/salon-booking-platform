# Task 30 — Postojeći ekrani na handoff

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3b` `3d` `3j` · `3k` `3m` `3n` `3u` · [24](../sprint-2/24-admin-akcije-nad-terminima.md) |

## Cilj
Prijava, „Danas", zahtjevi za potvrdu, lista i detalj termina dobijaju izgled iz handoffa. Tokovi
ispod ostaju netaknuti.

## Definicija gotovog
- [ ] `/login` po `3j` (desktop) i `3u` (telefon); auth ostaje Supabase email + lozinka
- [ ] `/dashboard` po `3b` / `3k` — „Danas"
- [ ] Pending prikaz po `3d` / `3m`, unutar postojećih termina
- [ ] Detalj termina po `3n`, sa postojeće četiri akcije
- [ ] **Nijedna RPC putanja nije promijenjena** — `set_appointment_status`, `cancel_appointment` i
      `book_appointment` rade kao od taska 24
- [ ] Postojećih 27 admin testova i dalje prolazi; novi testovi za ono što ekran sad prikazuje
- [ ] Prolaz kroz browser na oba tenanta — ista aplikacija, druga prijava, nijedan tuđi termin

## Koraci
1. Prijava, pa „Danas", pa zahtjevi, pa detalj
2. Commit po ekranu, ne jedan veliki
3. Prolaz kroz browser prije `/task complete`

## Zamke
- **Social login se ne dodaje adminu** (`SPEC.md`, „Funkcionalne granice"). Običan klijentski nalog
  ne smije proći admin guard — `private.is_admin()` traži **i** claim u JWT-u **i** red u
  `public.users`.
- Prijava nekog ko ima token a nema red izgleda kao prazna baza, a zapravo je pogrešno postavljen
  nalog (task 23). Ekran mora reći koje je od toga.
- **Statusi nose tekst**, ne samo boju.
- Demo sadržaj iz canvasa (imena, iznosi) nije podatak — ne prepisuje se ni u kod ni u testove.

## Status

Nije počet.
