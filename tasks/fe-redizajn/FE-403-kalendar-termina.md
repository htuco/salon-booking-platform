# FE-403 — Kalendar termina

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/calendar/calendar_screen.dart` · `prototype/adminv2/export/3c-kalendar-dana.png`, `3l-telefon-kalendar.png` |

## Cilj
Dnevni i sedmični prikaz po radniku, sa odobravanjem i odbijanjem zahtjeva.

## Zatečeno stanje
Najveći ekran u adminu (`calendar_screen.dart`, preko 1600 redova) i **jedini koji već računa
raspored po dostupnoj širini**: `constraints.maxWidth - _sirinaOse` dijeli prostor na kolone. To je
temelj na kojem FE-406 gradi, ne kod koji treba zamijeniti.

Sedmični prikaz danas **ne postoji** — postoji dnevni ([task 31](../sprint-3/31-kalendar-dana.md)).
To je jedina stavka ovog taska koja je nova funkcionalnost, ne redizajn, i zato nosi najviše rizika.

## Definicija gotovog
- [ ] **Prebacivanje dan / sedmica** — *izostavljeno, v. „Šta je izostavljeno i zašto"*
- [x] Kolone po radniku, termin je blok sa oštrim ivicama — zatečeno iz taska 31
- [x] Zahtjevi na odobrenju vizuelno odvojeni (isprekidan rub)
- [x] Preklapajući termini idu jedan pored drugog, nikad jedan preko drugog — zatečeno
- [ ] **Odobravanje na realtime signal** — *izostavljeno, v. niže*
- [x] Kolone se raspoređuju po dostupnoj širini i na 2560 px — zatečeno iz FE-406

## Zamke
- **Sedmični prikaz je nova funkcionalnost unutar vizuelnog epika.** Ako sprint pukne, puca on, a
  dnevni ostaje — tako i planirati.
- Termin nosi `buffer_minutes` **sa sebe**, ne iz postavki: pauza upisana u trenutku rezervacije se
  ne mijenja kad salon promijeni postavku. Blok koji crta pauzu iz `salon_settings` pomjera već
  dogovorene termine.
- Preklapanje se ne rješava sortiranjem po početku; dva termina istog radnika u isto vrijeme baza
  ne dozvoljava (exclusion constraint), ali dva **različita** radnika u istoj koloni znače da je
  kolona pogrešno izvedena.

## Status

**Redizajnerski dio gotov i dokazan**, grana `feat/fe-403-kalendar-termina`,
[PR #72](https://github.com/htuco/salon-booking-platform/pull/72) (draft). Dvije DoD stavke su
svjesno izostavljene — obje su funkcionalnost, ne redizajn; v. odjeljak ispod.

**309 testova pass** (bilo 306), čista analiza i format. Viđeno uživo na 1440×900 i 402×874, i u
tamnoj temi.

## Šta je zatečeno, a šta je stvarno urađeno

Ekran je bio **već ispunjen do četiri od šest DoD stavki** iz taska 31 i FE-406: kolone po radniku,
preklapanje kroz trake (`StavkaKalendara.traka`/`brojTraka`), raspodjela po dostupnoj širini i
mobilna lista. Provjereno u kodu prije pisanja, nije dirano.

Jedina stvarna rupa bio je **isprekidan rub oko zahtjeva na odobrenju**. Do sada se `pending` od
`confirmed` razlikovao samo nijansom podloge, a na mreži sa pet statusa to nije nosilo razliku
koja vlasniku mijenja radnju: potvrđen termin se gleda, zahtjev se rješava. Rub nosi razliku
**oblikom**, pa radi i kad boje nema (WCAG 1.4.1) — isto kao što šrafura nosi neradno vrijeme.

Rub ide na sva tri mjesta: mreža `3c`, mobilna lista `3l` i **uzorak u legendi**. Legenda koja
crta samo boju uči pola pravila.

`RubZahtjeva` je javan namjerno: test pita njegov `ceka`, umjesto da pogađa tip privatnog
painter-a ili da hvata `foregroundPainter` — koji i `Material` postavlja za svoj oblik, pa je prva
verzija testa bila zelena i za potvrđen termin.

## Šta je izostavljeno i zašto

- **Prekidač `Dan · Sedmica · Mjesec`.** Stoji u tabeli izostavljanja u `prototype/admin/SPEC.md`
  („dvije od tri opcije ne bi radile"), a i sam task ga priznaje kao *jedinu stavku koja je nova
  funkcionalnost, ne redizajn*. Ulazak bi tražio **ADR**, jer `SPEC.md` trenutno tvrdi suprotno —
  to je izmjena opsega, ne usputna promjena koda.
- **Osvježavanje na realtime signal.** U `calendar_*` nema nijedne `stream`/`channel` putanje, a
  epik FE-4 izričito piše da nijedan task u njemu ne mijenja upit ni ponašanje rezervacije.

Obje ostaju **imenovan dug**, ne tiho preskočene stavke. Sedmični prikaz je i po zamkama ovog
taska bio prvi kandidat da ispadne ako sprint pukne.
