# Task 16 — Client: "Moji termini" + otkazivanje

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | 25 (push vodi na ovaj ekran) |
| **Reference** | `prototype/ui/SPEC.md` 5h i 5p · [01 §8.3](../../docs/01-mvp-spec.md) |

## Cilj
Korisnik vidi šta je zakazao, u kojem je statusu, i može otkazati dok mu pravila to dozvoljavaju.
Success ekran iz taska 11 konačno ima gdje da vodi.

## Definicija gotovog
- [ ] `/appointments` po `05-…/SPEC` 5h: tabovi **Predstojeći / Prošli**, status po terminu
- [ ] `AppointmentRepository` u `core_api` — prvi put postoji, jer do sada `appointments` nije
      imao politiku za klijenta ([08 status](../sprint-1/08-core-api-repozitoriji.md))
- [ ] Otkazivanje kroz modal 5p: blur + scrim, destruktivna akcija i "Zadrži termin"
- [ ] **Rok za otkazivanje iz `vertical.rules.minCancelHours`**, ne iz konstante; nakon roka je
      dugme onemogućeno sa objašnjenjem
- [ ] Otkazan slot se **odmah oslobađa** — provjereno ponovnim otvaranjem koraka 3
- [ ] Prazno stanje: nema termina → poziv na booking, ne prazan ekran
- [ ] Widget testovi: dva taba, otkazivanje, zabrana nakon roka

## Koraci
1. Politika i RPC za otkazivanje prvo (`supabase/`), pa repozitorij, pa ekran
2. Ekran po handoffu; modal je nova `core_ui` komponenta (`AppDialog`)
3. Commit: `feat(client): moji termini i otkazivanje`

## Zamke
- **Otkazivanje je upis** — ide kroz RPC sa provjerom vlasništva i roka, nikad `update` sa klijenta.
- `cancelled_by` mora reći **ko** je otkazao (`customer` / `salon` / `system`); admin ekran i
  statistika kasnije zavise od toga.
- `pending` koji je istekao je `system` otkazivanje, ne korisnikovo.
