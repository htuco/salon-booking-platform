# FE-604 — Gušće tabele: red 40 px, sticky zaglavlje, bulk akcije

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2 dana |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 2) |
| **Blokira** | — |
| **Reference** | `services/services_screen.dart` · `employees/employees_screen.dart` · `clients/clients_screen.dart` |

## Cilj
Tabelarni ekrani su gušći i dozvoljavaju akciju nad više redova.

## Zatečeno stanje
Tabularne cifre već postoje (`barlowTabular`, ADR-0020). Commit `1990982` dokazuje da red raste sa fontom — 40 px je **najmanja** visina, ne fiksna.

## Definicija gotovog
- [ ] Red ima `minHeight: 40` i raste sa `textScaler`; postojeći test ostaje zelen
- [ ] Zaglavlje ostaje vidljivo pri skrolu; tabela skroluje horizontalno unutar sebe (otvorena stavka FE-406)
- [ ] Bulk akcije samo tamo gdje postoji akcija nad jednim redom; nijedna nova operacija baze

## Zamke
- Bulk brisanje bez undo-a ili potvrde je gore od sadašnjeg stanja — v. FE-608.
- Cilj dodira na telefonu ostaje 48 px; 40 px važi za desktop pojaseve.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
