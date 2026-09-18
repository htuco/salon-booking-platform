# `prototype/` — vizuelne reference, nijedna nije production kod

Tri foldera, tri uloge. Root pravila važe — v. `../CLAUDE.md`.

| Folder | Šta je | Status |
|---|---|---|
| `ui/` | Dizajnerski handoff: 17 ekrana u punoj vjernosti, finalni copy, tokeni, komponente | **Vizuelni izvor istine** |
| `admin/` | Salon OS handoff: 10 desktop i 11 mobilnih admin prikaza | **Vizuelni izvor istine za `apps/admin`** |
| `wireframe/` | Stariji React/Vite prototip sa svojim toolchainom | **Zamrznut** |

Za klijentsku aplikaciju je `ui/` jači od `wireframe/`; za admin aplikaciju je `admin/` jači od
`wireframe/`. Vjernost im je viša i copy je finalniji. `wireframe/` ostaje referenca samo za
**flow i rute** (`wireframe/src/app/routes.tsx` prati `docs/01 §12`) i kao istorijski zapis.

## `admin/` — kako se čita

`admin/SPEC.md` mapira svih 21 prikaz na postojeće i buduće Flutter module. `admin/index.html`
služi samo kao navigacija kroz originalni design canvas. Canvas renderer i placeholder slike se
ne portuju u aplikaciju.

Admin je jedan platformski build za sve salone. Njegov plavi akcent je identitet Salon OS-a, ne
tenant branding; salon i ovlasti i dalje dolaze iz server-side membershipa i RLS-a. Multi-location
prikaz `3a` je budući scope dok ne postoji odgovarajući RBAC.

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
