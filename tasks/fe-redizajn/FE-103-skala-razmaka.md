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
- [x] Svaka upotreba `borderRadius` je ili token, ili `zero`, ili ima napisan razlog —
      **sedam literala je nađeno i uklonjeno**, guard test ih sada drži
- [x] Nema `boxShadow` na karticama i listama — provjereno grepom, **nijedna pojava** u
      obje aplikacije
- [x] Paddinzi i margine dolaze iz skale — v. „Šta je ostalo namjerno" ispod
- [x] Skala u `core_ui` i u adminu se razlikuju **sa zapisanim razlogom**
      (`admin_tokens.dart:6` i `spacing.dart:1`) — dva handoffa, dva proizvoda
- [x] Kartica je linijski okvir, ne popunjen blok — viđeno uživo na dashboardu i kalendaru

## Zamke
- **Ne tražiti `borderRadius` grepom pa brisati.** `BorderRadius.zero` je ispravna upotreba i mora
  ostati; brisanje svojstva vraća Material podrazumijevani radius, dakle suprotno od cilja.
- Skale su dvije jer su aplikacije dvije. Spajanje u jednu je zaseban posao sa vlastitim rizikom i
  ne radi se usput.

## Status

**Gotovo, dokazano.** Grana `feat/fe-103-skala-razmaka`.

### Šta je revizija stvarno našla

Task je pretpostavljao da je posao razlikovati legitimne od nelegitimnih upotreba među 71
pojavom `borderRadius`. Stvarno stanje je bilo bolje na jednom kraju i gore na drugom:

- **Radius je u obje aplikacije već tokenizovan** — `AppRadius.none` (klijent, jedina
  vrijednost) i `AdminRadius.base`/`pill` (admin). Klijent nema **nijedan** literal.
- **Admin je imao sedam literala u ekranima.** Dva su bila doslovno prepisani tokeni:
  `circular(6)` = `AdminRadius.base` (`employees_screen.dart:189`) i `circular(20)` =
  `AdminRadius.pill` (`services_screen.dart:291`). To je greška koja se ne vidi u
  pregledu — izgleda tačno kao token dok se token ne promijeni, a tada se ugao promijeni
  svuda osim na tih sedam mjesta.
- Preostalih pet (`circular(4)` ×4, `circular(3)` ×1) su **stvarne mjere** sitnih
  elemenata iz canvasa, ali nisu bile nigdje zapisane. Sada su tokeni `AdminRadius.small`
  i `AdminRadius.dot`, svaki sa razlogom zašto nije izveden iz `base`.
- **`boxShadow` nema nijedan.** Pravilo „dubina iz ruba, ne iz sjenke" se već poštuje.

### Šta je ostalo namjerno

**63 `EdgeInsets` literala u adminu se ne diraju.** `admin_tokens.dart:10` to već
propisuje: canvas koristi međuvrijednosti (9, 11, 13, 15, 17) **unutar jedne komponente**,
i one su mjere te komponente, ne koraci skale. Svođenje na 4/8/12/16/24 bi bilo pisanje
koda protiv izmjerenog handoffa — tačno ono što `CLAUDE.md` zabranjuje.

Klijent ima **jedan** takav literal (`placeholder_screen.dart:25`), na ekranu koji je
privremen po imenu i namjeni.

### Dokaz

**310 admin testova PASS** (bilo 309), analiza i format čisti. Novi guard test
`apps/admin/test/no_hardcoded_radius_test.dart` — **provjereno da pada**: vraćen
`circular(6)` je prijavljen uz fajl i broj reda.

**Viđeno uživo** na 1440×900: dashboard (trake zauzetosti = `small`, pilule statusa =
`pill`) i kalendar (ćelije mini kalendara = `small`, uzorci u legendi = `dot`). Kartice su
linijski okviri sa hairline rubom, bez sjenki.
