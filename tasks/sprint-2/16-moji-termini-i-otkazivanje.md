# Task 16 — Client: "Moji termini" + otkazivanje

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | 25 (push vodi na ovaj ekran) |
| **Reference** | `prototype/ui/SPEC.md` 5h i 5p · [01 §8.3](../../docs/01-mvp-spec.md) |

## Cilj
Korisnik vidi šta je zakazao, u kojem je statusu, i može otkazati dok mu pravila to dozvoljavaju.
Success ekran iz taska 11 konačno ima gdje da vodi.

## Definicija gotovog
- [x] `/appointments` po `SPEC.md` 5h: tabovi **Predstojeći / Prošli**, status po terminu
- [x] `AppointmentRepository` u `core_api` — prvi put postoji
- [x] Otkazivanje kroz modal 5p: blur + scrim, destruktivna akcija i „Zadrži termin"
- [x] **Rok za otkazivanje iz `vertical.rules.minCancelHours`**, ne iz konstante; nakon roka je
      dugme onemogućeno sa objašnjenjem koje nosi tačan broj sati
- [x] Otkazan slot se **odmah oslobađa** — provjereno i pgTAP-om i `get_available_slots` upitom
- [x] Prazno stanje: nema termina → poziv na booking, ne prazan ekran
- [x] Widget testovi: dva taba, otkazivanje, zabrana nakon roka

## Koraci
1. Politika i RPC za otkazivanje prvo (`supabase/`), pa repozitorij, pa ekran
2. Ekran po handoffu; modal je nova `core_ui` komponenta (`AppDialog`)
3. Commit: `feat(client): moji termini i otkazivanje`

## Zamke
- **Otkazivanje je upis** — ide kroz RPC sa provjerom vlasništva i roka, nikad `update` sa klijenta.
- `cancelled_by` mora reći **ko** je otkazao (`customer` / `salon` / `system`); admin ekran i
  statistika kasnije zavise od toga.
- `pending` koji je istekao je `system` otkazivanje, ne korisnikovo.

---

## Status (2026-09-12) — ✅ zatvoren

`/appointments` postoji i radi protiv prave baze. Success ekran iz taska 11 konačno ima gdje da
vodi, a otkazivanje ide kroz `cancel_appointment` — treći i zadnji upis kojim klijentska app dira
bazu.

### Šta je isporučeno

| Sloj | Šta |
|---|---|
| `supabase` | `20260912140000_cancel_appointment.sql` — rok iz `salon_settings.min_cancel_hours`, `cancelled_by`, idempotentno. |
| `supabase` | `004_cancel_appointment.test.sql` — 15 pgTAP testova. |
| `core_api` | `AppointmentRepository` (čitanje `from(...)`, otkazivanje `rpc`), `myAppointmentsProvider`. |
| `core_ui` | `AppDialog` — modal 5p sa blurom, scrimom i destruktivnom akcijom gore. |
| `apps/client` | `features/appointments/` — ekran sa dva taba, kartica, razvrstavanje i otkazivanje. |

### Dokazano

```
$ ./tool/test_supabase.sh
==> pgTAP                        Files=4, Tests=97,  Result: PASS   (bilo 82)
==> REST izolacija               24 assertions, two real JWTs.
==> Javni katalog                26 assertions passed.
==> Upsert klijenta i rezervacija 20 asercija, stvaran JWT, stvaran 409.
==> Izolacija izmedju salona     22 asercija, tri stvarna JWT-a.

$ melos run format && melos run analyze && melos run test
  SUCCESS; 276 testova PASS (bilo 256), od toga 115 u `client` (bilo 103)
```

**Odigrano u browseru protiv živog stacka**: prijava emailom → rezervacija 22.09. u 13:00 →
„Moji termini" → otkazivanje kroz modal.

```
$ psql -c "select status, cancelled_by, date, start_time from public.appointments;"
 cancelled | customer | 2026-09-22 | 13:00:00

$ psql -c "select exists(select 1 from public.get_available_slots(...) where start_time='13:00');"
 t
```

Otkazan slot je **odmah slobodan**, i to je provjereno upitom, ne pretpostavkom. Termin je prešao
u tab „Prošli" sa statusom „Otkazano" i bez dugmeta za otkazivanje.

Slike: [`task-16-moji-termini.png`](../../docs/screenshots/task-16-moji-termini.png),
[`task-16-modal-otkazivanje.png`](../../docs/screenshots/task-16-modal-otkazivanje.png).

### Tri nalaza iz pgTAP-a

**1. Ista NULL rupa kao u tasku 14, i u `book_appointment` iz taska 05.** Guard oblika
`not (… and p_salon_id = private.client_salon_id() and …)` se **ne izvrši** kad header fali:
poređenje je `NULL`, `true and NULL` je `NULL`, a `if NULL then` se preskače.

**Nije curenje i nikad nije bilo** — za tuđeg klijenta je `private.owns_identity(...)` `FALSE`, a
`NULL and FALSE` je `FALSE`, pa guard radi. Provjereno pokretanjem: napadač bez headera koji
rezerviše u ime tuđeg klijenta dobija `42501`. Rupa se otvara samo kad je pozivalac **stvarni
vlasnik**, jer su tek tada svi ostali konjunkti `TRUE`. Posljedica je da zahtjev bez headera prođe
tamo gdje `security.md` tvrdi da mora pasti.

Zatvoreno kroz `create or replace` nad **doslovnim** tijelom iz taska 05 — diff pokazuje da je
promijenjen samo guard. `002_availability` iz taska 05 i dalje prolazi.

**2. Moj test je tvrdio pogrešnu stvar.** Očekivao je `42501` na direktan `update` sa klijenta, a
RLS ga pretvori u **nula pogođenih redova** — što u Postgresu nije greška. `authenticated` *ima*
`update` grant na `appointments`; ono što ga zaustavlja je odsustvo klijentske `for update`
politike. Asercija je prepisana na učinak: red ostaje netaknut. (`insert` bi bacio, jer ga hvata
`with check`.)

**3. Rok vrijedi za klijenta, ne za salon.** Prvo izdanje funkcije je primjenjivalo
`min_cancel_hours` na sve. Salon otkazuje kad mora — bolest, kvar — i tada klijent dobije
obavijest, ne zabranu.

### Odluke koje se ne vide iz potpisa

- **Granica između tabova nije u upitu** nego u `splitAppointments`: „prošlo" zavisi od trenutka
  gledanja, koji se pomjera između dva otvaranja ekrana. Upit koji bi vraćao samo buduće bi uz to
  morao znati zonu salona — a to zna baza.
- **Zatvoren termin ide u „prošle" bez obzira na datum.** Otkazan termin za sljedeću sedmicu nije
  nešto na šta korisnik dolazi.
- **Rok se na ekranu samo prikazuje.** Odlučuje baza; dugme je onemogućeno unaprijed da korisnik ne
  dobije grešku na ono što se vidjelo da neće proći. Kad se njih dvoje raziđu, baza je u pravu.

### Šta **nije** provjereno

- **Ništa na uređaju ni u emulatoru** — dokaz je web build, pgTAP i widget testovi.
- **Istekao `pending` (`cancelled_by = 'system'`)** nema ko da napiše — scheduler je Sprint 3.
  Ekran ga prikazuje ako se pojavi, ali nije viđen uživo.
- **Detalj termina i tab bar** (`SPEC.md` 5h nosi i jedno i drugo) su
  [task 18](18-pocetna-i-tab-bar.md) — ovdje je lista.
- **CI nije ništa potvrdio** — naplata blokira workflowove do 29.09.2026.
