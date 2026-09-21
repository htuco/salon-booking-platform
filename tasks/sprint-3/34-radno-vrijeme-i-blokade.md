# Task 34 — Radno vrijeme, pauze i blokade

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [33](33-osoblje-i-smjene.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3h` `3s` · [01 §8.1](../../docs/01-mvp-spec.md) |

## Cilj
Salon sam postavlja radno vrijeme, pauze i neradne dane. To je posljednji dio availability ulaza
koji se danas mijenja samo u bazi.

## Definicija gotovog
- [x] `/working-hours` po `3h`, mobilno `3s`
- [x] Radno vrijeme po danu, pauze, neradni dani i blokade po radniku
      (blokada bira radnika na ekranu; **radnikov sedmični raspored** ide kroz RPC, bez ekrana —
      v. „ostalo za sljedećeg")
- [x] Sve kroz RPC, sa izolacijom po salonu; pgTAP na svaku putanju pisanja
- [x] **Availability ostaje na backendu.** Ekran mijenja ulaz u `get_available_slots`, ne pravila
- [x] Postojeći termin koji ispadne van novog radnog vremena se **ne briše tiho** — admin ga vidi
- [x] Promjena se odmah vidi u klijentskoj app-i, dokazano upitom i prolazom kroz ekran

## Koraci
1. Migracija + pgTAP, pa ugovor, pa ekran
2. Provjera protiv klijentske app-e: promjena u adminu mijenja slotove u klijentu
3. Commit: `feat(admin): radno vrijeme, pauze i blokade`

## Zamke
- **Odluka koja se ne otvara:** availability logika je na backendu, nikad u app-i
  (`docs/01 §8.1`). Ekran koji sam računa slobodne termine je ista greška kao prosjek ocjena
  računat u Dartu iz taska 20.
- **Admin izuzetak vrijedi samo za `min_advance_booking_hours`** (task 24). Radno vrijeme, pauze i
  blokade vrijede i njemu.
- Dan salona nije nužno kalendarski dan — vremenska zona i prelazak preko ponoći imaju svoj slučaj.

## Status (2026-09-21)

Gotovo. [PR #57](https://github.com/htuco/salon-booking-platform/pull/57).

**Backend prvo, ekran drugi** — istim redom kao taskovi 32 i 33. Pet novih funkcija:
`set_working_hours`, `create_blocked_slot`, `delete_blocked_slot`, plus dvije `stable` funkcije
čitanja konflikata. Direktan `insert/update/delete` nad `working_hours` i `blocked_slots` je
oduzet roli `authenticated`.

**Zatvorena rupa koju je task 31 izričito ostavio ovdje.** Init migracija je nad obje tabele
davala pun grant, pa je „samo kroz `rpc`" bila konvencija a ne tvrdnja baze — task 31 je to
provjerio pozivom i odluku ostavio ovom tasku. Sada je tvrdnja, kao nad `appointments` (task 24)
i `employees` (task 33).

**Sedmica se piše u cjelini, i to nije stil ugovora.** `get_available_slots` čita **odsustvo reda
kao zatvoreno**, ne kao „nije podešeno", pa bi slanje samo izmijenjenih dana tiho zatvorilo
ostale. Ulaz je zato `working_hours_input[]` od tačno sedam dana, sa provjerom da je svaki ISO dan
prisutan tačno jednom — provjera dužine sama propušta šest dana plus duplikat. Upis je upsert, pa
ID-evi redova prežive izmjenu.

**Termin se ne briše tiho.** `working_hours_conflicts` i `blocked_slot_conflicts` su `stable`
funkcije čitanja koje ekran zove **prije** upisa — upozorenje stiže prije posljedice, a odluka
ostaje vlasniku. Aplikacija ne pomjera i ne otkazuje nijedan termin.

**Widget testovi su našli dva stvarna preliva na telefonu** (106 px, pa 70 px): red dana i red
pauze ne stanu u 402 px kao jedan `Row`. Vremena su sada ispod imena na `3s`, a red pauze je
`Wrap`. Na desktopu (`3h`) raspored ostaje kakav canvas crta.

**`flutter-ui-reviewer` je našao da reset stanja ne radi, i tri stvari uz njega.** Najskuplja je
bila tiha: `ValueKey(sve.length)` je trebao osvježiti uređivač poslije snimanja, ali
`weekFromWorkingHours` **uvijek** vraća sedam, pa je ključ bio isti prije i poslije i lokalno
stanje je preživjelo. Radilo je jedino u prelazu 0 → 7 — jedinom slučaju koji je moj test
pokrivao. Posljedica: „Sačuvaj izmjene" ostaje aktivno poslije uspješnog upisa, pa vlasnik snima
isto dvaput. Zamijenjeno `didUpdateWidget`-om koji poredi **sa `_dani`**, ne sa
`oldWidget.pocetna`: baza vrati upravo ono što je poslano, pa bi poređenje dvije `pocetna` vidjelo
„nema promjene" baš u trenutku kad izmjene treba odbaciti.

Uz to: `Semantics` labele na vremenima **nisu radile** — bez `container`/`excludeSemantics` prave
susjedni čvor, pa je čitač ekrana čitao praznu stavku pa „09:00", i početak se nije razlikovao od
kraja; `Switch` je bio potpuno bez labele (sedam puta „uključeno, prekidač"); dugo ime radnika
prelivalo je dropdown za 296 px; a na skali teksta 2.0 pucala su ista dva reda koja su
popravljena za širinu. Popravljeno je i brisanje blokade (bilo bez potvrde, na jedan tap),
greška pri snimanju (crtala se iznad sedam dana, a dugme je na dnu — sada ide i u snackbar),
i nedostajuće „Pokušaj ponovo" kod blokada.

**Provjera pauze u ekranu sada stvarno postoji.** Doc je tvrdio da je ima, a nije — napisana je
umjesto brisanja tvrdnje, jer `PT400` iz baze kao sirova poruka ne kaže koji je dan kriv.

Tri nove regresije drže sve to, i **sabotaža je provjerena**: uklanjanje `didUpdateWidget` tijela
obara test „poslije snimanja sa sedam redova dugme se gasi".

**`rls-auditor` je našao nedosljedan ugovor greške, i rupu u dokazu ispod njega.** Prvi prolaz je
provjeru pripadnosti radnika imao samo u putanjama pisanja, pa su `working_hours_conflicts` i
`blocked_slot_conflicts` na tuđeg radnika vraćale **praznu listu** umjesto `42501` — potvrđeno
pozivom, ne čitanjem. Curenja nije bilo (`salon_id = p_salon_id` je prvi predikat u oba tijela),
ali prazna lista se ne razlikuje od „nema konflikata", pa je signal bio zamućen, a ugovor različit
između pet funkcija iste migracije. Ozbiljniji nalaz je bio drugi: **`salon_id` predikat u te dvije
funkcije nije imao nijedan test koji bi pao da se ukloni** — 51 asercija bi prošla i da funkcija
vraća termine drugog salona sa `customer_name`. Guard je izdvojen u
`private.assert_salon_access(p_salon_id, p_employee_id)` i zovu ga **sve pet**; dodato je šest
asercija, od kojih dvije čitaju termin drugog salona. **Sabotaža je provjerena**: uklanjanje
`salon_id` predikata sada obara `013` (test 39).

### Dokazi

- `npx supabase db reset && npx supabase test db` — **385 testova, PASS**, od toga 57 novih u
  `013_working_hours_crud.test.sql`.
- `deno run --allow-env --allow-net supabase/tests/rest_working_hours.ts` — **15 provjera** kroz
  stvarni JWT i PostgREST. Skraćeno radno vrijeme, pauza, zatvoren dan i blokada svaki put
  mijenjaju ono što `get_available_slots` vrati klijentu; direktan `insert` vraća `401/403`. Test
  vraća salon u polazno stanje u `finally`.
- `dart run melos run test` — **SUCCESS** (admin 250, core_domain 88, core_api 122, core_ui 67,
  client 234). `dart analyze` bez ijedne primjedbe.
- **Oba CI joba zelena na `68234ab`** (zadnji commit):
  [Analiza, format i testovi](https://github.com/htuco/salon-booking-platform/actions/runs/35614498777)
  (3m43s) i [Schema, RLS and tenant isolation](https://github.com/htuco/salon-booking-platform/actions/runs/35614498450)
  (2m22s). Supabase job je dokaz iz čistog checkouta, koji lokalno pokretanje ne može dati.

### Ostalo za sljedećeg

- **Raspored po radniku nema svoj ekran.** `set_working_hours` prima `p_employee_id` i pgTAP ga
  pokriva, ali `/working-hours` uređuje samo salonski raspored. Radnikov sloj se za sada mijenja
  pozivom funkcije.
- **`/calendar/block` je i dalje placeholder ruta**, ali više ne čeka `rpc`:
  `prikaziUredjivacBlokade` je napisan da ga zovu oba ulaza. Vezivanje na `3c` je sitan posao.
- **„Pravila zakazivanja" iz `3h` nisu ovdje** — `salon_settings` je task 36, kako i stoji u
  njegovom DoD-u.
