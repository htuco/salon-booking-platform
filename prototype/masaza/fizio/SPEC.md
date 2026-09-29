# Handoff: Fizio Centar Zenica — tenant vertikale „masaža / wellness" (iOS, light + dark)

## Overview
Drugi tenant iste vertikale kao **Studio Masaže Mostar** (`prototype/masaza/`). Oblik, raspored, pisma,
komponente, interakcije i state su **identični** — ovaj dokument navodi samo razlike. Za sve što ovdje nije navedeno
važi masaža SPEC. Radni naziv „Fizio Centar Zenica" je zamjenjiv. 15 ekrana, iPhone 402×874 @1x, svaki light i dark.

## About the Design Files
HTML dizajn reference, ne produkcijski kod. Rekreirati u postojećem kodu aplikacije; fizio je **konfiguracija tenanta**
(tokeni + `vertical.terms` + feature flagovi + sadržaj), ne nova grana UI-ja.

## Fidelity
High-fidelity. Fotografije su placeholderi sa upisanim omjerom.

## Ekrani
Isti identifikatori kao masaža, da se mogu diffati. **Galerija je isključena** (`features.gallery = false`):
5l Galerija, 5q Lightbox i 5r Prijavi sliku ne postoje, a na Početnoj nema reda „Galerija".

| id | Ekran | Razlika u odnosu na masažu |
| --- | --- | --- |
| 5a | Početna | nema reda Galerija; „Izdvojene terapije"; CTA „Zakaži termin" |
| 5b | O nama | tekst i fotografije tenanta |
| 5c | Korak 1 od 4 — Izaberite terapiju | grupe tenanta: Pregled i vježbe / Fizikalna terapija / Paketi |
| 5d | Korak 2 od 4 — Kod koga dolazite? | podnaslov „Manuelna terapija · 45 min — rade je ova tri terapeuta." |
| 5e | Korak 3 od 4 — Izaberite vrijeme | slotovi za 45 min |
| 5f | Korak 4 od 4 | „Razlog dolaska" + kratak hint |
| 5g | Zahtjev poslan | „Čeka potvrdu centra" |
| 5h | Moji termini | — |
| 5i | Terapije | — |
| 5j | Obavijesti | — |
| 5k | Postavke | „pacijent od 2026." |
| 5m | Recenzije | — |
| 5n | O aplikaciji | monogram „FC" |
| 5o | Pravila korištenja | kašnjenje skraćuje terapiju; razlog dolaska vidi samo terapeut |
| 5p | Modal otkazivanja | „…za druge pacijente" |

## Tokeni

| token | light | dark |
| --- | --- | --- |
| background | `#F4F7F5` | `#131817` |
| surface | `#FFFFFF` | `#1A2020` |
| surfaceRaised | `#FFFFFF` | `#212828` |
| hairline | `#DDE5E1` | `#2C3534` |
| border | `#BCC9C4` | `#404B49` |
| borderStrong | `#7E8B87` (3,3:1 prema bg) | `#76837F` (4,5:1) |
| textBody | `#1F2929` | `#E6EDEB` |
| textMuted | `#586264` | `#A5B0AD` |
| textDisabled | `#9AA5A2` | `#5F6B68` |
| primaryFill | `#2F6F6D` | `#8CC3BF` |
| onPrimary | `#FFFFFF` (5,8:1) | `#0E2221` (8,4:1) |
| primaryPressed | `#2C6261` (fill + 18% textBody) | `#7DAEAB` (fill + 12% bg) |
| disabledFill | `#E4EAE7` | `#252D2C` |
| photo placeholder | `#E9E1D4` (topli sand — jedino mjesto topline) | `#2E2A24` |
| danger / onDanger (platforma) | `#9A3B2E` / `#FFFFFF` | `#E09A8C` / `#1B1512` |
| scrim | `rgba(31,41,41,.52)` | `rgba(6,8,8,.66)` |

Kontrast (light): textBody/bg 13,8 · textMuted/bg 5,8 · textMuted/surface 6,3 · textMuted/photo 4,8 · onPrimary/pressed 6,9 ·
primaryFill kao link 5,4. Sve obavezne kombinacije ≥ 4,5:1 (UI granica ≥ 3:1). Puna tabela u `canvas/Fizio App.dc.html`.
**Nema novih uloga.** Sage `#8FA9A0` i sand `#D8C4A8` se ne koriste za tekst, stanje ni aktivne elemente.

## Rječnik (`vertical.terms`, override tenanta)
`service` Terapija / Terapije · `service.acc` terapiju · `service.pronoun` je (ž.) · `staff` Terapeut / Terapeutkinja ·
`client` Pacijent · `cta.book` Zakaži termin · `note.label` Razlog dolaska · `note.hint` „Ne upisujte detalje o zdravstvenom stanju." ·
`venue` centar (umjesto „studio": „Čeka potvrdu centra", „Pozovi centar", „Obavijesti centra").
Naziv terapije iz baze uvijek ostaje u nominativu; gramatika okolnog teksta se slaže preko `service.pronoun`/`service.acc`.

## Fotografija
Čista terapijska sala i oprema, dnevno svjetlo. Bez lica pacijenata. Portreti terapeuta 1:1 su dozvoljeni. Omjeri kao masaža
(hero 3:4, thumb 1:1, portret 1:1, O nama par 1:1).

## Odstupanja od masaža handoffa
1. Tokeni tenanta (tabela gore) — hladna neutralna podloga i petrolej umjesto bjelokosti i kadulje; razlog: profesionalniji ton ordinacije.
2. `features.gallery = false` → 5l, 5q, 5r i red „Galerija" na Početnoj se ne renderuju.
3. Rječnik (gore), uključujući `venue` i gramatičke oblike.
4. Sadržaj tenanta (naziv, adresa, katalog terapija, tim, recenzije) — podaci, ne dizajn.
Oblik, pisma, razmaci, komponente i ponašanje: **bez odstupanja.**

## Files
- `canvas/Fizio App.dc.html` — svi ekrani light + dark (`5a`…`5p`, `-d`), kartica tokena sa kontrastom, tabela razlika.
- `screens-flat.html`, `screens-flat-dark.html` — statični HTML pune dužine.
- `screenshots/light/`, `screenshots/dark/` — PNG 2×, numeracija kao masaža (12, 17, 18 izostavljeni jer nema galerije).
- `canvas/support.js` — scaffolding prototipa, ne portati.
