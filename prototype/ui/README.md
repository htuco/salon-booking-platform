# `prototype/ui/` — vizuelni izvor istine

Dizajnerski handoff za mobilnu klijentsku aplikaciju: 17 ekrana, iPhone 402×874, dark, bosanski.
Nacrtan je nad brendom **Barber Studio Vitez**, ali se u ovaj repo uzima kao **bazni dizajn sistem
za sve tenante** — v. odjeljak "Kako se ovo prevodi u multi-tenant" niže.

Ovo je referenca, ne kod. Ekrani se pišu u Flutteru kroz `core_ui` tokene i komponente.

## Šta je gdje

| Putanja | Šta je |
|---|---|
| `SPEC.md` | **Puna specifikacija** — ekrani, komponente, tokeni, ponašanje, stanja. Prvo što se čita. |
| `screens-flat.html` | Svih 17 ekrana kao statični HTML pune dužine, bez okvira i bez JS-a. Samostalan (slike su base64) — otvori u browseru za diffanje uz implementaciju. |
| `screenshots/01…17-*.png` | Referentni PNG-ovi na 2×, puna dužina skrola, u redoslijedu flowa. |
| `assets/ph1–6.png` | **Placeholder** fotografije (čelik/ugalj plate). Nisu finalne — v. "Fotografije". |
| `canvas/` | Prototipni scaffolding. **Ne portuje se.** V. napomenu niže. |

## `canvas/` se ne koristi

`SPEC.md` izričito kaže da se `ios-frame.jsx`, `image-slot.js` i `support.js` ne portuju — to je
mašinerija prototipa (bezel uređaja, slotovi za slike, renderer), ne dizajn.

`Salon App v2.dc.html` uz to **ne radi offline**: traži `_ds/industry-…/_ds_bundle.js` koji nije
došao u paketu. Ako zatreba pan/zoom canvas, mora se ponovo izvesti sa tim bundleom. Do tada
`screens-flat.html` i `screenshots/` pokrivaju istu stvar i rade.

## Kako se ovo prevodi u multi-tenant

Handoff je nacrtan za jedan salon i ima fiksne hex vrijednosti. Platforma je white-label — jedan
codebase, N brendiranih aplikacija iz `tenants/*/tenant.yaml`. Podjela je zato:

- **Oblik je platformski i ide u `core_ui`** — tipografska skala, spacing ritam (22px gutter,
  14/18/20/22/26/34 blok), **radius 0 svuda**, hairline granice umjesto sjenki, visine dodirnih meta
  (≥44px), raspored tab bara, oblik komponenti (service row, time slot, calendar day, spec card,
  step progress, photo frame).
- **Boja je po tenantu i dolazi iz `tenant.yaml`** kroz `buildAppTheme()`. Dark paleta iz `SPEC.md`
  (`#0F1012` podloga, `#F2F2F3` primarni fill, `#C3C9CE` tijelo teksta) je paleta *ovog* brenda,
  ne konstanta sistema. Ne kucaj hex u ekran — ni "privremeno".
- **Tekst je po vertikali.** "Majstori", "Kod koga dolazite?", "Zakažite termin" su barber
  terminologija; dolaze iz `vertical.terms.*`, ne iz stringa u widgetu. V. `docs/05-vertical-packs.md`.

Praktično: ekran koji čita boju iz `Theme.of(context)` i tekst iz `vertical.terms` je tačan;
ekran koji izgleda identično screenshotu jer u sebi ima `#F2F2F3` je greška koja se vidi tek na
drugom tenantu.

## Fotografije

Svih 45 slotova su placeholderi. Trebaju prave fotografije: hero (portret 3:4), thumb usluge
(1:1, 76px), portret radnika (1:1), galerija (1:1), par na "O nama" (1:1), avatar (1:1).

Ikone su **Lucide**, stroke-width 1.5 — isti jezik ikona kao u `prototype/` (`lucide-react`) i u
Flutteru. Fontovi su **DM Serif Display** (naslovi) + **Archivo** (tijelo); pakuju se uz aplikaciju,
ne učitavaju se sa mreže.

## Odnos prema `../wireframe/`

`prototype/wireframe/` je stariji React wireframe — služio je da se flow vidi prije prvog Dart fajla i
**zamrznut je**. Gdje se njih dvoje ne slažu, **`ui/` je jači**: vjernost je viša i copy je
finalan. Prototip ostaje samo kao referenca za flow i za rute.

## Doseg naspram taskova

`SPEC.md` pokriva i ekrane izvan Sprinta 1. Danas su napravljeni `5a`, `5c`–`5g` (početna, četiri
koraka bookinga, zahtjev poslan), pa `5h` i `5p` iz taska 16 (moji termini i modal otkazivanja).

Ostaje `5b`, `5i`–`5o` i `5q` (o nama, usluge, obavijesti, postavke, galerija, recenzije, o
aplikaciji, pravila, lightbox) — v. `tasks/sprint-2/README.md`.

**Tab bar iz `SPEC.md` još ne postoji.** `5h` je napravljen kao *pushed* ekran sa back zaglavljem,
jer tab bar dolazi u [tasku 18](../../tasks/sprint-2/18-pocetna-i-tab-bar.md) i tek tamo ima pet
odredišta. Kad stigne, `5h` gubi back strelicu i dobija svoju ćeliju.

## Fotografije

Šema od taska 22 ima `services.image_url` i `employees.experience_years` — dvije kolone bez kojih
red usluge nikad ne bi bio 1:1 sa mockupom.

**Obje su nullable, i prazan okvir je predviđeno stanje.** Salon koji nema fotografije mora raditi
od prvog dana; `PhotoFrame` tada crta prazan kvadrat sa hairline obrubom, tačno kao u handoffu.

`seed.sql` nosi `images.demo.invalid` URL-ove koji se **namjerno ne razrješavaju**. Demo tako
izgleda onako kako stvarno jeste — bez fotografija — umjesto da tuđim slikama obeća nešto što
sistem nema. Prave fotografije dolaze sa onboardingom klijenta.

Posljedica za dokazivanje: snimak ekrana sa seed podacima **ne razlikuje** „fotografija radi" od
„fotografija tiho pada", jer oba daju prazan okvir. Ko dokazuje rad sa slikama mora privremeno
usmjeriti jedan red na sliku koja stvarno postoji — i ne commitovati taj URL.
### Ekrani koje handoff nema

**Koraci OTP prijave (`/auth/login`, unos emaila i unos koda) nisu nacrtani.** Handoff ima korak 4
(`5f`) kao ekran prijave sa tri dugmeta, ali nijedan ekran iza „Nastavi sa emailom" — a
`docs/06 §2.1` traži šestocifreni kod.

Ta dva koraka su zato **izvedena iz tokena**, ne izmišljena: isti gutter i ritam kao ostatak flowa,
hairline granica, `AppRadius.none`, `AppButton` i `inputDecorationTheme` iz `core_ui`, bez ijedne
nove vrijednosti. Kartica „Čuvamo vam" stoji i na prijavi, jer je prijava dio koraka 4.

Kad handoff dobije te ekrane, mjerodavan je on — ovo je popuna, ne odluka.
Kako izgledaju danas: [`docs/screenshots/task-13-otp-kod.png`](../../docs/screenshots/task-13-otp-kod.png).
