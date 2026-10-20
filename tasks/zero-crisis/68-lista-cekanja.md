# Task 68 — Lista čekanja

| | |
|---|---|
| **Procjena** | 3–4 dana |
| **Zavisi od** | [64](64-istek-neodgovorenih-zahtjeva.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `get_available_slots` · task 39 (push) |

## Cilj
Kad je dan pun, klijent se upisuje na listu čekanja; kad se termin oslobodi (otkazivanje, odbijanje,
istek), dobija push i može ga zauzeti.

## Odluke prije koda (ADR)
- **Ko dobija oslobođen termin:** preporuka — push **svima** sa liste za taj dan i uslugu, prvi koji
  zakaže dobija ga (bez rezervacije na čekanju). Alternativa „termin se drži prvom na listi X minuta"
  je pravednija, ali traži novi status i istek.
- Šta je upis: dan + usluga (+ opcionalno radnik i dio dana: jutro/popodne).
- Koliko dugo važi upis i koliko upisa po klijentu.

## Definicija gotovog
- [x] ADR sa odlukama iznad — [ADR-0031](../../docs/adr/0031-lista-cekanja-push-svima-prvi-zakaze.md), **predložen**, čeka Hamzino odobrenje u PR-u
- [x] Tabela upisa sa `salon_id`, RLS (klijent samo svoje, salon svoje), negativan test
- [x] Klijent: „Obavijesti me kad se oslobodi" na punom danu; lista svojih upisa u „Moji termini"
- [x] Oslobođen termin → push upisanima, jednom po oslobađanju (red u `notification_logs`; isporuka na uređaj nije viđena)
- [x] Melura: broj upisanih po danu (salon vidi potražnju)
- [ ] pgTAP + uživo na Androidu — pgTAP i uživo na webu da; Android nema uređaja (v. 56)

## Status (2026-10-20) — 🟡 kod dokazan lokalno, čeka odluku, merge i deploy

Grana `feat/lista-cekanja`, [PR #142](https://github.com/htuco/salon-booking-platform/pull/142).

**Šta je urađeno.** Migracija `20261020140000_lista_cekanja.sql`: tabela `waitlist_entries` bez
ijednog app granta; RPC `join_waitlist`, `leave_waitlist`, `my_waitlist`, `waitlist_full_dates`
(javno) i `waitlist_demand` (samo vlasnik). Pravilo slotova je preseljeno u
`private.candidate_slots`, sa prekidačem „računaj bez termina", pa je `get_available_slots` omotač
istog potpisa. Otkazivanje budi samo upise kojima se mjesto stvarno otvorilo. Ponuda
(`waitlist_offer`) je vezana za upis, ne za tuđi termin. `send-push` je šalje bez `appointment_id`.
Klijent: pun dan je treće stanje u kalendaru (precrtan, tapa se), panel „Obavijesti me kad se
oslobodi", sekcija „Lista čekanja" u „Moji termini" i stavka u „Obavijesti". Melura: „Lista
čekanja: N" za dan, samo vlasniku.

**Nađeno usput.** Kalendar koraka 3 nije dao tapnuti dan bez slobodnog vremena, pa pun dan nije
mogao ni biti izabran. Zato `CalendarDay.full` i `waitlist_full_dates` umjesto provjere po danu.

**Dokazano:**
- `./tool/test_supabase.sh` exit 0: pgTAP 33 fajla / 996 asercija (nov `033`, 53), svi REST
  testovi (`rest_public_catalog` 62, sa tri nove provjere bez tokena), `send-push` `deno test` 7.
- 13 mutacija, svaka obara 1–8 asercija u `033` (tabela u `security.md`, „Lista čekanja").
- `melos run test`: `core_domain` 104, `core_ui` 147, `core_api` 157, klijent 681, admin 722.
  `melos run analyze` je čist, osim zatečenog infoa u `apps/admin/lib/src/core/kontakt.dart:75` (#138).
- Uživo, lokalni stack, web: utorak 27.10. pun (blokada do 16:00 + dva termina u 16:00). Na 402 px
  klijent vidi „27, popunjen", tap → prijava (`?from=/book/slot`) → povratak na isti dan → upis.
  Salon otkaže Amarov termin, pa nastaje jedan red `waitlist_offer | queued | bez termina | uz upis`
  i dan ima 3 slobodna vremena. „Obavijesti" pokazuje „Oslobodilo se mjesto · Muško šišanje ·
  utorak 27.10.". „Moji termini" pokazuju upis, a „Ukloni" ga briše, zajedno sa ponudom (0 i 0).
  Melura na 1440 pokazuje „Lista čekanja: 1". Snimci su `docs/screenshots/task-68-*.png`.

**Ostalo za sljedećeg:**
- **Odluka (Hamza):** ADR-0031 je prijedlog. Ako izbor bude „termin se drži prvom X minuta", to
  je novi status i istek (procjena 5+ dana).
- **Deploy (Hamza) poslije merge-a, ovim redom:** `supabase functions deploy send-push` (inače
  stari worker baci `unsupported_type` na prvu ponudu), pa `supabase db push`. Provjere:
  `select proname from pg_proc where proname in ('join_waitlist','waitlist_full_dates','waitlist_demand','candidate_slots')`
  vraća sve četiri, a `select count(*) from information_schema.role_table_grants where table_name = 'waitlist_entries' and grantee in ('anon','authenticated')` vraća 0.
- Push `waitlist_offer` na Android uređaju (nema uređaja, v. 56). Isporuka nije viđena, viđen je
  samo red u logu.
- Red „Lista čekanja" u admin Postavkama i dalje vodi na „uskoro". O njemu odlučuje task 54.
- U `date_only` vertikali pun dan se ne nudi, jer korak tamo završava izborom dana. Ako `health`
  traži listu čekanja, panel treba mjesto i tamo.
