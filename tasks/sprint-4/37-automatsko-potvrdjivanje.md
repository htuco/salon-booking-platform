# Task 37 — Automatsko potvrđivanje termina

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | [01 §11](../../docs/01-mvp-spec.md) · `supabase/migrations/20260921180000_postavke_lokacije.sql` |

## Cilj
Kad salon uključi automatsko potvrđivanje, klijentska rezervacija nastaje kao `confirmed`. Danas
ostaje `pending` bez obzira na postavku.

## Šta je stvarno pokvareno
Postavka postoji kroz cijeli stek i **nigdje se ne čita**. `salon_settings.booking_mode` je u
`init_schema` (`check in ('manual','auto')`), task 36 ga piše kroz RPC, admin ekran ga prebacuje —
a `book_appointment` status bira isključivo po pozivaocu:

```sql
(case when v_admin then 'confirmed' else 'pending' end)::public.appointment_status,
```

Nije rubni slučaj ni utrka: žica nikad nije spojena. Isti `case when v_admin` odlučuje i o `source`
i o `pending_expires_at` u redovima ispod, pa se sve troje mijenja zajedno.

## Definicija gotovog
- [x] `book_appointment` čita `v_settings.booking_mode`; `auto` daje `confirmed` i `pending_expires_at = null`
- [x] Admin unos ostaje `confirmed` bez obzira na postavku — salon ne čeka odgovor od sebe (task 24)
- [x] pgTAP pokriva **oba** načina: `manual` → `pending` sa rokom, `auto` → `confirmed` bez roka
- [x] Negativan test: prebacivanje postavke ne dira **postojeće** termine
- [x] Klijent vidi tačan ishod odmah — ekran poslije rezervacije ne tvrdi „čeka potvrdu" kad je potvrđen
- [x] `supabase/IMPLEMENTATION.md` opisuje ugovor oba načina

## Koraci
1. Nova migracija koja zamjenjuje `book_appointment` — deployana se ne mijenja
2. pgTAP prije Dart promjene
3. Provjera klijentskog ekrana potvrde i teksta koji se na njemu pojavi

## Zamke
- **`create or replace` sa istim potpisom je zamjena; sa drugačijim je preopterećenje.** Obje verzije
  ostanu u bazi sa grantom i stari poziv tiho ode na staru. Provjeri `pg_proc` upitom.
- Push „termin potvrđen" ne smije stići dvaput kad je `auto` — v. task 39.

## Status (2026-09-22)

Kod je gotov i dokazan pokretanjem; [PR #63](https://github.com/htuco/salon-booking-platform/pull/63)
stoji kao draft. Grana `fix/automatsko-potvrdjivanje`.

**Šta je promijenjeno.** Migracija `20260922100000_automatsko_potvrdjivanje.sql` zamjenjuje
`book_appointment` **istim potpisom** i uvodi `v_auto := v_admin or coalesce(booking_mode,
'manual') = 'auto'`, kojim nosi `status` i `pending_expires_at`. Klijentski
`BookingSuccessScreen` grana po `appointment.status` i badge vodi kroz postojeći
`statusLabel`/`statusTone` umjesto vlastite kopije.

**`source` se namjerno ne mijenja.** Automatski potvrđen termin je i dalje stigao iz
aplikacije (`app`), a ne rukom iz salona (`manual`) — status i `source` odgovaraju na dva
različita pitanja, i spajanje bi ubilo jedini podatak po kojem se u izvještaju razlikuje
rezervacija klijenta od one koju je salon sam upisao.

**Dokazi.**

- `npx supabase db reset` primjenjuje migraciju od nule, `npx supabase test db` →
  **15/15 fajlova, 455 asercija** (bilo 433; novi `015` nosi 22).
- **Sabotaža**: stara verzija funkcije vraćena unutar transakcije nad novim testom obara
  **tačno dvije** asercije — `Auto mod: klijentska rezervacija je potvrdjena odmah` i
  `Potvrdjena rezervacija nema sta cekati` — i nijednu drugu. Poslije rollbacka `pg_proc`
  drži jednu `book_appointment`, i to onu sa `v_auto`.
- Zamka iz taska provjerena asercijom, ne okom: `count(*) = 1` nad `pg_proc` dokazuje
  zamjenu, ne preopterećenje.
- `melos run analyze` bez primjedbi u pet paketa, `melos run format` čist,
  `melos run test` **798** (bilo 797).
- **CI je zelen na PR-u**: `Schema, RLS and tenant isolation` i `Analiza, format i testovi` oba
  `SUCCESS` ([run 35727587537](https://github.com/htuco/salon-booking-platform/actions/runs/35727587537)).
  To je dokaz iz čistog checkouta, koji lokalno ne postoji.

**Nalaz koji ovaj task ne zatvara — ide u 39.** U `auto` modu salon ne dobija **nijednu**
push obavijest o novoj rezervaciji. `private.queue_appointment_push` na `INSERT` reagira
samo na `source='app' and status='pending'`, a `confirmed` red tu granu ne pogađa. Zamka
koju task opisuje (dupla „termin potvrđen") zato **ne postoji** — problem je suprotan, i
obavijest ne stigne nijednom. Popravka traži novu vrijednost u `notification_type` enumu
(danas: `confirmed`, `rejected`, `reminder_d1`, `reminder_h3`, `new_request`, `cancelled`),
što je šema izvan DoD-a ovog taska.

**Migracija je na hostovanom projektu** (2026-09-22). `npx supabase db push` je primijenio
**tačno jednu** migraciju — `migration list` je prije toga pokazao 17 primijenjenih i samo
`20260922100000` sa praznim `remote`. Poslije: jedna `book_appointment` u `pg_proc`, sa `v_auto`.

**Bug je bio živ u produkciji demo baze.** Salon je tamo **već bio u `auto` modu** — neko je
prekidač uključio kroz Postavke, a migracije nije bilo, pa je svaka klijentska rezervacija i dalje
nastajala kao `pending` i čekala potvrdu koju je salon postavkom već dao.

Dokaz nad **hostovanom** bazom, unutar transakcije koja je vraćena (`rollback`), sa privremenim
identitetom i prvim slotom koji `get_available_slots` stvarno vrati:

```
status=confirmed source=app rok=null
```

Provjereno poslije: nula zaostalih naloga, nula zaostalih klijenata, broj termina nepromijenjen (66).

**Ostalo za sljedećeg.**

- Ekran poslije rezervacije nije viđen uživo u `auto` modu; dokaz je za sada widget test plus
  gornji ishod iz baze. Sada je odblokiran — hostovani projekat ima migraciju.
- Hostovani projekat **nije `link`-ovan** i ne može biti bez Supabase access tokena, koji po
  pravilu repoa ne ide u `.env.live`. Direktna veza (`db.<ref>.supabase.co:5432`) je odbijena, pa
  komande idu kroz **session pooler**: `postgres.<ref>@aws-1-eu-west-1.pooler.supabase.com:5432`.

## Status (2026-09-23) — ✅ zatvoren

Spojen u `main` kroz [PR #63](https://github.com/htuco/salon-booking-platform/pull/63). Dokaz iz bloka
iznad važi; `015_automatsko_potvrdjivanje` prolazi i na `main`-u (`supabase test db`, 478/478).
