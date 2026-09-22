# FE-302 — Booking flow (4 koraka)

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-201](FE-201-zamjena-default-tranzicije.md), [FE-102](FE-102-tipografija-barlow.md) |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/booking/` · `prototype/ui/screenshots/03-korak1-usluga.png`…`06-korak4-prijava.png` |

## Cilj
Redizajn toka: usluga → radnik → vrijeme → prijava/potvrda.

## Zatečeno stanje
Tok **postoji i radi**, sa stanjem u `booking_flow_provider.dart` i testovima u
`apps/client/test/booking_flow_screens_test.dart`. Ono što DoD iz handoffa traži kao novo, dijelom
je već dokazano tim testovima:

- „Back čuva odabrane vrijednosti" — `bookingFlowProvider` to već radi, test to već tvrdi.
- „Dugme *Dalje* onemogućeno dok korak nije validan" — postoji, uz labelu koja kaže **šta fali**
  (`Izaberite vrijeme`), što je jače od samog onemogućenog dugmeta i mora ostati.
- `StepProgressBar` postoji u `core_ui` i nosi `LinearProgressIndicator`, pa ga dira i
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md).

## Definicija gotovog
- [ ] Indikator koraka 1–4 po handoffu, oštre ivice, aktivni korak naglašen bojom tenanta
- [ ] Korak 3: nedostupni slotovi **vidljivi i isključeni** (45 % opacity), ne skriveni
- [ ] Slot je dodirna meta ≥ 44 px
- [ ] Prelazi između koraka koriste tranziciju iz [FE-201](FE-201-zamjena-default-tranzicije.md) — nijedan korak nema svoju animaciju
- [ ] Postojeće ponašanje (back čuva izbor, validacija po koraku, poruka umjesto sivog dugmeta) ostaje dokazano istim testovima
- [ ] `PT409` („termin je upravo zauzet") i dalje vraća korisnika na korak sa vremenom, sa zadržanim danom

## Zamke
- **Ovo je jedini klijentski ekran sa dokazanim ponašanjem u utrci.** Test za `PT409` provjerava da
  se lista ponovo traži od baze, a ne prikazuje iz pamćenja; redizajn koji uvede keš slotova ga obori.
- Granularnost `date_only` postoji kao vertikala (`_verticalDateOnly` u testu) — korak 3 nema uvijek
  slotove, i redizajn to mora podnijeti.
- Korak 4 nudi prijavu; „nastavak kao gost" zavisi od `allow_guest_booking`, a
  [task 41](../sprint-4/41-bez-zakazivanja-bez-prijave.md) ga **uklanja**. Uskladiti prije crtanja.

## Status

Nije počet.
