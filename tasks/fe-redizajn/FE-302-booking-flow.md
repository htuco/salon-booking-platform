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
- [x] Indikator koraka 1–4 po handoffu, oštre ivice — pređeni korak u boji teksta, ne brenda (v. Status)
- [ ] Korak 3: nedostupni slotovi **vidljivi i isključeni** (45 % opacity), ne skriveni — **čeka [ADR-0021](../../docs/adr/0021-zauzeti-slotovi-klijentu-se-ne-prikazuju.md)**
- [x] Slot je dodirna meta ≥ 44 px
- [x] Prelazi između koraka koriste tranziciju iz [FE-201](FE-201-zamjena-default-tranzicije.md) — nijedan korak nema svoju animaciju
- [x] Postojeće ponašanje (back čuva izbor, validacija po koraku, poruka umjesto sivog dugmeta) ostaje dokazano istim testovima
- [x] `PT409` („termin je upravo zauzet") i dalje vraća korisnika na korak sa vremenom, sa zadržanim danom

## Zamke
- **Ovo je jedini klijentski ekran sa dokazanim ponašanjem u utrci.** Test za `PT409` provjerava da
  se lista ponovo traži od baze, a ne prikazuje iz pamćenja; redizajn koji uvede keš slotova ga obori.
- Granularnost `date_only` postoji kao vertikala (`_verticalDateOnly` u testu) — korak 3 nema uvijek
  slotove, i redizajn to mora podnijeti.
- Korak 4 nudi prijavu; „nastavak kao gost" zavisi od `allow_guest_booking`, a
  [task 41](../sprint-4/41-bez-zakazivanja-bez-prijave.md) ga **uklanja**. Uskladiti prije crtanja.

## Status

🟡 **Pet od šest stavki je već bilo isporučeno. Šesta čeka odluku, ne kod.** Grana `feat/fe-302-booking-flow`.

Provjereno čitanjem koda (2026-09-23), bez izmjene ekrana:

- **Indikator** — `StepProgressBar` (`packages/core_ui/lib/src/components/step_progress_bar.dart`):
  četiri segmenta, 5 px, razmak 5 px, `BorderRadius.zero`. Pređeni korak je u boji teksta
  (`onSurface`), ne u boji tenanta. Tako kaže `prototype/ui/SPEC.md:70` (done `#F2F2F3`, pending
  `#3A3F44`), a `prototype/ui/` je jači od handoffa. Brand ostaje na CTA ispod trake.
- **Dodirna meta** — `TimeSlotChip` ima `minHeight: AppSize.timeSlot` (58 px) i
  `minWidth: AppSize.touchTarget`.
- **Tranzicija** — rute `/book/*` su obični `GoRoute` + `builder`, pa idu kroz
  `AppPageTransitionsBuilder` iz FE-201. U `features/booking/` nema nijednog `AnimatedSwitcher`,
  vlastitog `PageRoute` ni tranzicije.
- **Ponašanje i `PT409`** — `apps/client`: `flutter test test/booking_flow_screens_test.dart` →
  **10 pass** (grupa „409 — slot je otišao između prikaza i potvrde"). `packages/core_ui`:
  `flutter test` → **84 pass**.
- **Korak 4 ne nudi gosta** — `details_step_screen.dart` nema „nastavak kao gost", pa se ne kosi
  sa taskom 41.

**Otvoreno: zauzeti slotovi.** `get_available_slots` vraća samo slobodna vremena. Po
`.claude/docs/security.md` upravo taj ugovor dopušta pristup i za `anon`. Da bi se zauzeti
slotovi prikazali, anonimni posjetilac bi vidio raspored salona. To je odluka, pa je
[ADR-0021](../../docs/adr/0021-zauzeti-slotovi-klijentu-se-ne-prikazuju.md) napisan kao
**predložen**. `TimeSlotChip` već ima stanje „zauzet" (precrtano, prigušeno, iznad AA praga), pa
ekranu nedostaje samo podatak.

**Ostalo za sljedećeg:** vlasnik proizvoda prihvata ili odbija ADR-0021. Ako ga odbije, slijedi
migracija za `get_available_slots` + pgTAP + `security.md`, pa `_Grupa` u `slot_step_screen.dart`
dobija `onTap: null` za zauzeta vremena. Na uređaju nije viđeno.
