# Handoff: Studio Masaže Mostar — kandidat vertikale „masaža / wellness" (iOS, light + dark)

## Overview
Klijentska aplikacija za masažni studio na postojećoj white-label platformi. **Nije novi dizajn sistem**:
oblik platforme (radius 0, bez sjenki, hairline granice, tab bar, back header, booking flow, komponente)
je isti kao u baznom handoffu (`prototype/ui/`). Mijenjaju se boja, fotografija, tekst
(rječnik vertikale) i tipografija. Sav tekst je bosanski (ijekavica). 18 ekrana, iPhone 402×874 @1x,
svaki u svijetloj i tamnoj temi. Radni naziv „Studio Masaže Mostar" je zamjenjiv.

## About the Design Files
Fajlovi su **dizajn reference u HTML-u** — pokazuju izgled, raspored i ponašanje. Nisu produkcijski kod.
Zadatak je rekreirati ih u okruženju aplikacije (Flutter / SwiftUI / RN) sa njenim postojećim
komponentama i token slojem. Ekrani su isti identifikatori kao bazni handoff (`5a`…`5q`) da se mogu diffati;
`5r` je novi.

## Fidelity
**High-fidelity.** Konačne boje, tipografija, razmaci i tekst. Fotografije su placeholderi sa označenim omjerom.

## Ekrani

| id | Ekran | Svrha | Chrome |
| --- | --- | --- | --- |
| 5a | Početna | Hero 3:4, naslov ispod fotografije, „Rezerviši tretman", izdvojeni tretmani, Naš tim (horizontalno), ocjena, radno vrijeme cijele sedmice, kontakt i adresa, linkovi O nama / Galerija / Recenzije | tab bar, Početna aktivna |
| 5b | O nama | Priča, foto par 1:1, radno vrijeme, kontakt, mreže, sekundarni CTA | tab bar, Početna aktivna |
| 5c | Korak 1 od 4 — Izaberite tretman | Grupe Relaks / Terapeutski / Paketi; izbor dužine **unutar** označenog reda | back „Početna" + progress |
| 5d | Korak 2 od 4 — Kod koga dolazite? | Samo terapeuti koji rade izabrani tretman; izbor obavezan | back „Tretman" |
| 5e | Korak 3 od 4 — Izaberite vrijeme | Mjesečni kalendar → slotovi Prijepodne / Poslijepodne | back „Terapeut" |
| 5f | Korak 4 od 4 — Provjerite i pošaljite | Sažetak, prijava (Apple / Google / email), napomena za terapeuta, pristanak | back „Vrijeme" |
| 5g | Zahtjev poslan | Status „Na čekanju" + šta se dalje dešava. Nije potvrda. | back „Početna", bez tab bara |
| 5h | Moji termini | Predstojeći / Prošli; kartica unutar 12h (otkazivanje onemogućeno + objašnjenje) i kartica na čekanju (otkazivanje dozvoljeno) | tab bar, Moji termini |
| 5i | Tretmani | Puni cjenovnik po grupama; tap → rezervacija sa predizabranim tretmanom (ulazi u 5c) | tab bar, Tretmani |
| 5j | Obavijesti | Potvrda, podsjetnik dan ranije, obavijest studija; nepročitano = pun kvadrat + 600 | tab bar, Obavijesti |
| 5k | Postavke | Profil, nalog, obavijesti (prekidači), jezik, o aplikaciji, pravila, privatnost, odjava, brisanje naloga | tab bar, Postavke |
| 5l | Galerija | 3 kolone 1:1, **ambijent** (sobe, prostor, materijali), 18 slika | back „Početna" |
| 5m | Recenzije | Prosjek 4,9, histogram 5→1, lista (zvjezdice pune vs. obris) | back „Početna" |
| 5n | O aplikaciji | Monogram, verzija, „Kako radi" u 3 koraka, pravni linkovi | back „Postavke" |
| 5o | Pravila korištenja | 6 odjeljaka: rezervacija, otkazivanje 12h, kašnjenje skraćuje tretman, cijene, podaci, kontakt | back „Postavke" |
| 5p | Modal otkazivanja | Destruktivno „Otkaži termin" + „Zadrži termin" | modal preko 5h (blur 1.5px + scrim) |
| 5q | Lightbox galerije | Brojač „4 / 18", zatvori, podijeli, „Prijavi" (zastavica), traka sličica | overlay, tamna podloga u obje teme |
| 5r | Prijavi sliku | Bottom sheet: neprikladno / nije ovaj studio / autorsko pravo / drugo + slobodan tekst | sheet preko 5q |

Dodatna stanja (u `canvas/Masaza App.dc.html`, sekcija „Stanja po elementu"): prazan dan u 5e, email prijava
sa kodom od 6 znakova, 5f sa prijavom i pristankom (CTA aktivan).

## Komponente (oblik = bazni handoff, vrijednosti = tokeni ispod)
- **Tab bar** — 5 jednakih ćelija: Tretmani · Moji termini · **Početna** · Obavijesti · Postavke.
  Aktivna: traka 3px `primaryFill` na vrhu, inset 16% lijevo/desno, label 600 `textBody`. Neaktivna `textMuted` 400.
  Pozadina `surface`, `border-top: 1px hairline`, donji padding 26px.
- **Back header** — `←` 22px + 18px/600 ime ekrana **na koji se vraća**, min 48px. Naslov ekrana je u tijelu (Newsreader 42).
- **Service row** — foto 76×76 (1:1), naziv 19/600, **trajanje 16/600 textBody** (glavna informacija), opis 15 `textMuted`,
  cijena Newsreader 24 (više dužina: „od 70 KM" u listi, „70 / 100 KM" kad je označen).
  Selected: `2px primaryFill`. Pressed: pozadina `disabledFill`.
  **Izbor dužine**: označen red se proširuje (hairline separator + label „Dužina tretmana" + segment 2 ćelije 56px,
  svaka „90 min / 100 KM"). Default = kraća dužina. Nema dodatnog koraka.
- **Kartica terapeuta (5d)** — portret 104×104 1:1, ime Newsreader 26, uloga (rječnik), specijalizacija 16/600 u jednom redu,
  „N godina iskustva", ispod hairline + „Radi: …" (tretmani). Selected: `2px primaryFill` + kvadrat 28px sa kvačicom.
- **CTA** — 60px, pune širine, uglati, label 19/600 Public Sans. Primarni `primaryFill`/`onPrimary`, pressed `primaryPressed`,
  disabled `disabledFill`/`textDisabled`, sekundarni `1px borderStrong`, destruktivni `danger`/`onDanger`, ghost bez okvira.
  Jedan primarni po ekranu.
- **Time slot** — 58px, 3 kolone, gap 10; default `1px border` na `surface`; selected fill `primaryFill`.
- **Dan u kalendaru** — 44px; slobodan `1px border`; izabran fill; prošli `textDisabled` bez okvira;
  dan kad terapeut ne radi `textDisabled` + **precrtan** (razlika i bez boje); danas = crtica 2px ispod broja.
- **List group / spec card** — `1px border` na `surface`, redovi min 60px, padding 16/18, razdjelnik `hairline`, chevron `›` `textMuted`.
- **Status termina** — Na čekanju: **isprekidan** okvir + prazan kvadrat; Potvrđen: pun okvir `primaryFill`; Otkazan: pun fill `textMuted`.
  Kartica termina na čekanju ima i isprekidan vanjski okvir.
- **Step progress** — 4 segmenta 5px, gap 5; urađeno `primaryFill`, preostalo `border`.
- **Photo frame** — nikad zaobljen ni izrezan u krug; `1px hairline`, podloga `photo`.
- **Modal** — pozadinski ekran `blur(1.5px)` + scrim; dijalog inset 20, bottom 120, `1px borderStrong`, `surfaceRaised`.
- **Bottom sheet** — grab handle 52×4 `border`, `border-top 1px borderStrong`, `surfaceRaised`.
- **Checkbox / radio / prekidač** — uglati; checkbox 24px, radio 22px sa unutrašnjim kvadratom 10px, prekidač 50×30 sa kvadratnim knobom.

## Stanja
default / pressed / selected / disabled (45% ili `disabledFill`). Fokus s tastature: unutrašnji uglati prsten 2px `primaryFill`
(`outline-offset:-2px`) i preko fotografije. Zvjezdica ocjene: puna vs. obris. Učitavanje: skeleton blokovi `disabledFill`,
bez spinnera i bez shimmera. Osvježavanje: traka 2px `primaryFill` na vrhu sadržaja, linearno.

## Interakcije i pravila
- **Nalog je obavezan.** Nema gosta. Prijava: Apple, Google ili email (magic link **ili** kod od 6 znakova). Nema prijave telefonom,
  broj telefona se ne traži nigdje. Apple/Google dugmad u produkciji koriste službene stilove provajdera.
- **Izbor terapeuta je obavezan** (`requireStaffChoice`). Nema „Bilo ko od nas". 5d prikazuje samo terapeute koji rade izabrani tretman i dužinu.
- 5e: dani prije danas i dani kad terapeut ne radi nisu interaktivni. Slotovi se računaju za izabranu dužinu (90 min → razmak 90 min);
  ispod slotova „završava u HH:MM". Prazan dan: isprekidan okvir, „Nema slobodnih termina" + prvi slobodan dan kao sekundarno dugme.
- 5f: „Pošalji zahtjev" je onemogućen dok korisnik nije prijavljen **i** nije označio pristanak; razlog stoji iznad dugmeta.
- **Poslije slanja je zahtjev, ne potvrda.** 5g i 5h pokazuju „Na čekanju" dok studio ne potvrdi; potvrda stiže kao obavijest (5j).
- **Otkazivanje do 12h prije termina.** Poslije toga dugme ostaje, onemogućeno, sa objašnjenjem (rok, kad je istekao) i linkom „Pozovi studio".
  Otkazivanje → 5p → potvrda oslobađa termin odmah.
- Galerija → lightbox (5q) → „Prijavi" → 5r. Gost koji tapne „Prijavi" ide na prijavu i vraća se na **istu sliku** (isti `lightboxIndex`), sheet otvoren.
- Tab prelazi bez animacije; bez animacija koje „prodaju".

## State
`draft = { treatmentId, durationMin, staffId (obavezno), date, slot, note, consent:boolean }`, `auth` (null | provider),
`appointmentsTab`, `cancelDialogOpen`, `lightboxIndex`, `reportSheetOpen`, `reportReason`, `reportText`, `emailCode` (≤6).
Backend: tretmani sa **listom dužina i cijena po dužini**, grupa tretmana, terapeuti (portret, specijalizacija, godine iskustva, tretmani),
raspored po terapeutu, termini sa statusom i `cancellableUntil`, galerija, recenzije + histogram, obavijesti, podaci studija (sedmično radno vrijeme).

## Tokeni (kadulja)

| token | light | dark |
| --- | --- | --- |
| background | `#F4EDE3` | `#181613` |
| surface | `#FAF5EE` | `#211E1A` |
| surfaceRaised | `#FFFFFF` | `#2A2621` |
| hairline | `#E4DACC` | `#35302A` |
| border | `#D0C4B3` | `#4A443C` |
| borderStrong | `#8A8072` | `#857B6E` |
| textBody | `#2D2925` | `#EEE8DE` |
| textMuted | `#6A6259` | `#B4AB9F` |
| textDisabled | `#A39B90` | `#6F675D` |
| primaryFill | `#56664F` | `#A7B99C` |
| onPrimary | `#FFFFFF` | `#1B2117` |
| disabledFill | `#E7DED1` | `#2E2A25` |
| *primaryPressed* (izvedeno) | `#46553F` | `#93A688` |
| *danger / onDanger* (platforma) | `#9A3B2E` / `#FFFFFF` | `#E09A8C` / `#1B1512` |
| *scrim* | `rgba(45,41,37,.52)` | `rgba(8,7,6,.66)` |
| *photo placeholder* | `#E5DACA` | `#2C2823` |

Kontrast (light): textBody/bg 12,4:1 · textMuted/bg 5,2:1 · onPrimary/primaryFill 6,2:1 · primaryFill kao link 5,3:1 · borderStrong/bg 3,3:1 (UI).
Dark: onPrimary/primaryFill 7,9:1 · textMuted/bg 8,0:1. Lightbox (5q/5r pozadina) je `#12100E` u obje teme.
Alternativni akcent „glina" je u `canvas/Masaza Tema.dc.html` (nije izabran).

**Mapiranje:** tenant bira samo `primaryFill`; platforma izvodi `onPrimary`, `primaryPressed` i dark vrijednost i automatski potamni/posvijetli
fill ako CTA labela padne ispod 4,5:1. Podloge/linije/tekst dolaze iz vertikale. `danger`, `scrim`, radius i razmaci su zaključani.

Tipografija — naslovi **Newsreader** 400 (optical size auto; 22 / 26 / 32 / 34 / 40 / 42 / 52; brojke 44–58), UI **Public Sans** 400/500/600
(12–20px, line-height 1.45–1.6), kickeri 14/600 uppercase .18em. Spacing — gutter 22; ritam 14/18/20/22/26/34; gap 8 (foto), 10–12 (liste). Radius 0. Sjenke nema.

## Rječnik vertikale (`vertical.terms`)
U prototipu **tačkasto podvučeno** (samo oznaka, ne za produkciju).
`service.singular` Tretman · `service.plural` Tretmani · `staff.m/.f` Terapeut / Terapeutkinja · `staff.section` Naš tim ·
`client` Klijent (nikad „Pacijent") · `cta.book` Rezerviši tretman · `appointment` Termin · `appointments.tab` Moji termini ·
`note.label` Napomena za terapeuta · `note.hint` „Ne upisujte detalje o zdravstvenom stanju — terapeut će vas pitati na licu mjesta."

## Fotografija
Ambijent i ruke, prigušeno svjetlo, lan, drvo, kamen, ulje. Bez golih tijela, bez lica klijenata, bez „before/after".
Omjeri: hero **3:4**, thumb tretmana **1:1**, portret terapeuta **1:1**, galerija **1:1**, O nama par **1:1**. Svaki placeholder ima omjer upisan u sebi.

## Odstupanja od baznog handoffa

| # | Šta | Barber (baza) | Masaža | Razlog |
| --- | --- | --- | --- | --- |
| 1 | Tema | tamna, čelik/ugalj | svijetla topla bjelokost + kadulja; dark kao varijanta | wellness ton, mirno, bez klinički plave |
| 2 | Tipografija | DM Serif Display + Archivo | Newsreader + Public Sans | mekši, tiši naslovi; humaniji UI tekst za cijene i opise |
| 3 | Početna | tekst preko hero fotografije sa gradijentom | hero 3:4 na vrhu, naslov **ispod**; bez gradijenta | čitljivost na svijetloj temi, manje „vikanja" |
| 4 | Početna sadržaj | cjenovnik, galerija, ocjena | + Naš tim, radno vrijeme **cijele sedmice**, kontakt i adresa | povjerenje u terapeuta; klijent planira unaprijed |
| 5 | Tab „Usluge" / „Termini" | Usluge, Termini | Tretmani, Moji termini | rječnik vertikale |
| 6 | Service row | trajanje sekundarno | trajanje 16/600 glavna informacija; više dužina po tretmanu | tretmani 45/60/90 min |
| 7 | Izbor dužine | — | segment unutar označenog reda u 5c | bez novog koraka u flowu |
| 8 | Korak 2 | „Bilo ko od nas" prvi | uklonjeno; kartica sa specijalizacijom, iskustvom, tretmanima | `requireStaffChoice`; povjerenje |
| 9 | Korak 3 | prošli dani neaktivni | + dani kad terapeut ne radi (precrtano), prazno stanje, „završava u" | duži tretmani, raspored po osobi |
| 10 | Korak 4 prijava | Apple / Google / **telefon + OTP** | Apple / Google / **email** (link ili kod); telefon se ne traži | zahtjev vertikale, manje ličnih podataka |
| 11 | Korak 4 sadržaj | prijava + sažetak | + napomena za terapeuta sa hintom, checkbox pristanka | GDPR / zdravstveni podaci se ne prikupljaju |
| 12 | 5g | hero fotografija | bez fotografije; status + 3 koraka | ne slaviti nepotvrđen termin |
| 13 | Otkazivanje | do 2h; dugme nestaje | do **12h**; dugme ostaje onemogućeno + objašnjenje + „Pozovi studio" | duži tretmani, jasnoća |
| 14 | Galerija | radovi | ambijent studija | bez tijela i „before/after" |
| 15 | Prijava slike | — | zastavica u lightboxu + bottom sheet (5r); gost → prijava → ista slika | moderacija sadržaja |
| 16 | Pravila (5o) | kašnjenje | kašnjenje **skraćuje tretman**, cijena ista | sljedeći termin počinje na vrijeme |
| 17 | Tokeni | literal hex | imenovani tokeni + `danger`, `primaryPressed`, `scrim` | mapiranje na tenant |

## Files
- `canvas/Masaza App.dc.html` — svi ekrani (light `5a`…`5r`, dark `5a-d`…`5r-d`), kartica tokena, rječnik, stanja.
- `canvas/Masaza Tema.dc.html` — palete kadulja i glina, light i dark, kontrast, uzorak komponenti.
- `screens-flat.html` / `screens-flat-dark.html` — isti ekrani kao statični HTML pune dužine, bez JS.
- `screenshots/light/01…18-*.png`, `screenshots/dark/01…18-*.png` — 2× (804px), pune dužine; 16–18 odsječeni na 874pt.
  Redoslijed: 01 Početna · 02 O nama · 03–06 koraci 1–4 · 07 Zahtjev poslan · 08 Moji termini · 09 Tretmani · 10 Obavijesti ·
  11 Postavke · 12 Galerija · 13 Recenzije · 14 O aplikaciji · 15 Pravila · 16 Modal otkazivanja · 17 Lightbox · 18 Prijavi sliku.
- `canvas/support.js` — scaffolding prototipa. **Ne portati.**
