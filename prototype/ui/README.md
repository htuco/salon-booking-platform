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
  (≥44px), raspored tab bara (`AppBottomNav`: pet ćelija, Početna u sredini, traka 3px uvučena
  16% iznad aktivne), oblik komponenti (service row, time slot, calendar day, spec card,
  step progress, photo frame, star rating, back header).
- **Boja je po tenantu i dolazi iz `tenant.yaml`** kroz `buildAppTheme()`. Dark paleta iz `SPEC.md`
  (`#0F1012` podloga, `#F2F2F3` primarni fill, `#C3C9CE` tijelo teksta) je paleta *ovog* brenda,
  ne konstanta sistema. Ne kucaj hex u ekran — ni "privremeno".
- **Tekst je po vertikali.** "Majstori", "Kod koga dolazite?", "Zakažite termin" su barber
  terminologija; dolaze iz `vertical.terms.*`, ne iz stringa u widgetu. V. `docs/05-vertical-packs.md`.

### Pushed ekran nosi back header, ne `AppBar`

`SPEC.md` §Bottom tab bar: pushed ekrani imaju „a back header (`←` 22px + 18px/600 label,
min-height 48px)". To znači **ime ekrana na koji se vraća** pored strelice, a naslov ekrana u
tijelu kao veliki serif (`displaySmall`) — tako crta i `12-galerija.png` („← Početna", pa
„Galerija") i `13-recenzije.png`.

Materialov `AppBar` daje mali sans naslov i platformski chevron. Razlika je upola manji naslov i
tuđa ikona, ne vidi se ni u jednom testu, i vidi se u sekundi kad ekran stoji pored Cjenovnika.
Komponenta je `BackHeader` u `core_ui`; `AppBar` u ekranu je greška.

### Zvjezdica je nacrtana, ne ikona

`StarRating` u `core_ui` crta zvjezdicu kroz `CustomPainter`, iako je ostatak ikona Lucide.
Razlog je što **Lucide nema popunjenu zvjezdicu** — cijeli set je linijski. Prva verzija je zato
punu od prazne razlikovala samo bojom obrisa, i na živom ekranu su kartica sa peticom i kartica sa
četvorkom izgledale isto (izmjereno: 2,4% razlike u svjetlini po zvjezdici, a polovina se crtala
identično kao puna).

Puna je sada **ispunjena površina**, prazna je **obris**. Razlika nošena samo bojom je i WCAG 1.4.1
problem: ocjena je informacija, a informacija se ne smije prenositi isključivo bojom. Boja i dalje
dolazi iz teme (`onSurface` / `onSurfaceVariant`), nikad iz palete handoffa.

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
koraka bookinga, zahtjev poslan), `5h` i `5p` iz taska 16 (moji termini i modal otkazivanja), te
`5b` i `5i` iz taska 19 (o nama, usluge).

Ostaje `5j`–`5o` i `5q` (obavijesti, postavke, galerija, recenzije, o aplikaciji, pravila,
lightbox) — v. `tasks/sprint-2/README.md`.

### Dva odstupanja od handoffa na `5b`, oba svjesna

- **Radno vrijeme je puna sedmica, ne jedan red.** `02-o-nama.png` ga svodi na „Radno vrijeme ·
  09:00 – 20:00", što je tačno samo za salon koji svaki dan radi isto. Demo barber radi subotom
  do 14:00 i nedjeljom ne radi — jedan red bi lagao, i to bi se otkrilo pred zatvorenim vratima.
- **Sadržaj `5b` je i na Početnoj, inline.** Handoff ekran 5b opisuje, ali mu **nijedan nacrtani
  ekran ne daje ulaz** — ni `5a`, ni Postavke. Priča, radno vrijeme i kontakt su podaci zbog kojih
  se salon otvara na telefonu, pa stoje na `5a`; `/about` ostaje kao ruta i kao oblik iz handoffa.
  Sekcije dijele obje strane (`features/about/about_sections.dart`), pa ne postoje dvaput. Foto par
  je pri tome **samo na `/about`**: na Početnoj bi ponovio prve dvije slike iz Galerije iznad njega.

## Fotografije

Šema od taska 22 ima `services.image_url` i `employees.experience_years` — dvije kolone bez kojih
red usluge nikad ne bi bio 1:1 sa mockupom.

**Obje su nullable, i prazan okvir je predviđeno stanje.** Salon koji nema fotografije mora raditi
od prvog dana; `PhotoFrame` tada crta prazan kvadrat sa hairline obrubom, tačno kao u handoffu.

**Od 2026-09-13 su dva demo salona namjerno u različitim stanjima**, jer jedan seed ne može
istovremeno pokazati pun ekran i prazan okvir:

- **Barber Studio Vitez je pun.** Hero, galerija od dvanaest slika, portret oba majstora,
  fotografija na svakoj usluzi i 25 ocjena sa četiri napisane recenzije — sve Unsplash URL-ovi
  (licenca dozvoljava komercijalnu upotrebu bez
  atribucije). Uz to adresa, telefon, mail i mreže, **svi izmišljeni**; ne pripadaju nikome i ne
  zovu se. Ovaj salon postoji da se Početna može vidjeti onako kako je salon vidi.
- **Beauty Studio Travnik je prazan** i tu ostaje. `Pramenovi` nemaju `image_url`, Amina i Lejla
  nemaju fotografiju. Prazan okvir je **predviđeno stanje** i mora biti vidljivo u demou, inače se
  otkrije tek kod prvog klijenta bez fotografija.

Fotografije stoje kao **daljinski URL-ovi, ne kao spakovani assets**: Flutter nema asset po
flavoru, pa bi trinaest fotografija jednog demo salona ušlo u build svakog tenanta. Cijena je da
demo bez interneta pokazuje prazne okvire — isto stanje koje salon bez fotografija ionako ima.

Posljedica za dokazivanje, sada uža nego prije: **na beautyju** snimak ekrana i dalje ne razlikuje
„fotografija radi" od „fotografija tiho pada", jer oba daju prazan okvir. Na barberu razlikuje.
### Gdje Početna namjerno odstupa od `01-pocetna.png`

Četiri odstupanja na jednom ekranu, sva po pravilima iznad, da se ne ispravljaju kao greške:

- **Serif naslov u heroju je ime salona, ne „Zakažite termin".** Handoff na tom mjestu ima poziv
  na akciju, a dugme odmah ispod isti taj tekst u drugom licu. `docs/02 §3` traži da klijent u
  prve dvije sekunde vidi **čiji** je salon, a ime je tenant podatak — jedina stvar na ekranu
  koja se mijenja bez builda. Poziv na akciju ostaje na dugmetu, gdje ga handoff i ima.
- **Naslov sekcije radnika je „Naš tim", ne „Majstori".** Tekst dolazi iz `vertical.terms`
  (`docs/05 §3`), a ne sa slike — isto pravilo koje je gore imenovano baš tim primjerom.
- **CTA je u brand boji, ne `#F2F2F3`.** Boja dolazi iz `tenant.yaml`; na beauty tenantu je roze.
- **Hero je visok 420 pt, ne 320.** Ovo je odstupanje **u smjeru** handoffa, ne od njega: `SPEC.md`
  („Assets") traži hero kao portret 3:4, što bi na 402 pt širine bilo 536 pt. Prvi hero je crtao
  brand gradijent, pa je 320 prolazilo; čim je ispod stala stvarna fotografija, izgledalo je kao
  traka a ne kao izlog. 420 je sredina na kojoj CTA i prva usluga i dalje ulaze u prvi ekran.

  Pri tom povećanju se **vidjelo zašto raspored nije smio zavisiti od te vrijednosti**: naslov i
  status su stajali na `_visinaSlike * 0.55`, dakle na procentu, dok im je sadržaj fiksne visine —
  pa je svako povećanje pola piksela slalo iznad teksta a pola u praznu traku ispod njega (~12 px
  na 320, ~57 px na 420). Sada se lijepe za dno heroja i visina je stvarno jedan broj. Čuva ih
  test koji mjeri razmak, ne redoslijed — redoslijed je prolazio i sa rupom.

„Cjenovnik" je pri tome **doslovno sa slike** i stoji u `.arb`-u, ne u terminologiji: sekcija je
isječak cjenovnika, a puna lista je zaseban ekran koji se i zove „Usluge". Kad vertikala ne
prikazuje cijene (`VerticalFeatures.prices`), naslov pada na `servicePlural` — sekcija bez cijena
nije cjenovnik.

Sekcija bez podataka se **sakriva**, ne crta prazna: salon bez galerije nema praznu mrežu, nego
nema sekciju. Kako to izgleda danas: [`docs/screenshots/task-18-home-barber.png`](../../docs/screenshots/task-18-home-barber.png)
i [`task-18-home-beauty.png`](../../docs/screenshots/task-18-home-beauty.png) — isti build, dva brenda.

### Ekrani koje handoff nema

**Koraci OTP prijave (`/auth/login`, unos emaila i unos koda) nisu nacrtani.** Handoff ima korak 4
(`5f`) kao ekran prijave sa tri dugmeta, ali nijedan ekran iza „Nastavi sa emailom" — a
`docs/06 §2.1` traži šestocifreni kod.

Ta dva koraka su zato **izvedena iz tokena**, ne izmišljena: isti gutter i ritam kao ostatak flowa,
hairline granica, `AppRadius.none`, `AppButton` i `inputDecorationTheme` iz `core_ui`, bez ijedne
nove vrijednosti. Kartica „Čuvamo vam" stoji i na prijavi, jer je prijava dio koraka 4.

Kad handoff dobije te ekrane, mjerodavan je on — ovo je popuna, ne odluka.
Kako izgledaju danas: [`docs/screenshots/task-13-otp-kod.png`](../../docs/screenshots/task-13-otp-kod.png).

### Tri odstupanja na `5n` („O aplikaciji"), sva iz istog razloga

Ekran u storeu ne smije tvrditi ono što aplikacija ne radi, pa handoff ovdje nije prepisan doslovno:

- **Treći korak „Kako radi" nije „Dobijete podsjetnik" nego „Vidite status".** Podsjetnika nema —
  `supabase/functions/send-reminders/` i `send-push/` su danas samo `README` (task 25). Kad push
  stigne, korak se vraća na handoff formulaciju.
- **„Ocijenite aplikaciju" stoji vidljiv, ali neaktivan.** Traži App Store / Play ID, a aplikacije
  nisu objavljene. Crta se na 45% prozirnosti (`SPEC.md` §Interactions) i **ne prima dodir**, uz
  red objašnjenja ispod. Sakriti ga značilo bi da se lista mijenja pod korisnikom kad app ode u
  store; prazan tap je gori od reda koji vidljivo čeka.
- **Podnaslov ne imenuje salon.** Handoff piše „Zakazivanje termina u Barber Studiju Vitez", a ta
  deklinacija se iz podatka ne može izvesti. Rečenica je zato neutralna i vrijedi za svaki tenant.

Monogram **jeste** tekst, kako `SPEC.md` §Assets i traži — ali su to **prva i zadnja riječ** imena
(„Barber Studio Vitez" → „BV"), ne prve dvije. Srednja riječ je u imenima salona najčešće
generička („Studio", „Salon"), a zadnja je grad ili prezime i to razlikuje dva salona istog lanca.

### `5o` crta šest sekcija, ekran ih ne zna unaprijed

Broj sekcija dolazi iz baze, a broj uz sekciju (`01`, `02`…) je **pozicija u listi**, ne podatak.
Salon može dodati svoju sekciju ili nemati nijednu — beauty tenant u seedu ima kraći dokument
upravo zato da se to vidi u demou. Zato u tekstu sekcije ne smije stajati „v. tačku 3": referenca
se pomjeri čim neko doda sekciju iznad.

Brojevi u tijelu (rok otkazivanja, telefon) dolaze kroz placeholdere iz živih podataka. Handoff
piše „2 sata", a baza provodi 3 za barbera i 6 za beauty — v.
[`docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md).

### Red liste je `LinkRow` u `core_ui`

Oblik „labela + chevron, grupisano u jedan okvir" sa `11-postavke.png` i `14-o-aplikaciji.png`
živi u `core_ui` kao `LinkRow`/`LinkRowGroup`, sa tri stanja: sa akcijom (chevron, dodir), bez
akcije (nosi podatak, bez chevrona i bez fokusa) i onemogućen (chevron ostaje, 45% prozirnosti,
bez dodira). Do taska 21 je stajao u `apps/client/features/account/`, sa jednim pozivaocem.

