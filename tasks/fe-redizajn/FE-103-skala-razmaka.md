# FE-103 — Skala razmaka i tretman rubova

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `packages/core_ui/lib/src/tokens/` · `apps/admin/lib/src/core/theme/` · `CLAUDE.md` |

## Cilj
Razmaci dolaze iz skale, kartice su linijski okviri sa oštrim ivicama i hairline rubom, bez sjenki.

## Zatečeno stanje
Skala i pravilo **već postoje**; ovo je revizija, ne uvođenje:

- `AppSpacing` (klijent, `core_ui`) i `AdminSpacing` (admin) su u upotrebi kroz ekrane
  (`AppSpacing.gutter`, `AdminSpacing.gutterDesktop`…).
- „Radius 0, hairline granice umjesto sjenki" je **tvrdo pravilo iz `CLAUDE.md`**, ne novi zahtjev
  handoffa.
- Uprkos tome, u kodu stoji **71 upotreba `borderRadius`/`BorderRadius`** van testova. Dio su
  legitimne (`BorderRadius.zero` u `bottomSheetTheme`), dio nisu — to razlikovanje je posao ovog taska.

## Definicija gotovog
- [ ] Svaka upotreba `borderRadius` je ili `zero`, ili ima napisan razlog u istom redu
- [ ] Nema `boxShadow` na karticama i listama; dubina se nosi rubom
- [ ] Paddinzi i marginе dolaze iz skale (4 / 8 / 12 / 16 / 24 / 32 / 48); proizvoljne vrijednosti nestaju
- [ ] Skala u `core_ui` i u adminu se **poklapaju po vrijednostima ili se razlikuju sa razlogom** koji je zapisan
- [ ] Kartica je linijski okvir, ne popunjen blok — provjereno na oba ekrana koja je najviše koriste

## Zamke
- **Ne tražiti `borderRadius` grepom pa brisati.** `BorderRadius.zero` je ispravna upotreba i mora
  ostati; brisanje svojstva vraća Material podrazumijevani radius, dakle suprotno od cilja.
- Skale su dvije jer su aplikacije dvije. Spajanje u jednu je zaseban posao sa vlastitim rizikom i
  ne radi se usput.

## Status

Nije počet.
