# Task 55 — Prerada admin dashboarda

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [54](54-uklanjanje-nepotrebnog-iz-admina.md) |
| **Blokira** | — |
| **Reference** | ADR-0020 · `prototype/adminv2/` · `docs/01` §6.3 (Dashboard) · task 47 |

## Cilj
„Danas" postaje radna površina vlasnika: prvo ono na šta mora reagovati, pa tek onda brojke.

## Definicija gotovog
- [ ] **Dizajn prije koda.** Novi izvoz u `prototype/adminv2/` ili ADR koji kaže šta se mijenja
      naspram postojećeg — admin je 1:1 sa izvozom (ADR-0020), pa se dashboard ne crta napamet
- [ ] Zahtjevi na odobrenju ostaju najvažniji blok (`docs/01` §6.3); odobri/odbij u redu već postoji i ostaje
- [ ] Prazna stanja, skeletoni i inline greška na dashboardu — ne samo happy path
- [ ] Radnikova verzija (task 47) i dalje radi: bez prometa, samo njegovi termini
- [ ] Widget testovi za obje uloge nad **istim** ekranom
- [ ] Viđeno uživo, obje uloge, 1440, 2560 i 402

**Ulaz za dizajn** (prijedlog iz Claude Designa, 2026-09-25, uzima se ono što se ne sudara sa
odlukama): zahtjevi na vrhu, statistika sekundarno · prazna stanja i skeletoni · undo toast umjesto
potvrdnog dijaloga gdje je moguće · desni kontekstni panel na širokim ekranima. Isprekidan okvir za
„na odobrenju" i fluidni layout do 2560 (FE-406) već postoje.

## Zamke
- „Koralna samo za jednu akciju" ide protiv `prototype/admin/SPEC.md`, gdje koralna nosi i
  primarne oznake — ako se mijenja, to ulazi u isti ADR.
- Brojka bez podatka iza sebe je gora od praznog mjesta (SPEC). Nova kartica traži upit koji je
  dokazuje, ne procjenu.

## Status
Nije počet.
