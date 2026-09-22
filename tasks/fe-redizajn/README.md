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
| [FE-102](FE-102-tipografija-barlow.md) | Tipografija Barlow / Barlow Condensed | obje | FE-3xx, FE-4xx | 2–3 dana |
| [FE-103](FE-103-skala-razmaka.md) | Skala razmaka i tretman rubova | obje | — | 0,5–1 dan |
| [FE-104](FE-104-ikone.md) | Ikone: jedan set, jedna debljina | obje | — | 1–2 dana |
| [FE-201](FE-201-zamjena-default-tranzicije.md) | Jedna tranzicija na obje platforme | klijent | FE-302 | 1–2 dana |
| [FE-202](FE-202-tab-navigacija.md) | Prelaz između tabova | klijent | — | 1 dan |
| [FE-203](FE-203-modali-i-bottom-sheet.md) | Modali i bottom sheet | obje | FE-304 | 1 dan |
| [FE-204](FE-204-lightbox-galerija.md) | Lightbox galerije | klijent | FE-305 | 1–2 dana |
| [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) | Ukinuti default Flutter indikatore | obje | FE-501 | 2–3 dana |
| [FE-301](FE-301-pocetna-i-o-nama.md) | Početna i „O nama" | klijent | — | 1–2 dana |
| [FE-302](FE-302-booking-flow.md) | Booking flow (4 koraka) | klijent | — | 2–3 dana |
| [FE-303](FE-303-zahtjev-poslan.md) | Ekran „Zahtjev poslan" | klijent | — | 0,5 dan |
| [FE-304](FE-304-moji-termini.md) | Moji termini | klijent | — | 1–2 dana |
| [FE-305](FE-305-usluge-galerija-recenzije.md) | Usluge, galerija, recenzije | klijent | — | 2–3 dana |
| [FE-306](FE-306-obavijesti-i-postavke.md) | Obavijesti i postavke | klijent | — | 1–2 dana |
| [FE-401](FE-401-admin-shell.md) | Admin ljuska i Melura branding | admin | FE-402…FE-405 | 1–2 dana |
| [FE-402](FE-402-dashboard.md) | Dashboard | admin | — | 1–2 dana |
| [FE-403](FE-403-kalendar-termina.md) | Kalendar termina | admin | — | 2–3 dana |
| [FE-404](FE-404-upravljanje-podacima.md) | Usluge, osoblje i klijenti | admin | — | 2–3 dana |
| [FE-405](FE-405-login.md) | Prijava (admin) | admin | — | 0,5 dan |
| [FE-406](FE-406-desktop-fluidni-layout.md) | Desktop je fluidan, ne fiksni 1280 | admin | FE-402…FE-404 | 1–2 dana |
| [FE-501](FE-501-stanja-i-skeletoni.md) | Stanja učitavanja, greške i prazna stanja | obje | — | 1–2 dana |
| [FE-502](FE-502-pristupacnost.md) | Pristupačnost i kontrast | obje | — | 1–2 dana |
| [FE-503](FE-503-ciscenje-legacy-stilova.md) | Čišćenje legacy stilova | obje | — | 1 dan |
| [FE-504](FE-504-qa-prolaz.md) | QA prolaz kroz sve ekrane | obje | — | 1–2 dana |

Ukupno **32–48 dana**. To je tri do četiri sprinta i tako se planira, ne kao jedan „redizajn".

## Četiri odluke koje moraju pasti prije prvog commita

Handoff traži četiri stvari koje se **kose sa pravilima koja ovaj repo već provodi**. Nijedna nije
sitnica i nijedna se ne rješava usput u taskovu — svaka je ADR (`docs/adr/`), po pravilu iz
`CLAUDE.md`: odluka koja se ne može pročitati iz koda.

**1. Barlow protiv dva postojeća para pisama.** Handoff traži Barlow + Barlow Condensed. Repo danas
nosi **Space Grotesk + JetBrains Mono** u adminu i **DM Serif Display + Archivo** u klijentu, oba
zapakovana lokalno uz OFL licence, i oba **izričito napisana** u `prototype/admin/SPEC.md:54` i
`prototype/ui/SPEC.md:110`. Ovo nije zamjena fonta nego zamjena dva handoffa; dok ADR ne postoji,
FE-102 mijenja kod protiv specifikacije koja i dalje tvrdi suprotno.

**2. Koralna na klijentu ruši multi-tenant branding.** `#EE6C4D` je akcent **Salon OS admina** i
tako je i specificiran (`prototype/admin/SPEC.md:82`, tekst na koralu `#2C2C2C`). Klijentska
aplikacija nema jednu boju: boja dolazi iz `tenants/<flavor>/tenant.yaml` kroz `buildAppTheme()`,
i `CLAUDE.md` to vodi kao tvrdo pravilo („Iz `prototype/ui/` se uzima oblik, ne boja"). Fiksna
koralna u klijentu je greška koja prolazi svaki test i vidi se tek na drugom salonu.

**3. Lucide kao set ikona je nova zavisnost.** `prototype/ui/SPEC.md:51` traži Lucide stroke 1.5, i
wireframe ga koristi (`lucide-react`) — ali u Flutteru ga danas nema nijedan paket, a u kodu stoji
**116 upotreba `Icons.*`**. Bira se između pub paketa, zapakovanog icon fonta i SVG seta; to je
izbor koji nosi licencu, veličinu bundla i tree-shaking, dakle ADR.

**4. Šta je `prototype/adminv2/`.** Folder je stigao commitom `1edd73a` sa 21 PNG izvozom i
**nije opisan u `prototype/CLAUDE.md`**, koji i dalje nabraja tri foldera i `admin/` vodi kao
„vizuelni izvor istine za `apps/admin`". Dok se ne zapiše zamjenjuje li `adminv2/` stari `admin/`
ili stoji uz njega, svaki FE-4xx task ima dva izvora istine koji se ne slažu.

## Šta ovaj epik **ne** dira

- **Funkcionalnost.** Nijedan task ovdje ne mijenja upit, migraciju, RLS politiku ni ponašanje
  rezervacije. Gdje bi redizajn to tražio, task to imenuje i staje.
- **`prototype/wireframe/`.** Zamrznut je i ostaje zamrznut (`prototype/CLAUDE.md`).
- **Dark mode klijenta.** Handoff ga ne pokriva; ostaje imenovan dug.

## Status

Epik otvoren 2026-09-22. Nijedan task još nije počet.
