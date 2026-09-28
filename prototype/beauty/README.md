# Handoff: tema `elegant_beauty` (svijetla) za klijentsku aplikaciju

## Overview
Klijentska aplikacija za zakazivanje je white-label: jedan kod, više brendiranih aplikacija. Postojeća tema je `barber_dark` (Barber Studio Vitez). Ovaj paket dodaje drugu temu, **`elegant_beauty`**, za frizerske i kozmetičke salone za žene. Demo salon je **Beauty Studio Travnik**, a njegova brand boja je `#B76E79` (sekundarna `#FFF5F5`).

Tema je **tema, a ne jedan salon**. Svi beauty saloni dijele iste neutralne tokene. Iz konfiguracije salona dolazi samo `brand` (i opcionalno `secondary`). Ostale brand uloge tema izvodi sama (algoritam je u nastavku).

Repo: `htuco/salon-booking-platform`, aplikacija `apps/client` (Flutter).

## About the Design Files
Fajlovi u ovom paketu su **dizajn reference napravljene u HTML-u**. To su prototipovi koji pokazuju izgled i ponašanje, a ne produkcijski kod za kopiranje. Zadatak je **ponovo napraviti ovaj dizajn u postojećem Flutter kodu klijentske aplikacije**, po njegovim obrascima: `ThemeExtension`, postojeći widgeti, tenant konfiguracija. Temu treba dodati kao novu varijantu uz `barber_dark`, ne kao zaseban ekran ili zasebnu aplikaciju.

Fajlovi se otvaraju direktno u browseru (`Beauty App.dc.html`, `Beauty Tema.dc.html`). Ako se `support.js` servira preko lokalnog servera (`npx serve`), sve radi.

## Fidelity
**High-fidelity.** Boje, tipografija, razmaci i stanja su finalni. Fotografije nisu finalne: okviri su prazni placeholderi (vidi odjeljak Assets).

### Koji fajl je autoritativan
| Pitanje | Fajl |
|---|---|
| Raspored ekrana, tipografija, veličine | **`Beauty App.dc.html`**, 1:1 isti shell kao barber (5a–5q u `Salon App v2.dc.html`) |
| Paleta, tokeni, kontrast, stanja komponenti, pravac fotografija | **`Beauty Tema.dc.html`** |

> Pažnja: `Beauty Tema.dc.html` crta ekrane sa DM Serif Display + Archivo, sa drugačijim rasporedom Početne. To je **zastarjelo**. Odluka nakon pregleda: beauty tema koristi **Jost** za sav tekst i **isti shell kao barber**. Iz `Beauty Tema.dc.html` koristite samo tokene, komponente i pravila, a ne raspored ni pismo.

## Šta se NE mijenja (platforma, dijeli se sa barber temom)
- Radius **0** svuda: dugmad, kartice, fotografije, slotovi, sheet, dialog.
- Granice od 1px umjesto sjenki. Bez glassmorphisma i bez blura (u barberu je modal imao `blur(1.5px)`, ovdje je uklonjen).
- Bočni gutter **22px**. Vertikalni ritam: 14 / 18 / 20 / 22 / 26 / 34px.
- Dodirne mete ≥44px (standard je 48).
- Tab bar ima 5 ćelija: Usluge · Termini · **Početna** (sredina) · Obavijesti · Postavke. Aktivna ćelija ima traku od 3px na vrhu, uvučenu 16% sa obje strane.
- Booking flow ima 4 koraka i progres od 4 segmenta (visina 5px, razmak 5px): tretman → osoba → vrijeme → prijava.
- Ikone su Lucide, linijske, stroke 1.5, veličina 23 u tab baru.

## Design Tokens

### Neutrale: iste za svaki beauty salon
| Token | Hex | Upotreba |
|---|---|---|
| `surface` | `#FCF9F6` | Podloga ekrana. Topla bijela (lan, ~70° u OKLCH), ne roza, da ne zaprlja zlatni i šljiva brand. |
| `surfaceContainer` | `#F5EFEA` | Kartice, sažetak rezervacije, kartica termina |
| `photoGround` | `#ECE4DC` | Okvir dok se slika ne učita |
| `navSurface` | `#F8F3EE` | Tab bar |
| `outline` | `#DDD2C9` | Rub kartica, redova i slotova (1px) |
| `hairline` | `#EAE2DA` | Separatori unutar liste i tabele |
| `strongOutline` | `#9A8D83` | Rub interaktivnih kontrola (sekundarno dugme, polje, strelice). ≥3:1 na surface. |
| `textPrimary` | `#1F1A17` | Naslovi, cijene, vremena |
| `textMuted` | `#5E554F` | Opisi, trajanja, meta, neaktivne ikone u tab baru |
| `textDisabled` | `#8F847B` | Prošli dani, onemogućeno (namjerno <4.5:1, WCAG izuzima onemogućeno) |
| `disabledFill` | `#ECE6E0` | Onemogućeno primarno dugme / CTA |
| `scrim` | `rgba(31,26,23,.52)` | Iza modala i sheeta, bez blura |
| `error` / `onError` | `#A3352D` / `#FFFFFF` | Otkazivanje, „Izbriši račun", greške |
| `success` | `#2E6A4C` | Status „Potvrđen", tačka „Otvoreno danas" (dodatni token) |

### Brand uloge: izvode se iz `brand` (+ opcionalno `secondary`)
| Token | Ruža (demo) | Bordo `#7A2E3B` | Upotreba |
|---|---|---|---|
| `brand` | `#B76E79` | `#7A2E3B` | Sirova vrijednost iz konfiguracije |
| `brandLine` | `#B76E79` | `#7A2E3B` | Traka 3px u tab baru, fokus prsten 2px, marker „danas", nepročitano |
| `primary` | `#A7606B` | `#7A2E3B` | Primarno dugme / CTA, izabrani slot, izabrani dan, progres |
| `primaryPressed` | `#944F5A` | `#671D2C` | Pritisnuto primarno dugme ili slot |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | Tekst na primary, uvijek bijel |
| `brandContainer` | `#FFF5F5` | `#FFF0F1` | Pozadina izabranog reda (tretman, osoba) |
| `brandInk` | `#A25B66` | `#7A2E3B` | Brand kao tekst: linkovi „Sve slike ›", „Izabrano", aktivna ikona u tab baru |

**Algoritam izvođenja** (implementirajte ga u Dartu, jedna funkcija `BeautyTheme.fromBrand(brand, secondary?)`):
```
contrast(a,b) = WCAG 2.x relativna luminancija
darkenTo(c, bg, target): u OKLCH smanjuj L za 0.004 (isti C i H) dok contrast(c,bg) < target

brandLine      = contrast(brand, surface) >= 3.0 ? brand : darkenTo(brand, surface, 3.05)
primary        = contrast(#FFF, brand)   >= 4.5 ? brand : darkenTo(brand, #FFFFFF, 4.6)
primaryPressed = primary sa L - 0.06
brandContainer = secondary ?? oklch(0.968, min(C_brand*0.2, 0.018), H_brand)
brandInk       = darkenTo(brand, brandContainer, 4.6)
onPrimary      = #FFFFFF
```
Referentna JS implementacija se nalazi u `<script data-dc-script>` na dnu oba HTML fajla (`beautyTheme()`, `toOklch`, `fromOklch`, `darkenTo`). Testni brandovi: Ruža `#B76E79`, Bordo `#7A2E3B`, Pudrasta `#D4A29B`, Zlatna `#B08D57`, Šljiva `#6E3B5C`. Za svaki mora vrijediti `contrast(onPrimary, primary) ≥ 4.5`.

**Zašto primary nije sirovi brand:** bijelo na `#B76E79` daje ~3.8:1, što pada AA za tekst na dugmetu. Tema zato potamni brand.

### Kontrast (izmjereno)
- onPrimary / primary (ruža): 4.6:1 ✓
- textMuted / surface: ~7:1 ✓ · na surfaceContainer ✓ · na photoGround ✓
- brandInk / brandContainer: ≥4.6:1 ✓
- strongOutline / surface: ≥3:1 ✓ (non-text)
- onError / error: ✓

### Tipografija: **Jost** (Google Fonts, 400/500/600/700) za sve
Jost je zamijenio i DM Serif Display (naslovi, cijene, vremena) i Archivo (UI). Veličine su iste kao u barber shellu:

| Uloga | Font |
|---|---|
| Hero naslov (Početna) | Jost 500 52/1.0 |
| Naslov ekrana | Jost 500 42/1.05 |
| O nama naslov | Jost 500 40 |
| Naslov sekcije (Cjenovnik, Galerija…) | Jost 500 32 |
| Mjesec u kalendaru | Jost 500 26 |
| Vrijeme u kartici termina | Jost 500 46–58, line-height 0.85–0.9 |
| Cijena u redu | Jost 500 24 |
| Ocjena (4,8) | Jost 500 44–54 |
| Ime u redu (usluga/osoba) | Jost 600 20–21 |
| Meta u redu | Jost 400 16, textMuted |
| Tekst | Jost 400 17–18 / 1.5–1.6 |
| Dugme / CTA | Jost 600 19 (visina 62–66); CTA Početne 700 21, visina 68 |
| Back header „← Nazad" | Jost 600 18, strelica 22 |
| Kicker | Jost 600 14, letter-spacing 0.18em, UPPERCASE |
| Tab bar label | Jost 12 (400 neaktivno, 600 aktivno) |
| Dani u kalendaru | Jost 500 17, ćelija 44px |
| Slot vremena | Jost 500 22, visina 64 |

## Screens / Views
Svi ekrani su 402×874 @1x (iPhone). Tačne vrijednosti su u `Beauty App.dc.html`. Mapiranje na barber ekrane:

| ID | Ekran | Barber izvor | Napomene |
|---|---|---|---|
| 1a | Početna | 5a | Hero fotografija 430px full-bleed ispod status bara, gradient `surface` (0.72 → 0.12 → 0.78 → 0.97 → 1), naslov „Zakažite termin" i čip „Otvoreno danas do 19:00" (1px textPrimary, kvadrat 9px success). CTA „Rezerviši termin" (68px, primary). Zatim Cjenovnik (3 reda + „Prikaži svih 11 tretmana"), Naš tim, Galerija 3×2 (gap 8), Recenzije. |
| 1b | O nama | 5b | Hero 480px, naziv salona centriran, „frizerski i kozmetički salon od 2016.", outline dugme „Rezerviši". Info box **bez reda Telefon**: demo salon nema telefon. |
| 1c | Korak 1: tretman | 5c | Redovi 76px sa slikom. Izabran red: 2px primary + brandContainer. |
| 1d | Korak 2: osoba | 5d | „Bilo ko iz tima" je uvijek prvi. Stilistica / Koloristica. |
| 1e | Korak 3: vrijeme | 5e | Mjesečni kalendar (7 kolona, ćelija 44) + slotovi 3 kolone (Prijepodne / Poslijepodne). Izabrano: primary fill + onPrimary. |
| 1f | Korak 4: prijava | 5f | Sažetak (surfaceContainer) + Apple / Google / email. |
| 1g | Zahtjev poslan | 5g | Status **„Na čekanju"**, nikad „Potvrđeno". |
| 1h | Moji termini | 5h | Segment Naredni / Prošli. |
| 1i | Usluge | 5i | Puni cjenovnik. |
| 1j | Obavijesti | 5j | |
| 1k | Postavke | 5k | „Izbriši račun" u `error`. |
| 1l | Galerija | 5l | 3 kolone, kvadrati. |
| 1m | Recenzije | 5m | |
| 1n | O aplikaciji | 5n | Bez reda „Telefon salona". |
| 1o | Pravila korištenja | 5o | Kontakt je samo email. |
| 1p | Modal: otkazivanje | 5p | scrim bez blura, dialog na `surface`, 1px outline. |
| 1q | Lightbox | 5q | Svijetla podloga, sličice 56px, aktivna ima 2px primary. |
| 2a | Sheet „Šta nije u redu sa slikom?" | novo | 4 razloga (dodir šalje prijavu), napomena „Prijava ide nama, ne salonu.", „Odustani". |
| 2b | Početna bez ocjena | novo | 0 ocjena → sekcija se **ne prikazuje** (nikad „0,0"). |
| 2c | Recenzije: prazno | novo | Ikona 64px u outline okviru, „Još nema recenzija", mirno. |
| 2d | Galerija: prazno | novo | „Salon još nije dodao fotografije." |

### Namjerna stanja demo salona
- **Radnica bez fotografije** → kvadrat 76px, `surfaceContainer` + 1px `outline`, inicijal u Jost 500 ~30–34, textPrimary.
- **Usluga bez slike** (Pramenovi) → isti inicijal-kvadrat.
- **Nema recenzija** → na Početnoj nema sekcije; ekran Recenzije ima prazno stanje (2c).
- **Nema fotografija u galeriji** → 2d; na Početnoj se ne prikazuje sekcija Galerija.
- **Nema telefona** → nema reda Telefon ni sekcije Kontakt.

### Status termina: razlikuje se oblikom, ne samo bojom
- **Na čekanju**: 1px **isprekidan** rub u textPrimary, ikona sata.
- **Potvrđen**: 1px pun rub u `success`, kvačica.
- **Otkazan**: bez ruba, ispuna `surfaceContainer`, textMuted, ✕.

## Interactions & Behavior
Ista navigacija kao barber tema:
- Back header „← Nazad" / „← Početna" vraća na prethodni ekran.
- Korak 3: dodir na dan postavlja `selectedDay`. Prošli dani nisu klikabilni. Dodir na slot postavlja `selectedSlot`. CTA je onemogućen (`disabledFill` / `textDisabled`) dok slot nije izabran; tada glasi „Dalje · HH:MM".
- Primarno dugme: pritisnuto = `primaryPressed`; fokus = 2px `brandLine` prsten, offset 2.
- Sekundarno dugme: 1px `strongOutline`; pritisnuto = `surfaceContainer`.
- Sheet za prijavu slike: dodir na razlog odmah šalje prijavu (bez dodatne potvrde), sheet se zatvara.
- Tranzicije: kao u barber temi (vidi `tasks/FE-201`).

## State Management
Nema novog stanja. Tema se bira iz tenant konfiguracije:
```
tenant.theme = 'elegant_beauty' | 'barber_dark'
tenant.brandColor = '#B76E79'
tenant.secondaryColor = '#FFF5F5' // opcionalno
tenant.hasPhone / hasReviews / hasGallery → uslovno prikazivanje sekcija
```

## Terminologija (beauty, ženski rod)
Klijentica/Klijentice, Stilistica (Koloristica, Kozmetičarka), Naš tim, Tretman, Termin, „Rezerviši termin", „Moji termini", „Napomena", „Bilo ko iz tima". **Nigdje** „Majstor", „Barber" ni „Klijent". Stringovi trebaju ići kroz tenant/theme l10n ključeve, ne kroz hardkodiranje.

## Assets
- **Fotografije:** svi okviri su prazni placeholderi. Pravac za fotografije (svjetlo, boja, kadar, pozadina i 8 opisa kadrova) nalazi se u `Beauty Tema.dc.html` → sekcija 6. Ukratko: dnevno meko svjetlo, 5000–5500K, detalj (ruke, kosa, nokti), topla bijela pozadina, **bez lica klijentica**. Lica se prikazuju samo kod članica tima.
- **Ikone:** Lucide (scissors, calendar, house, bell, user…), stroke 1.5.
- **Logo i cover** dolaze od salona i nisu dio teme.

## Files
- `Beauty App.dc.html`: svih 21 ekran u iOS okviru (autoritativno za raspored i pismo). U Tweaks panelu se bira brand boja (Ruža / Bordo / Pudrasta / Zlatna / Šljiva).
- `Beauty Tema.dc.html`: paleta, tabela tokena, kontrast, komponente u svim stanjima, poređenje sa barber temom, pravac fotografija.
- `ios-frame.jsx`, `image-slot.js`, `support.js`, `_ds/…`: podrška za prikaz (nije za implementaciju).
- Barber referenca za poređenje: `Salon App v2.dc.html` u korijenu projekta (ekrani 5a–5q).
