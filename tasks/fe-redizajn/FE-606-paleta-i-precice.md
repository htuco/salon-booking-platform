# FE-606 — ⌘K paleta i tastaturne prečice

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2 dana |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 1) |
| **Blokira** | — |
| **Reference** | `core/widgets/admin_scaffold.dart` |

## Cilj
Pretraga klijenata, termina i usluga iz jedne palete; odobri/odbij i dan naprijed/nazad sa tastature.

## Zatečeno stanje
Nijedan admin ekran nema `Shortcuts`/`Actions`. Pretraga klijenta postoji samo na ekranu klijenata.

## Definicija gotovog
- [ ] `Ctrl+K` / `⌘K` otvara paletu iz ljuske, na svakom ekranu
- [ ] Rezultati dolaze iz postojećih provajdera; svaki upit tenant-scoped kao danas, nema novog RPC-a bez `security.md`
- [ ] Odobri/odbij rade samo na fokusiranom zahtjevu; `←`/`→` mijenjaju dan na kalendaru
- [ ] Prečice ne okidaju dok je fokus u tekstualnom polju
- [ ] Popis prečica dostupan iz palete

## Zamke
- Browser može zauzeti `Ctrl+K` — provjeriti uživo na `flutter build web`, ne samo widget testom.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
