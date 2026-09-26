# Task 47 — Admin ljuska za radnika

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [46](46-uloga-employee-i-izolacija.md) |
| **Blokira** | — |
| **Reference** | task [29](../sprint-3/29-responsive-shell.md) · `prototype/admin/SPEC.md` |

## Cilj
Prijavljen radnik dobija istu aplikaciju, ali suženu na ono što smije.

## Definicija gotovog
- [x] Router guard prima `employee`, ne samo `salon_admin` — danas ga izbacuje na `/login`
- [x] Navigacija ne nudi module koje radnik nema; ćelija koja vodi u zabranu je gora od ćelije koje nema
- [x] „Danas", kalendar i lista termina pokazuju **njegove** termine, bez filtera koji se može isključiti
- [x] Promet i metrike salona se radniku ne prikazuju
- [x] Widget testovi za obje uloge nad **istim** ekranom — dva stabla bi prolazila i kad ljuska ne radi
- [x] Viđeno uživo, obje prijave, na 1440 i 402

## Zamke
- **Sužavanje na ekranu nije izolacija.** Ako politika iz taska 46 ne stoji, sakriven modul je i
  dalje dostupan kroz URL i kroz REST. Ekran prati politiku, ne zamjenjuje je.
- `kAdminDestinations` je **jedna** lista za obje širine (task 29) — filter ide u nju, ne u dvije ljuske.

## Status (2026-09-24)

✅ Spojen u `main` kroz [PR #107](https://github.com/htuco/salon-booking-platform/pull/107).
Bez migracije.

- Guard pušta `employee` sa vezom na `employees`; `kRuteRadnika` je lista dozvoljenih ruta
  (Danas, kalendar, termini i detalj, „Još"), ostalo vodi na `/dashboard`.
- Navigacija je ista lista, filtrirana (`adminDestinationsZa`); „Još" radniku nosi samo odjavu.
- Upiti termina nose `employeeId` iz članstva; kalendar crta samo njegovu kolonu, „Slobodno
  vrijeme" i zauzetost računaju samo njegovu smjenu.
- Promet, „Novi termin", blokade, „Dodaj pauzu/Zatvori dan" i pretraga klijenata radniku ne stoje.

**Dokaz:** `melos run analyze` čist, `melos run test` zelen (admin 452, bilo 424) — testovi za obje
uloge nad istim ekranom: ljuska (`admin_shell_test`), dashboard (`dashboard_screen_test`), guard
po 11 adresa (`widget_test`) i prijava (`login_screen_test`). Uživo protiv lokalnog stacka
(`supabase db reset` + lokalni nalog radnika vezan za „Emir"), 1440 i 402: radnik vidi tri
modula i jedan svoj termin od tri, bez prometa; `/clients` iz adrese vraća na `/dashboard`;
vlasnik vidi svih osam modula, tri termina i promet.

**Živa provjera je našla ono što testovi nisu:** ekran prijave i ekran poziva su sami pitali
`isSalonAdmin` i odjavljivali radnika porukom „nije vezan ni za jedan salon". Popravljeno
(`imaPristup`) uz regresioni test koji bez popravke pada.

**Ostalo za sljedećeg:** radnik nema način da vidi termin bez dodijeljenog radnika — namjerno,
po politici iz taska 46. Sprint 5 (slike, ADR-0015) treba raspisati.
