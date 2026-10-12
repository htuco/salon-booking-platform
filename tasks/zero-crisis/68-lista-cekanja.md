# Task 68 — Lista čekanja

| | |
|---|---|
| **Procjena** | 3–4 dana |
| **Zavisi od** | [64](64-istek-neodgovorenih-zahtjeva.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `get_available_slots` · task 39 (push) |

## Cilj
Kad je dan pun, klijent se upisuje na listu čekanja; kad se termin oslobodi (otkazivanje, odbijanje,
istek), dobija push i može ga zauzeti.

## Odluke prije koda (ADR)
- **Ko dobija oslobođen termin:** preporuka — push **svima** sa liste za taj dan i uslugu, prvi koji
  zakaže dobija ga (bez rezervacije na čekanju). Alternativa „termin se drži prvom na listi X minuta"
  je pravednija, ali traži novi status i istek.
- Šta je upis: dan + usluga (+ opcionalno radnik i dio dana: jutro/popodne).
- Koliko dugo važi upis i koliko upisa po klijentu.

## Definicija gotovog
- [ ] ADR sa odlukama iznad
- [ ] Tabela upisa sa `salon_id`, RLS (klijent samo svoje, salon svoje), negativan test
- [ ] Klijent: „Obavijesti me kad se oslobodi" na punom danu; lista svojih upisa u „Moji termini"
- [ ] Oslobođen termin → push upisanima, jednom po oslobađanju
- [ ] Melura: broj upisanih po danu (salon vidi potražnju)
- [ ] pgTAP + uživo na Androidu

## Status
Nije počet.
