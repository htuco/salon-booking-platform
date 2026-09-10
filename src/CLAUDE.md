# src/ — wireframe prototip (nije production kod)

React + Vite + Tailwind + Radix. Postoji da se flow i vizual vide **prije** prvog Dart fajla.
Root pravila važe — v. `../CLAUDE.md`.

**Proizvod je Flutter.** Ovdje se ne dodaje funkcionalnost u nadi da će "kasnije preći u proizvod",
i odavde se komponente ne prevode jedan-na-jedan u Dart — Flutter ekrani koriste `core_ui` tokene.
Prototip je referenca za flow i vizuelni jezik, ne izvor koda.

- Rute prate `docs/01 §12`; ikone su `lucide-react` (isti jezik ikona kroz cijeli sistem).
- Nema eslint/prettier konfiguracije, pa ni pre-commit hooka za ovaj folder — dodaje se kad
  toolchain stvarno postoji, da se ne blokira svaki commit na alatu koji ne radi.
- Poznata mrtva težina za uklanjanje: `@mui/*` i `@emotion/*` u `package.json` bez ijednog importa
  (`docs/07 §2`).
- Dokaz je "flow se vidi i klika" (`npm run dev`) plus `npm run build`, ne testovi.
