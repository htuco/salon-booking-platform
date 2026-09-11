# `prototype/` — React wireframe (zamrznut, nije production kod)

React + Vite + Tailwind + Radix, sa svojim toolchainom (`package.json`, `vite.config.ts`,
`index.html` su ovdje, ne u rootu). Root pravila važe — v. `../CLAUDE.md`.

## Zamrznut je

Postojao je da se flow i vizual vide **prije** prvog Dart fajla. Tu ulogu je preuzeo
`design/` — dizajnerski handoff sa 17 ekrana u punoj vjernosti i finalnim copyjem.

**Ovdje se više ne razvija.** Ne dodaje se ekran, ne popravlja se vizual, ne prati se dizajn.
Ostaje kao referenca za **flow i rute** (`src/app/routes.tsx` prati `docs/01 §12`) i kao
istorijski zapis. Gdje se prototip i `design/` ne slažu, **`design/` je jači**.

Ako ti se čini da nešto treba promijeniti ovdje — to je znak da promjena pripada Flutteru
(`apps/client/`) ili dizajnu (`design/`), ne ovom folderu.

## Ako ga ipak treba pokrenuti

```bash
cd prototype && npm install && npm run dev    # ili: npm run build
```

Dokaz je "flow se vidi i klika", ne testovi. Testova ovdje nema i ne pišu se.

## Napomene

- **Root `package.json` je nešto drugo** — drži samo `lefthook` (git hookovi za cijeli repo).
  Ovaj ovdje je toolchain prototipa. Ne spajaju se nazad.
- Nema eslint/prettier konfiguracije, pa ni pre-commit hooka za ovaj folder. Ne dodaje se —
  folder je zamrznut.
- Ikone su `lucide-react`, isti jezik ikona kao u `design/` i u Flutteru.
- Mrtva težina (`@mui/*`, `@emotion/*` bez ijednog importa) je uklonjena pri premještanju
  iz roota; `docs/07 §2` je time zatvoren.
