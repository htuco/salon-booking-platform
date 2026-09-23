# FE-602 — Dashboard kao radna površina

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 2), dopuna `3b` u handoffu |
| **Blokira** | — |
| **Reference** | `dashboard/dashboard_screen.dart` · `appointments/zahtjev_kartica.dart` · `prototype/adminv2/export/3b-lokacija-danas.png` |

## Cilj
Na vrhu dashboarda su zahtjevi na odobrenju sa odobri/odbij u redu; statistika je ispod.

## Zatečeno stanje
FE-402 je ekran doveo 1:1 sa `3b` (PR #70, #81), gdje su metrike na vrhu. Odobri/odbij postoje u `zahtjev_kartica.dart` i u traci akcija detalja.

## Definicija gotovog
- [ ] Dopuna handoffa ili zapisano odstupanje u `prototype/admin/SPEC.md` prije koda
- [ ] Red zahtjeva koristi istu akciju kao `zahtjev_kartica.dart`, ne drugu implementaciju
- [ ] Odbijanje i dalje traži razlog gdje ga sadašnji tok traži
- [ ] Nula zahtjeva: sekcija se sklapa u jedan red, ne ostaje prazan okvir

## Zamke
- Poništava dio dokaza FE-402; testovi koji tvrde redoslijed kartica se prepisuju, ne brišu.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
