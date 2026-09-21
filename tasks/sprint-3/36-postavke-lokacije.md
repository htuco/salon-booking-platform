# Task 36 — Postavke lokacije

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3i` `3t` · [21](../sprint-2/21-obavijesti-i-pravni-ekrani.md) |

## Cilj
Salon mijenja svoje podatke i booking pravila bez novog builda i bez nas.

## Definicija gotovog
- [x] `/settings` po `3i`; „Još" (`3t`) je mobilni ulaz u module izvan četiri navigacijske ćelije
      — `3t` je napravio task 29, ovdje je samo prestao voditi na placeholder
- [x] Osnovni podaci: naziv, adresa, grad, telefon, email, Instagram, Facebook **stranica**
- [x] Booking pravila iz `salon_settings`: način potvrde, buffer, min/max unaprijed, granularnost,
      `min_cancel_hours`, `allow_guest_booking`
- [x] Salonski dio pravila (`salon_policies`) — otkazivanje, kašnjenje, kontakt
- [x] **`app_policies` se ne dira iz admina.** Zakazivanje, Cijene i „Vaši podaci" obavezuju firmu
      i iste su u svakoj brandiranoj app-i
      ([ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md))
      — ekran ih prikazuje kao **zaključan popis**, jer nevidljivo ograničenje izgleda kao kvar
- [x] pgTAP: `salon_admin` nema pisanje nad `app_policies` — negativan test taska 21 je ostao
      zelen i **ponovljen kroz pravi PostgREST** u `rest_postavke_lokacije.ts`
- [x] Promjena `min_cancel_hours` odmah mijenja ponašanje klijentskog otkazivanja — dokazano
      posljedicom: isti termin, dva poziva `cancel_appointment`, `PT403` pa `cancelled`

## Koraci
1. RPC + pgTAP, pa ekran
2. Provjera kroz klijentsku app-u: promjena pravila se vidi bez novog builda
3. Commit: `feat(admin): postavke lokacije i booking pravila`

## Zamke
- **Facebook stranica salona nije Facebook prijava.** `salons.facebook_url` je kontakt i ostaje;
  prijava preko Facebooka ne postoji
  ([ADR-0011](../../docs/adr/0011-facebook-login-se-ne-implementira.md)).
- **Branding ne ide ovdje.** Boje i logo dolaze iz `tenant.yaml` kroz generator; polje za boju u
  adminu bi napravilo drugi izvor istine za isti podatak.
- **Negativan test iz taska 21 mora ostati zelen**: `salon_admin` nad `app_policies`. Upravo je
  NULL grana u guardu pustila zahtjev bez `x-salon-id` headera u tasku 14.
- Sekcije pravila se crtaju dinamično `01..NN`. `PostgrestTransformBuilder.order` ima
  `ascending = false` kao **default** — ista zamka je dvaput dala obrnut redoslijed (taskovi 21 i
  23) i vidi se tek na ekranu.

## Status (2026-09-21) — 🟡 čeka CI

[PR #59](https://github.com/htuco/salon-booking-platform/pull/59), draft, commit `ce76081`.

**Nalaz koji je odredio obim: dvije tabele su bile na suprotnim krajevima iste greške.** Nad
`salons` vlasnik nije mogao pisati **uopšte** — postoje samo `public_salons`, `staff_salons`
(oba `select`) i `super_salons`, pa je `insert/update/delete` grant iz init migracije bio mrtav.
Nad `salon_settings` je grant bio **živ**, uz `staff_manage` koja ga je puštala, pa je direktan
`PATCH` prolazio i zaobilazio svaku validaciju — vlasnik je mogao upisati `min_cancel_hours = 0`
zajedno sa `booking_mode` koji RPC ne bi primio. Oba puta su zatvorena u `rpc`
(`update_salon_contact`, `update_salon_settings`), kao što je task 24 zatvorio `appointments`,
33 `employees`, a 34 `working_hours`. `staff_manage` je zamijenjena sa `staff_read` (`for
select`): politika koja tvrdi više nego što grant dopušta je politika koju sljedeći čitalac
pogrešno pročita.

**Kolone su nabrojane u potpisu, ne proslijeđene kroz.** `status`, `plan`, `slug`,
`vertical_pack_key`, `terminology_override`, boje i logo nisu parametri. Branding posebno:
dolazi iz `tenant.yaml` kroz generator, pa bi polje u adminu bilo drugi izvor istine koji
sljedeće generisanje tiho pregazi. Isto važi za `timezone` i `language` — oni mijenjaju značenje
**svih** već upisanih `time` vrijednosti u `working_hours` i `appointments`, dakle migracija
podataka, ne postavka.

**`salon_policies` namjerno ostaje bez `rpc`, i to je jedini takav admin modul.** `staff_manage`
već daje CRUD uz grant, a mimo `check` constrainta koji stoje (`sort_order > 0`, neprazan naslov
i tijelo) nema šta da se validira — funkcija bi bila prosljeđivanje koje sakriva politiku umjesto
da je pojača. Zapisano u `security.md` i `architecture.md` da sljedeći čitalac ne traži `rpc`
kojeg nema.

**DoD o roku otkazivanja je dokazan posljedicom, ne čitanjem.** `014` provuče isti termin i istog
klijenta kroz `cancel_appointment` dva puta, a između poziva samo podigne pa spusti rok kroz
`update_salon_settings`: prvi put `PT403`, drugi put `cancelled`. Rok se čita pri **svakom**
pozivu, ne pamti se pri rezervaciji. REST test dodaje drugu polovinu tvrdnje „bez novog builda":
ono što vlasnik snimi čita **`anon` bez tokena**.

**Dokazano pokretanjem:** `supabase test db` **433 asercije** u 14 fajlova (novi `014` nosi 48),
svih deset REST testova zeleno (novi `rest_postavke_lokacije.ts` 19 provjera), `melos run test`
**278** admin testova (10 novih za ekran), `flutter analyze` čist, `dart format` bez izmjena,
`gen_flavors --check` ažuran. Sabotaže: guard u `update_salon_contact` oslabljen na `true` obara
**2** asercije; guard i validacija izbačeni iz `update_salon_settings` obaraju **12**.

**Zamka za sljedećeg, iz vlastite greške u postupku.** Sabotažu treba pokretati **samo unutar
transakcije testa**. `create or replace` kroz `psql -f` nad fajlom kojem je skinut `begin;` ostane
komitovan u bazi — sljedeći REST test je zato prijavio *pravo* cross-tenant pisanje (vlasnik A
preimenovao salon B, `200`), kojeg u migraciji nema. `supabase db reset` to čisti, ali dok se ne
primijeti, dokaz laže u oba smjera.

**Ostalo za sljedećeg:**

- **Ekran nije otvoren uživo.** Dokaz je widget test na `1440×900` i `402×874` plus REST test nad
  pravim PostgREST-om; vizuelno poređenje sa canvasom `3i` nije rađeno. Nastavlja se sa
  `./tool/run_tenant.sh` i prijavom kao `admin@barberstudiovitez.test`.
- **Četiri stvari iz canvasa `3i` namjerno nisu nacrtane**, jer nisu u DoD-u i nemaju šemu iza
  sebe: naslovna fotografija, „Lista čekanja" (`salon_settings` nema takvo polje), „Obavijesti
  klijentima" i „Pristup" (korisnici i uloge — svoj task). Kontrola koja ne radi je gora od
  kontrole koje nema.
- `max_advance_booking_days` je na ekranu ograničen na 1–365; baza traži samo `> 0`. Gornja
  granica je procjena, ne pravilo iz specifikacije.
- Usput vraćen `rest_working_hours.ts` u CI — task 34 ga je upisao samo u `tool/test_supabase.sh`,
  pa je dotad bio dokaz koji se vrti isključivo na razvojnoj mašini.
