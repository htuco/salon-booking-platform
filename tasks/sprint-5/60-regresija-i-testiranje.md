# Task 60 — Regresija i testiranje

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [59](59-radnik-u-seedu.md) i svi taskovi sprinta koji su stigli |
| **Blokira** | — |
| **Reference** | `/verify` skill · `CLAUDE.md` („Testovi su uski") |

## Cilj
Cijeli sistem prođen rukom, kraj na kraj. Bugovi se ne nagađaju unaprijed — nalaze se ovdje i
zapisuju u tabelu ispod.

## Definicija gotovog
- [ ] Klijent, svi tenanti (barber, beauty, health ako je stigao): početna, zakazivanje od koraka 1
      do potvrde, moji termini, otkazivanje, prijava, reset lozinke, brisanje računa
- [ ] Admin, obje uloge (vlasnik, radnik): prijava, Danas, kalendar, termini, odobri/odbij/otkaži,
      novi termin sa telefonskim klijentom, usluge, osoblje i poziv, radno vrijeme, blokade, postavke, slike
- [ ] Push u oba smjera na Android uređaju: novi zahtjev salonu, potvrda i podsjetnik klijentu
- [ ] Izolacija: `supabase test db` + oba Deno REST testa zeleni; vlasnik A ne vidi ništa od B
- [ ] Širine 1440, 2560 i 402 za admin; telefon za klijenta
- [ ] Svaki nađeni bug je u tabeli: sitan se popravi u ovom PR-u sa regresionim testom, veći dobija svoj task
- [ ] `melos run analyze`, `melos run test` i CI zeleni na kraju

## Nađeni bugovi

| # | Gdje | Šta | Ishod |
|---|---|---|---|
| — | — | — | — |

## Zamke
- **Prolazna `melos run test` suite ne govori ništa o ekranu ni o upitu.** Ovaj task se dokazuje
  pokretanjem, sa snimcima u `docs/screenshots/`.
- Hostovani projekat mora imati sve migracije sprinta (`supabase db push`) prije žive provjere.

## Status
Nije počet.
