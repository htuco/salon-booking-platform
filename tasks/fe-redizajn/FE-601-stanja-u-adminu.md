# FE-601 — Prazna stanja, skeletoni i inline greške na svim admin ekranima

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 1), [FE-501](FE-501-stanja-i-skeletoni.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/*/` |

## Cilj
Svaki admin ekran ima učitavanje, grešku i prazno stanje, ne samo „happy path”.

## Zatečeno stanje
FE-501 definiše obrazac za obje aplikacije, ali nije počet. Dashboard već ima prazan dan (FE-402). Ostali ekrani nisu provjereni.

## Definicija gotovog
- [ ] Obrazac iz FE-501 primijenjen na svaki ekran u `features/`, tabela ekran → tri stanja u ovom fajlu
- [ ] Greška pri akciji (odobri, odbij, spremi) je inline uz red ili polje, ne samo SnackBar
- [ ] Widget test po stanju za dashboard, kalendar i zahtjeve

## Zamke
- Radi se **poslije** FE-501, ne umjesto njega. Dva obrasca za istu stvar su greška koju ovaj task treba spriječiti.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
