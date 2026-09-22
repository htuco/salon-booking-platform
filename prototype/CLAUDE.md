# `prototype/` — vizuelne reference, nijedna nije production kod

Četiri foldera, četiri uloge. Root pravila važe — v. `../CLAUDE.md`.

| Folder | Šta je | Status |
|---|---|---|
| `ui/` | Dizajnerski handoff: 17 ekrana u punoj vjernosti, finalni copy, tokeni, komponente | **Vizuelni izvor istine** |
| `adminv2/` | Melura redizajn: isti 21 prikaz (`3a`–`3u`), noviji izgled | **Vizuelni izvor istine za `apps/admin`** |
| `admin/` | Stariji Salon OS handoff: istih 21 prikaz plus `SPEC.md` | **Vizual zastario, tekst važi** |
| `wireframe/` | Stariji React/Vite prototip sa svojim toolchainom | **Zamrznut** |

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
