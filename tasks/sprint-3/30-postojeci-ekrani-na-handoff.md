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
- [x] `/login` po `3j` (desktop) i `3u` (telefon); auth ostaje Supabase email + lozinka
- [x] `/dashboard` po `3b` / `3k` — „Danas"
- [x] Pending prikaz po `3d` / `3m`, unutar postojećih termina
- [x] Detalj termina po `3n`, sa postojeće četiri akcije
- [x] **Nijedna RPC putanja nije promijenjena** — `set_appointment_status`, `cancel_appointment` i
      `book_appointment` rade kao od taska 24; jedini novi upit je `select` (`byId`)
- [x] Postojeći admin testovi i dalje prolaze; novi testovi za ono što ekran sad prikazuje
      (broj iz DoD-a je bio zastario: 85 prije ovog taska, ne 27)
- [x] Prolaz uz **pravu prijavu** — Android emulator (API 35) protiv hostovanog projekta:
      prijava seed nalogom, „Danas" sa pravim terminima, detalj termina
- [ ] 🟡 **Drugi tenant** — `admin@beautystudiotravnik.test` na hostovanom projektu ne postoji
      (`POST /auth/v1/token` → 400), pa se „druga prijava, nijedan tuđi termin" ne može odigrati

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

## Status (2026-09-19)

Sva četiri ekrana su prevedena na handoff i **viđena u browseru na obje širine** —
`docs/screenshots/task-30-admin-*.png` (prijava, Danas, zahtjevi, termini, detalj).

**Šta je urađeno.** `/login` je dobio podjelu iz `3j` (bijela kolona 560 px + tamna ploha koja
uzima ostatak) i telefonski oblik iz `3u`. `/dashboard` se zove „Danas", ima naslov dana, tri
kartice metrika, tabelu rasporeda i kolonu sa zahtjevima i zauzetošću; telefon isti sadržaj kao
kartice ispod vlastitog zaglavlja. `/appointments?status=pending` je ekran zahtjeva iz `3d`/`3m`,
a `/appointments/:id` je **prvi put pravi ekran** (`3n`) umjesto placeholdera. Ljuska je dobila
breadcrumb `Vitez / Danas` (ime iz novog `adminSalonProvider`-a), akcije top bara i mogućnost da
telefonski ekran nosi svoje zaglavlje.

**Šta canvas traži, a namjerno nije nacrtano** — dvanaest stavki sa razlogom i taskom u kojem se
vraćaju, upisano u `prototype/admin/SPEC.md` („Šta canvas crta, a aplikacija namjerno nema").
Najvažnija: brojke „6 lokacija · 19 majstora · 84 termina" na ekranu prijave nisu demo sadržaj nego
**zbir preko svih salona**, koji `salon_admin` po RLS-u ne smije vidjeti, a ekran prijave bi ih
tražio neprijavljen.

**Greške koje je našao ekran, a testovi nisu mogli:** zauzetost je pisala „3 3 termina" (pomoćna
funkcija već nosi broj, a test je gledao podniz), telefonska prijava je imala dugme širine svog
teksta nasred ekrana (kolona bez `stretch`), i desktop prijava je crtala logotip dvaput. Uz to je
prvi prolaz brojao termine po `status.blocksSlot`, koje je `false` za završen termin — „6 termina"
je pokazivalo 5, a majstor koji je sve odradio izgledao prazan.

**Dokazano:** `melos run analyze` čist, `melos run test` **642 testa** (admin **145**, bilo 85),
`dart format` bez izmjena. Svi novi testovi provjereni da mogu pasti; kod „zatvoren termin nema
nijednu radnju" je trebalo oboriti **sva tri** čuvara da test pukne, i to je ovdje zapisano jer
znači da test pokriva svojstvo, ne jednu granu.

**Prava prijava je odigrana — pretpostavka iz taska 29 nije bila tačna.** Tamo stoji da hostovani
projekat „ima šemu, ali nije bilo naloga"; seed nalog `admin@barberstudiovitez.test` /
`admin123456` **postoji i prijava prolazi**. Tok je odigran na **Android emulatoru (API 35)**
protiv hostovanog Supabasea: prijava, „Danas" sa pravim terminima iz baze, pa detalj termina —
`docs/screenshots/task-30-admin-uredjaj-*.png`. Time pada i dug iz taskova 28 i 29 („nije viđeno
uz pravu prijavu"), ne samo iz ovog.

**Uređaj je našao grešku koju nijedan test i nijedan web snimak nisu:** ćelija „Zahtjevi" u donjoj
navigaciji je nosila **crvenu tačku iako nema nijednog zahtjeva**. `Badge` je bio uvijek vidljiv, a
Material prazan `label` iscrta kao tačku — salon bez ijednog zahtjeva je tako dobijao znak da ga
nešto čeka. Web snimci to nisu pokazali jer je demo uvijek imao zahtjeve na čekanju. Popravljeno i
pokriveno testom koji gleda **postojanje `Badge`-a**, ne teksta u njemu.

**Ostalo za sljedećeg (🟡).** Drugi tenant: `admin@beautystudiotravnik.test` na hostovanom projektu
**ne postoji** (`POST /auth/v1/token` vraća 400), pa se „ista aplikacija, druga prijava, nijedan
tuđi termin" još ne može odigrati uživo — izolacija je i dalje dokazana samo pgTAP-om i Deno
testovima. Uz to app **nije pokrenuta na fizičkom uređaju**; emulator nije telefon (nema pravog
dodira, mreže ni notifikacija). iOS ostaje nedostupan jer je ova mašina Windows.
