# FE redizajn — Melura

Redizajn obje aplikacije, presložen u format taskova ovog repoa. **Nije sprint** nego epik koji
presijeca sve sprintove: `tasks/sprint-<N>/` nose funkcionalnost, ovaj folder nosi izgled.

Ulaz je dizajnerski handoff (25 stavki, grupisanih u pet epika). Presložene su ovdje jer su
stigle u formatu koji ne kaže **šta je u repou već urađeno** — a to je kod polovine njih glavno
pitanje. Svaki task zato nosi `## Zatečeno stanje` sa stvarnim fajlom i brojem reda, i tek onda
`## Definicija gotovog`.

| # | Task | Aplikacija | Blokira | Procjena |
|---|---|---|---|---|
| [FE-101](FE-101-tokeni-boja.md) | Paleta kao tokeni | obje | FE-3xx, FE-4xx | 0,5–1 dan |
| ~~[FE-102](FE-102-tipografija-barlow.md)~~ | ~~Tipografija Barlow~~ — **neće se raditi** ([ADR-0019](../../docs/adr/0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md)) | — | — | — |
| [FE-103](FE-103-skala-razmaka.md) | Skala razmaka i tretman rubova | obje | — | 0,5–1 dan |
| [FE-104](FE-104-ikone.md) | Ikone: jedna debljina (Lucide već uveden, [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md)) | klijent | — | 0,5–1 dan |
| [FE-201](FE-201-zamjena-default-tranzicije.md) | Jedna tranzicija na obje platforme 🟡 | klijent | FE-302 | 1–2 dana |
| [FE-202](FE-202-tab-navigacija.md) | Prelaz između tabova ✅ | klijent | — | 1 dan |
| [FE-203](FE-203-modali-i-bottom-sheet.md) | Modali i bottom sheet ✅ | obje | FE-304 | 1 dan |
| [FE-204](FE-204-lightbox-galerija.md) | Lightbox galerije ✅ | klijent | FE-305 | 1–2 dana |
| [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) | Ukinuti default Flutter indikatore ✅ | obje | FE-501 | 2–3 dana |
| [FE-301](FE-301-pocetna-i-o-nama.md) | Početna i „O nama" ✅ | klijent | — | 1–2 dana |
| [FE-302](FE-302-booking-flow.md) | Booking flow (4 koraka) 🟡 | klijent | — | 2–3 dana |
| [FE-303](FE-303-zahtjev-poslan.md) | Ekran „Zahtjev poslan" ✅ | klijent | — | 0,5 dan |
| [FE-304](FE-304-moji-termini.md) | Moji termini 🟡 | klijent | — | 1–2 dana |
| [FE-305](FE-305-usluge-galerija-recenzije.md) | Usluge, galerija, recenzije ✅ | klijent | — | 2–3 dana |
| [FE-306](FE-306-obavijesti-i-postavke.md) | Obavijesti i postavke 🟡 | klijent | — | 1–2 dana |
| [FE-401](FE-401-admin-shell.md) | Admin ljuska i Melura branding | admin | FE-402…FE-405 | 1–2 dana |
| [FE-402](FE-402-dashboard.md) | Dashboard | admin | — | 1–2 dana |
| [FE-403](FE-403-kalendar-termina.md) | Kalendar termina | admin | — | 2–3 dana |
| [FE-404](FE-404-upravljanje-podacima.md) | Usluge, osoblje i klijenti | admin | — | 2–3 dana |
| [FE-405](FE-405-login.md) | Prijava (admin) | admin | — | 0,5 dan |
| [FE-406](FE-406-desktop-fluidni-layout.md) | Desktop je fluidan, ne fiksni 1280 | admin | FE-402…FE-404 | 1–2 dana |
| [FE-501](FE-501-stanja-i-skeletoni.md) | Stanja učitavanja, greške i prazna stanja ✅ | obje | — | 1–2 dana |
| [FE-502](FE-502-pristupacnost.md) | Pristupačnost i kontrast | obje | — | 1–2 dana |
| [FE-503](FE-503-ciscenje-legacy-stilova.md) | Čišćenje legacy stilova | obje | — | 1 dan |
| [FE-504](FE-504-qa-prolaz.md) | QA prolaz kroz sve ekrane 🟡 | obje | — | 1–2 dana |
| [FE-505](FE-505-demo-ulazi-pune-sve-ekrane.md) | Demo ulazi pune sve ekrane (nalaz FE-504) | obje | FE-504 | 0,5–1 dan |
| [FE-506](FE-506-o-nama-po-5b.md) | „O nama" po obliku iz `5b` (nalaz FE-504) | klijent | — | 0,5–1 dan |

Ukupno **32–48 dana**. To je tri do četiri sprinta i tako se planira, ne kao jedan „redizajn".

## Četiri odluke — sve četiri su pale

Handoff je tražio četiri stvari koje se **kose sa pravilima koja ovaj repo već provodi**. Nijedna
se nije rješavala usput u taskovu — svaka je ADR (`docs/adr/`), po pravilu iz `CLAUDE.md`: odluka
koja se ne može pročitati iz koda.

**Stanje: sve četiri su riješene. Epik je odblokiran u cijelosti.**

**1. Barlow protiv dva postojeća para pisama.** ✅ **Riješeno —
[ADR-0019](../../docs/adr/0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md): Barlow se ne uvodi.**
Odlučile su dvije činjenice: **Barlow nema mono rez**, a mono u adminu nosi inline podatak
(`prototype/admin/SPEC.md:65` — `13:00`, `82%`, `26 MIN`), i **zamjena pisma mijenja visinu svakog
reda**, čime bi poništila dokaz završenog admin bloka (šest taskova, preko 300 testova). Iz
handoffa se uzima **tipografska skala i hijerarhija**, ne porodica pisma. Oba `SPEC.md`-a ostaju
tačna. **FE-102 je time zatvoren kao „neće se raditi", ne kao gotov.**

**2. Koralna na klijentu ruši multi-tenant branding.** ✅ **Riješeno —
[ADR-0018](../../docs/adr/0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md): klijent
je ne dobija.** `#EE6C4D` ostaje isključivo u adminu, koji je jedan platformski build za sve salone.
Klijent je N brandiranih buildova i boja mu dolazi iz `tenants/<flavor>/tenant.yaml` kroz
`buildAppTheme()` — mehanizam nije teorijski, dva postojeća tenanta nose `#C6A667` i `#B76E79`.
Iz handoffa se uzima **oblik, ne boja**, kako `CLAUDE.md` već traži.

**3. Lucide kao set ikona.** ✅ **Riješeno —
[ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md): Lucide je
set klijenta, admin ostaje na Material `Icons.*`.** Ovdje je **opis u ovom fajlu bio netačan**:
tvrdio je da „u Flutteru ga danas nema nijedan paket" i da stoji „116 upotreba `Icons.*`". Stvarno
stanje: `lucide_icons_flutter: ^3.1.19` je **već** u `apps/client/pubspec.yaml:68` i
`packages/core_ui/pubspec.yaml:20`, uvezen u 12 fajlova klijenta i četiri `core_ui` komponente.
Material ostatak u klijentu su bile **četiri upotrebe dvije ikone**, a **61 upotreba je u adminu**,
koji se po ADR-0017 ne prevodi. **FE-104 je time sužen** — nije „uvedi set ikona" nego „zamijeni
četiri ikone i ujednači veličine".

**4. Šta je `prototype/adminv2/`.** ✅ **Riješeno —
[ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md).**

`adminv2/` je vizuelni izvor istine za admin, `admin/` je zastario. Odluka je ispala uža nego što
je izgledala: **oba foldera pokrivaju isti skup ekrana** — izvučeni identifikatori iz
`adminv2/export/` daju `3a`–`3u`, isto što `admin/SPEC.md` nabraja u „Mapi prikaza", razlika nula
u oba smjera. Dakle nije drugi handoff nego **redizajn istih 21 prikaza**, pa `SPEC.md` ostaje na
snazi kao tekst (mapa na module, funkcionalne granice), a `adminv2/` je jači za vizual.
`prototype/CLAUDE.md` to sada izričito piše.

### Zajednička nit kroz sve tri nove odluke

Sve tri govore isto: **iz handoffa se uzima oblik, a ne vrijednost.** Skala i hijerarhija da,
porodica pisma ne. Raspored i značenje akcenta da, hex ne. Gdje handoff nosi vrijednost koja se u
ovom repou već izvodi odnekud drugdje — iz `tenant.yaml`, iz zapakovanog pisma, iz postojećeg seta
ikona — jači je repo. Ekrani se zato **neće poklapati sa PNG-ovima u boji ni u pismu**, i to je
očekivano, ne bug.

## Šta ovaj epik **ne** dira

- **Funkcionalnost.** Nijedan task ovdje ne mijenja upit, migraciju, RLS politiku ni ponašanje
  rezervacije. Gdje bi redizajn to tražio, task to imenuje i staje.
- **`prototype/wireframe/`.** Zamrznut je i ostaje zamrznut (`prototype/CLAUDE.md`).
- **Dark mode klijenta.** Handoff ga ne pokriva; ostaje imenovan dug.

## Status

Epik otvoren 2026-09-22.

**Gotovo:** [FE-406](FE-406-desktop-fluidni-layout.md) — [PR #65](https://github.com/htuco/salon-booking-platform/pull/65)
spojen u `main` (`824c98b`). Četiri pojasa širine, admin je fluidan do 2560 px. Viđeno uživo;
browser je našao dvije greške koje 289 testova nije.

FE-406 je počet prvi iako nije prvi po broju: ne zavisi ni od čega, blokira FE-402, FE-403 i
FE-404, i **jedini je od šest admin taskova koji ne referencira nijedan PNG iz `prototype/adminv2/`**
— pa je mogao naprijed dok su odluke iznad čekale ADR.

**Gotovo:** [FE-401](FE-401-admin-shell.md) — kod gotov i dokazan, grana
`feat/fe-401-admin-ljuska-melura`. Melura wordmark, tamni sidebar, verzal navigacija, uloga
ispod imena. 294 testa, viđeno uživo na tri ekrana. Odblokirao ga je
[ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md), spojen u `main`.

Dva nalaza iz izvoza koja task nije predvidio: **koralne oznake uz aktivnu stavku nema**
(skeniran cijeli sidebar — nula koralnih piksela), a **pilula brojača jeste koralna**, što task
nije spomenuo. Oba zapisana u task fajlu.

**Gotovo:** [FE-405](FE-405-login.md) ([PR #69](https://github.com/htuco/salon-booking-platform/pull/69)),
[FE-402](FE-402-dashboard.md) ([PR #70](https://github.com/htuco/salon-booking-platform/pull/70)) i
[FE-404](FE-404-upravljanje-podacima.md) ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)),
svi spojeni u `main`.

**Gotovo (redizajnerski dio):** [FE-403](FE-403-kalendar-termina.md) —
[PR #72](https://github.com/htuco/salon-booking-platform/pull/72), draft. Zahtjev na odobrenju
nosi isprekidan rub, na mreži `3c`, u listi `3l` i u legendi. 309 testova.

Ekran je bio **već ispunjen do četiri od šest DoD stavki** iz taska 31 i FE-406, pa je stvarni
posao bio jedna rupa, ne cijeli ekran. Dvije stavke su **izostavljene kao imenovan dug**:
prekidač `Dan · Sedmica · Mjesec` (stoji u tabeli izostavljanja u `prototype/admin/SPEC.md`;
ulazak traži ADR) i osvježavanje na realtime signal (funkcionalnost, a epik je vizuelni).

**Time je admin blok (FE-401…FE-406) zatvoren.**

**Sljedeće:** ostatak epika je **klijentska** aplikacija, i on je sada **odblokiran** — sve četiri
odluke su pale kao ADR ([0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md),
[0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md),
[0018](../../docs/adr/0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md),
[0019](../../docs/adr/0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md)).

Dvije od njih **smanjuju opseg epika**, ne povećavaju ga:

- **FE-102 se ne radi** — Barlow je odbijen, postojeća pisma ostaju (ADR-0019).
- **FE-104 je sužen** — Lucide je već uveden u klijentu; ostaje ujednačavanje debljine i
  četiri Material upotrebe u klijentu i ujednačavanje veličina (ADR-0017).

Preostaje **17 taskova**: FE-101, FE-103, FE-104, FE-2xx (5), FE-3xx (6) i FE-5xx (4).
FE-5xx po definiciji idu zadnji.

**🟡 [FE-201](FE-201-zamjena-default-tranzicije.md)** — grana `feat/fe-201-jedna-tranzicija`.
Jedan `AppPageTransitionsBuilder` za sve platforme, 220/180 ms, swipe-back na iOS-u zadržan.
Dokazano testovima (`core_ui` 75, klijent 238); **fali snimak sa Android i iOS uređaja**. Admin
ostaje na svom pretapanju (ADR-0020).

**✅ [FE-202](FE-202-tab-navigacija.md)** — grana `feat/fe-202-prelaz-tabova`. Tab se pretapa
120 ms preko prethodnog, stanje i skrol preživljavaju, ostali tabovi se ne grade iznova. 243 testa.

**✅ [FE-203](FE-203-modali-i-bottom-sheet.md)** — grana `feat/fe-203-modali-i-sheet`. `AppModal`:
dijalog 180 ms fade + scale 0,98, sheet 240 ms. Admin dio se ne radi (ADR-0020).

**✅ [FE-204](FE-204-lightbox-galerija.md)** — grana `feat/fe-204-lightbox`. `Hero` 260 ms kroz
`PageRoute` (dijalog ne pokreće let), mreža skroluje ispod da zatvaranje sa druge slike ne poskoči.
Pinch sluša samo dva prsta, pa ne otima swipe. 250 testova; viđen na emulatoru, gdje su nađena i popravljena dva prazna leta.

**✅ [FE-205](FE-205-ukidanje-default-flutter-indikatora.md)** — spojen u [PR #78](https://github.com/htuco/salon-booking-platform/pull/78);
tabela ga do FE-301 nije označavala. Klijent spinnera nije ni imao — posao je bio admin.

**✅ [FE-301](FE-301-pocetna-i-o-nama.md)** — grana `feat/fe-301-pocetna-i-o-nama`. Ekrani su već bili
po handoffu; popravljen skok CTA-a od 78 px pri učitavanju (kostur 320 + razmak naspram heroja 420),
na Početnoj i `/about`. Test mjeri vrh dugmeta, sabotaža ga obara. 252 testa.

**✅ [FE-303](FE-303-zahtjev-poslan.md)** — grana `feat/fe-303-zahtjev-poslan`. Ekran je bio po handoffu
od taska 37; popravljena back gesta, koja je na Androidu zatvarala aplikaciju (ispod `/book/success`
nema rute). Sada vodi na Početnu i čisti flow. Test sa sabotažom, 253 testa. Na uređaju nije viđeno.

**🟡 [FE-504](FE-504-qa-prolaz.md)** — grana `docs/fe-504-qa-prolaz`. Prvi prolaz na webu, na stanju
`main` + #94 + #95. Snimljeno 100 prikaza: klijent na oba tenanta (402 i 360 px), admin na 1440,
2560, 768 i 402 px. Admin i veći dio klijenta prate izvoz. Dva nalaza su zasebni taskovi:
**[FE-505](FE-505-demo-ulazi-pune-sve-ekrane.md)** (demo ulazi ne pune devet prikaza, dva se sruše)
i **[FE-506](FE-506-o-nama-po-5b.md)** (`/about` hero). Uređaj (FE-201) nije provjeren.
