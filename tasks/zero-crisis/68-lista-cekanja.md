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
- [x] ADR sa odlukama iznad — [ADR-0031](../../docs/adr/0031-lista-cekanja-push-svima-prvi-zakaze.md), **prihvaćen 2026-10-21** u reviewu PR-a #142, sa izmjenama iz reviewa
- [x] Tabela upisa sa `salon_id`, RLS (klijent samo svoje, salon svoje), negativan test — i salon ne vidi redove ponuda u logu (pgTAP, mutacija obara)
- [x] Klijent: „Obavijesti me kad se oslobodi" na punom danu; lista svojih upisa u „Moji termini"
- [x] Oslobođen termin → push upisanima, jednom po oslobađanju: samo upisu kojem je baš to otkazivanje otvorilo vrijeme, jedan po klijentu (red u `notification_logs`, pgTAP sa mutacijama; isporuka na uređaj nije viđena)
- [x] Melura: broj upisanih po danu (salon vidi potražnju)
- [ ] pgTAP + uživo na Androidu — pgTAP i uživo na webu da; Android nema uređaja (v. 56)

## Status (2026-10-21) — 🟡 popravke iz reviewa dokazane lokalno, čeka CI, merge i deploy

ADR-0031 je prihvaćen. Popravke iz Hamzinog reviewa idu kao commitovi na istu granu
(`fix(supabase)`, `fix(client)`, `fix(admin)`, `docs`); migracija nije deployana, pa je mijenjana
na mjestu.

**Šta je popravljeno.**
- Salon ne vidi redove ponuda ni u logu: `staff_notification_logs` je sužena na
  `waitlist_entry_id is null` (red ponude nosi `device_id`, a spoj na `appointments.device_id` bi
  otkrio ko čeka).
- „Jednom po oslobađanju" je stvarno pravilo: upis dobija ponudu samo kad je otkazani termin
  blokirao slobodan slot njegove usluge i radnika (isti radnik, preklapanje `span`-a sa
  `[početak, kraj + bafer)`); `candidate_slots` zato vraća i `span`. Od više upisa istog klijenta
  ponudu dobija najraniji.
- Upis gasi tek **potvrđen** termin (insert kao `confirmed` ili prelaz u `confirmed`); `pending` i
  odbijen zahtjev ga ostavljaju. Deaktivirana usluga ili radnik brišu upise koji ih traže.
- PT429 kaže „Već imate tri upisa na listi čekanja".
- Klijent: `myWaitlistProvider` se invalidira gdje i termini i poslije zakazivanja; bez dozvole za
  push panel kaže da obavijesti nisu uključene (`pushPermissionProvider`); odjava ima svoju
  poruku; pad upita je `LoadError`; upis i odjava idu kroz `WaitlistActionNotifier`.
- Melura: upit potražnje ide jednom po sedmici (`.select(pocetakSedmice)`), sa testom za vlasnika
  i radnika.

**Dokazano (2026-10-21, vlastiti stack `pr142`):**
- `./tool/test_supabase.sh` exit 0: pgTAP 33 fajla / 1008 asercija (`033` 65), REST: izolacija 24,
  javni katalog 62, upsert 20, između salona 42, brisanje naloga 33, admin prijava 14, push 12,
  `send-push` `deno test` 7.
- Mutacije nad `033` (svaka primijenjena na živu bazu, pa `supabase test db`): politika bez
  uslova → pada 1; stari uslov okidača → 1; bez uslova radnika → 1; bez preklapanja → 1; bez jedne
  ponude po klijentu → 3; `pending` gasi upis → 2; „pročitano" bez vlasništva → 2; okidač bez
  filtera salona → 2; bez brisanja deaktiviranih → 2. Ponovljene Enizove mutacije čiji su testovi
  mijenjani: bez provjere slotova 1, `claim` bez grane upisa 3, istorija bez vlasništva 1, bez
  gašenja na terminu 3, bez gašenja na brisanju naloga 1. Tabela je u `security.md`.
- `melos run test`: `core_domain` 104, `core_ui` 147, `core_api` 157, klijent 686, admin 725.
  `melos run analyze` čist osim zatečenog infoa u `apps/admin/lib/src/core/kontakt.dart:75`.
  Tema za oba demo tenanta prolazi, `gen_flavors --check` ažuran.
- Mutacije u Dartu, svaka obara svoj test: bez invalidacije poslije zakazivanja, panel bez
  provjere dozvole, stara poruka odjave (sekcija i panel), greška kao prazno stanje, kalendar bez
  `.select`, kalendar bez provjere radnika.

**Nije provjereno uživo poslije reviewa:** panel bez push dozvole i sekcija sa greškom viđeni su
samo u widget testovima; poruka bez dozvole na pravom telefonu nije viđena (nema uređaja, v. 56).

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
- ~~**Odluka (Hamza):** ADR-0031 je prijedlog.~~ Prihvaćen 2026-10-21, v. status iznad.
- **Deploy (Hamza) poslije merge-a, ovim redom:** `supabase functions deploy send-push` (u istom
  prolazu ide i `send-push` iz taska 67), pa `supabase db push`. Obrnutim redom stari worker ne
  zna `waitlist_offer`: `messageFor` baci izuzetak unutar slanja, red završi kao
  `failed / delivery_unknown` i ponuda se tiho izgubi. Provjere poslije `db push`:
  `select proname from pg_proc where proname in ('join_waitlist','waitlist_full_dates','waitlist_demand','candidate_slots')`
  vraća sve četiri; `select has_table_privilege('anon','public.waitlist_entries','select'), has_table_privilege('authenticated','public.waitlist_entries','select')`
  → `f | f`; `select 'waitlist_offer' = any(enum_range(null::public.notification_type)::text[])`
  → `t`; `select count(*) from pg_trigger where not tgisinternal and tgfoid in (select oid from pg_proc where proname in ('queue_waitlist_offers','close_waitlist_entry','delete_waitlist_of_identity','delete_waitlist_of_inactive'))`
  → `5`; `select pg_get_expr(polqual, polrelid) from pg_policy where polname = 'staff_notification_logs'`
  → `(private.is_admin(salon_id) AND (waitlist_entry_id IS NULL))`. Lokalno su sve dale tačno to.
- Uklanjanje veze radnik–usluga ne briše upis kod tog radnika (samo deaktivacija radnika ili
  usluge briše); takav upis troši mjesto do kraja dana. Zapisano u `security.md`.
- Push `waitlist_offer` na Android uređaju (nema uređaja, v. 56). Isporuka nije viđena, viđen je
  samo red u logu.
- Red „Lista čekanja" u admin Postavkama i dalje vodi na „uskoro". O njemu odlučuje task 54.
- U `date_only` vertikali pun dan se ne nudi, jer korak tamo završava izborom dana. Ako `health`
  traži listu čekanja, panel treba mjesto i tamo.
