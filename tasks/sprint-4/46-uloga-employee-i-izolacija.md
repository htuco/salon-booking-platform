# Task 46 — Uloga `employee` i sužena izolacija

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [45](45-nalozi-za-osoblje.md) |
| **Blokira** | [47](47-admin-ljuska-za-radnika.md) |
| **Reference** | [01 §5.3](../../docs/01-mvp-spec.md) · [ADR-0013](../../docs/adr/0013-radnik-dobija-suzen-pristup-svojim-terminima.md) · `.claude/docs/security.md` |

## Cilj
Radnik se prijavi u istu admin aplikaciju i vidi **samo svoje** termine. Ovo je jedino mjesto u
sprintu gdje greška curi tuđe podatke.

## Zatečeno stanje
`staff_role` enum **već ima** vrijednost `employee`, ali je nijedna politika ne prihvata:
`private.is_admin()` traži `salon_admin` i u JWT-u i u `public.users`, a `private.is_client()`
isključuje `employee`. Takav nalog danas nema **nijedno** pravo. Uz to, `public.users` nema kolonu
koja bi nalog vezala za red u `employees`.

## Definicija gotovog
- [x] `public.users.employee_id` — FK na `employees(salon_id, id)`, obavezan kad je uloga `employee`
- [x] `private.is_employee(p_salon)` i `private.current_employee_id()`
- [x] Politike: radnik čita i mijenja **svoje** termine; cjenovnik, osoblje i postavke su mu čitanje
      ili ništa, po odluci iz ADR-a
- [x] `set_appointment_status` i `cancel_appointment` prihvataju radnika **samo** za njegove termine
- [x] pgTAP: radnik A ne vidi termine radnika B; ne mijenja tuđi termin; ne mijenja cjenovnik; ne
      vidi drugi salon
- [x] Deno REST test sa **stvarnim** JWT-om radnika — pgTAP ne dokazuje PostgREST sloj
- [x] `.claude/docs/security.md` dobija red za `employee` u tabeli uloga

## Zamke
- **Ovo mijenja model autorizacije.** Do sada je `is_admin()` bila jedina kapija za osoblje. Svaka
  politika koja je pisana na „osoblje = admin" mora biti pregledana, ne samo dopunjena.
- Termin **bez** dodijeljenog radnika (`employee_id is null`) nije ničiji — odluči vidi li ga radnik
  i zapiši; tiho izostavljanje znači da termin nestane iz svih pogleda.
- `rls-auditor` subagent ide prije PR-a.

## Status (2026-09-24)

Gotov — `rls-auditor` pregled urađen, nalazi zatvoreni.

- Migracija `20260924160000_uloga_employee.sql` je **aditivna**: `is_admin()` netaknut, sve
  `staff_manage` politike i RPC-evi pisanja ostaju admin-only (pregled svake je u zaglavlju
  migracije). Nove: `users.employee_id`, `is_employee`, `current_employee_id`,
  `can_manage_appointment`, politike `employee_own` i `employee_blocks`.
- **Termin bez radnika vidi samo admin** — zapisano u `security.md` i ADR-0013.
- Poziv za radnika mora nositi radnika bez naloga; pozivi iz taska 45 bez radnika su povučeni,
  a nalog radnika bez veze nema prava (`check` je `not valid` za stare redove).
- Admin: poziv za radnika bira radnika iz Osoblja umjesto kucanja imena.
- Dokaz: `supabase test db` **597 PASS** (`021` nosi 46). Sabotaže: politika bez uslova na
  radnika obara 3, kapija bez vlasništva termina obara 2, bez `is_active` obara 5. `rest_employee_izolacija.ts` **13 PASS**
  sa stvarnim JWT-om radnika; svih 12 REST testova zeleno (284 provjere). `melos run test` PASS
  (admin 429), analyze i format čisti.
- Nije viđeno uživo: radnik se još ne može prijaviti u aplikaciju — to je task 47.


**`rls-auditor` (2026-09-24), nalazi i ishod:**
- **Deaktiviran radnik je zadržavao pristup** — `is_employee`/`current_employee_id` nisu gledali
  `employees.is_active`. Popravljeno u istoj migraciji (još nije na hostovanom), 5 novih asercija.
- `020` je brojao sve pozive u bazi, a REST test ih je ostavljao — pgTAP je padao na prljavoj bazi.
  `020` broji samo svoje, REST test briše svoje pozive; provjereno REST-om pa pgTAP-om zaredom.
- Dopunjeni negativni slučajevi: otkazivanje termina bez radnika, salona B i nepostojećeg termina,
  nepostojeći termin kroz `set_appointment_status` — ista `42501`.
- Curenja preko granice salona, pristupa samo na osnovu claima, ni puta da radnik sam sebi
  promijeni ulogu/vezu auditor nije našao.

**Ostalo za sljedećeg:** Realtime nad `appointments` nije pokriven testom. `postgres_changes`
poštuje RLS pa `employee_own` važi i tu, ali nijedan test to ne drži — task 47 ga treba vidjeti
uživo (radnik ne dobija događaj za tuđi termin).
