# Task 34 — Radno vrijeme, pauze i blokade

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [33](33-osoblje-i-smjene.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3h` `3s` · [01 §8.1](../../docs/01-mvp-spec.md) |

## Cilj
Salon sam postavlja radno vrijeme, pauze i neradne dane. To je posljednji dio availability ulaza
koji se danas mijenja samo u bazi.

## Definicija gotovog
- [ ] `/working-hours` po `3h`, mobilno `3s`
- [ ] Radno vrijeme po danu, pauze, neradni dani i blokade po radniku
- [ ] Sve kroz RPC, sa izolacijom po salonu; pgTAP na svaku putanju pisanja
- [ ] **Availability ostaje na backendu.** Ekran mijenja ulaz u `get_available_slots`, ne pravila
- [ ] Postojeći termin koji ispadne van novog radnog vremena se **ne briše tiho** — admin ga vidi
- [ ] Promjena se odmah vidi u klijentskoj app-i, dokazano upitom i prolazom kroz ekran

## Koraci
1. Migracija + pgTAP, pa ugovor, pa ekran
2. Provjera protiv klijentske app-e: promjena u adminu mijenja slotove u klijentu
3. Commit: `feat(admin): radno vrijeme, pauze i blokade`

## Zamke
- **Odluka koja se ne otvara:** availability logika je na backendu, nikad u app-i
  (`docs/01 §8.1`). Ekran koji sam računa slobodne termine je ista greška kao prosjek ocjena
  računat u Dartu iz taska 20.
- **Admin izuzetak vrijedi samo za `min_advance_booking_hours`** (task 24). Radno vrijeme, pauze i
  blokade vrijede i njemu.
- Dan salona nije nužno kalendarski dan — vremenska zona i prelazak preko ponoći imaju svoj slučaj.

## Status

Nije počet.
