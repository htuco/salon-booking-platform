# `prototype/` — vizuelne reference, nijedna nije production kod

Šest foldera, šest uloga. Root pravila važe — v. `../CLAUDE.md`.

| Folder | Šta je | Status |
|---|---|---|
| `ui/` | Dizajnerski handoff: 17 ekrana u punoj vjernosti, finalni copy, tokeni, komponente | **Vizuelni izvor istine** |
| `beauty/` | Handoff teme `elegant_beauty`: isti shell kao `ui/`, svijetla paleta, brand uloge izvedene iz jedne boje, 21 ekran | **Izvor istine za beauty temu** (task 52) |
| `adminv2/` | Melura redizajn: isti 21 prikaz (`3a`–`3u`), noviji izgled; u `profil/` meni korisnika i Moj profil (`4a`–`4e`, task 61, sa svojim `README.md`); u `toast/` toast obavijesti (`5a`–`5c`, task 62); u `danas/` novi Danas (`6a`–`6m`, task 55, ADR-0027) — za Danas jači od `3b`/`3k` | **Vizuelni izvor istine za `apps/admin`** |
| `admin/` | Stariji Salon OS handoff: istih 21 prikaz plus `SPEC.md` | **Vizual zastario, tekst važi** |
| `wireframe/` | Stariji React/Vite prototip sa svojim toolchainom | **Zamrznut** |
| `masaza/` | Handoff vertikale `health`: masaža (18 ekrana) i u `fizio/` fizioterapija kao drugi tenant (15 ekrana), isti shell kao `ui/`, light + dark | Izvor istine za **paletu, pismo i rječnik** `health` tema (ADR-0026); oblik ekrana i dark ostaju iz `ui/`, v. `masaza/README.md` |

Za klijentsku aplikaciju je `ui/` jači od `wireframe/`; za admin aplikaciju je **`adminv2/` jači
od `admin/`**, a oba jača od `wireframe/`. `wireframe/` ostaje referenca samo za **flow i rute**
(`wireframe/src/app/routes.tsx` prati `docs/01 §12`) i kao istorijski zapis.

## Admin: sliku uzimaš iz `adminv2/`, tekst iz `admin/SPEC.md`

Ovo je jedino mjesto u repou gdje se izvor razdvaja na dva foldera, pa se najlakše pogriješi.
Odluka i obrazloženje: [ADR-0016](../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md).

- **`adminv2/export/` je kako ekran izgleda.** 21 PNG, imenovan po istim identifikatorima
  `3a`–`3u`. Nema `SPEC.md` i ne očekuje se.
- **`admin/SPEC.md` je šta ekran radi.** Mapa prikaza na Flutter module, funkcionalne granice
  („šta canvas crta, a aplikacija namjerno nema"), tokeni, redoslijed implementacije. Skup
  ekrana je identičan u oba foldera, pa ta mapa i dalje važi.
- Gdje `SPEC.md` opisuje **vizual** a `adminv2` pokazuje drugo, jači je `adminv2`, i `SPEC.md`
  se ispravlja u istoj promjeni koja taj ekran dira.
- `admin/canvas/` i `admin/index.html` se **ne portuju** — canvas renderer i placeholder slike
  nikad nisu ni bili za portovanje.

Dvije neusklađenosti koje `SPEC.md` još nosi, i koje zatvara
[FE-401](../tasks/fe-redizajn/FE-401-admin-shell.md), ne usputna izmjena:

- ime proizvoda je **Melura**, ne „Salon OS" (`SPEC.md:1`)
- **koralna `#EE6C4D` nosi primarne akcije**, a plava `#3D5A80` pada na linkove i sporedno
  (`SPEC.md:81–82`)

Admin je jedan platformski build za sve salone, pa je njegov akcent identitet proizvoda, **ne**
tenant branding — ista koralna u klijentskoj aplikaciji je greška, tamo boja dolazi iz
`tenant.yaml`. Salon i ovlasti i dalje dolaze iz server-side membershipa i RLS-a. Birač lokacije i
„6 lokacija" u sidebaru `adminv2` izvoza su prikaz `3a`: **budući scope** dok ne postoji RBAC, pa
njihov izostanak u aplikaciji nije propust.

## `ui/` — kako se čita

`ui/SPEC.md` je specifikacija (ekrani, komponente, tokeni, ponašanje, stanja); `ui/README.md`
objašnjava kako se prevodi u ovaj repo. Ukratko, jer je to pravilo koje se najlakše prekrši:

- **Oblik se uzima** — tipografska skala, spacing ritam, radius 0, hairline granice umjesto sjenki,
  dodirne mete ≥44px, oblik komponenti. Živi u `core_ui`.
- **Boja se ne uzima.** Hex u handoffu je paleta *jednog* brenda (Barber Studio Vitez). Boja dolazi
  iz `tenant.yaml` kroz `buildAppTheme()`.
- **Tekst se ne uzima.** "Majstori", "Kod koga dolazite?" su barber terminologija; dolaze iz
  `vertical.terms`.

Hardkodiran hex ili naziv usluge u ekranu prolazi test i prolazi pregled screenshota — padne tek na
drugom tenantu ili drugoj vertikali.

`ui/canvas/` se **ne portuje** (handoff to izričito kaže) i `Salon App v2.dc.html` ne radi offline
jer mu fali `_ds` bundle iz izvoza. Za gledanje služe `ui/screens-flat.html` i `ui/screenshots/`.

## `beauty/` — tema, ne novi dizajn

Handoff od 2026-09-27 za task 52. Ne mijenja raspored: `Beauty App.dc.html` je **isti shell kao
`ui/`** (ekrani `1a`–`1q` odgovaraju `5a`–`5q`), plus četiri stanja (`2a`–`2d`: sheet prijave
slike, Početna bez ocjena, prazne recenzije, prazna galerija). Opis i tokeni su u
`beauty/README.md`; kad se on i canvas ne slažu, jači je canvas za raspored, a
`Beauty Tema.dc.html` za paletu i stanja komponenti.

- **Uzima se paleta teme**, ne salona: neutrale su iste za svaki beauty salon, a `primary`,
  `brandLine`, `brandInk` i `brandContainer` se **izvode** iz jedne `brand` boje iz
  `tenant.yaml` (algoritam i referentna JS implementacija su u `README.md`). Izvođenje ide u
  `core_ui`, ne u ekran.
- **Jost je usvojen za temu `elegant_beauty`**
  ([ADR-0025](../docs/adr/0025-pismo-i-uloge-izbora-vezu-se-za-temu.md)): tema nosi par pisama,
  barber ostaje na DM Serif Display + Archivo. Skala je ista — mijenja se pismo, ne veličina.
- **Izbor ide brandom samo u beautyju.** Slot, dan, progres, izabrani red i tab traka čitaju
  `AppSelectionColors`; barber ih puni bojom teksta kao i prije, beauty izvedenim brand ulogama.
- **Blur modala ostaje** u svim temama, i u beautyju (ADR-0025). Iz handoffa se uzima scrim token,
  ne uklanjanje blura — beauty se tu namjerno ne poklapa sa canvasom.
- Handoff zove barber temu `barber_dark`; u repou je `modern_barber`. Uslovi `hasPhone` /
  `hasReviews` / `hasGallery` u repou dolaze iz podataka, ne iz konfiguracije.
- `beauty/` se otvara offline preko lokalnog servera (`python3 -m http.server` u folderu), jer
  browser blokira `file:`. Ovdje `_ds` bundle postoji, za razliku od `ui/canvas/`. Fotografije su
  prazni slotovi, pa je 404 na `.image-slots.state.json` očekivan. Jost se učitava sa Google
  Fontsa.
- `ios-frame.jsx`, `image-slot.js`, `support.js` i `_ds/` se ne portuju — isto kao `ui/canvas/`.

## `wireframe/` — zamrznut

Ovdje se **ne razvija**: ne dodaje se ekran, ne popravlja se vizual, ne prati se dizajn. Ako ti se
čini da nešto treba promijeniti ovdje, to je znak da promjena pripada Flutteru (`apps/client/`) ili
dizajnu (`prototype/ui/`).

Ako ga ipak treba pokrenuti:

```bash
cd prototype/wireframe && npm install && npm run dev    # ili: npm run build
```

Dokaz je "flow se vidi i klika", ne testovi. Testova ovdje nema i ne pišu se.

- **Root `package.json` je nešto drugo** — drži samo `lefthook` (git hookovi za cijeli repo).
  `wireframe/package.json` je toolchain prototipa. Ne spajaju se nazad.
- Nema eslint/prettier konfiguracije i neće je dobiti; hook se dodaje kad stigne pravi `web/`
  (Next.js konzola, `docs/07 §1`).
- Ikone su `lucide-react`, isti jezik ikona kao u `ui/` i u Flutteru.
- Mrtva težina (`@mui/*`, `@emotion/*` bez ijednog importa) je uklonjena pri premještanju iz roota;
  `docs/07 §2` je time zatvoren.
