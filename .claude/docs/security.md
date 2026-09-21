# Sigurnost i autorizacija

Ovaj dokument opisuje jedini dio sistema gdje greška ne pravi bug nego curenje: **tenant izolaciju**.
Salon A ne smije vidjeti nijedan red salona B, a klijent ne smije vidjeti ništa osim svojeg.
Sve tvrdnje ovdje odgovaraju `supabase/migrations/20260910090000_init_schema.sql` i
`20260910090500_auth_identity.sql`. Ako promijeniš politiku, promijeni i ovaj dokument u istoj promjeni.

## Zlatno pravilo

**Svaki red pripada salonu, i svaka putanja do njega mora to dokazati.** Ne postoji upit "svi
termini", ne postoji "dohvati pa filtriraj u Dartu", ne postoji endpoint koji vraća listu salona za
identitet. Filtriranje na klijentu nije izolacija — to je izolacija koju vidiš samo ti, ne i
PostgREST.

Praktično: **RLS je jedina odbrana koja stvarno stoji.** Flutter kod ne šalje `salon_id` kao mjeru
sigurnosti nego kao izbor konteksta; ono što ga ograničava su politike u bazi.

## Tri identiteta i šta svaki od njih smije

| Ko | Kako se prepoznaje | Smije |
|---|---|---|
| **anon** (neprijavljen) | bez JWT-a | čita aktivne salone, njihove aktivne usluge i radnike, mapiranja, radno vrijeme, postavke, **objavljene recenzije** (uz agregat `salon_rating_summary`), **pravila korištenja sa politikom privatnosti** i bezlični `availability_signals` red salona. **Nema nijedan write grant.** |
| **klijent** | JWT bez privilegovane uloge (`private.is_client()`) | sve što i anon, plus **svoj** `auth_identities` red, i **svoj** `customers`/`appointments`/`devices` red **u salonu iz `x-salon-id`** |
| **osoblje** | `app_metadata.role = salon_admin` **i** red u `public.users` sa istim `salon_id` | upravljanje podacima **svog** salona; validirani upisi termina, uređaja i usluga idu kroz RPC |
| **super admin** | `app_metadata.role = super_admin` **i** red u `public.users` sa `role='super_admin'` | sve; iznad tenant izolacije |

**Uloga u tokenu sama po sebi ne znači ništa.** `private.is_super_admin()` i `private.is_admin()`
oba traže i claim iz JWT-a **i** postojeći red u `public.users`. Falsifikovan ili zastario token bez
članstva u bazi ne prolazi. `user_metadata` je isključivo prikazni podatak i nikad se ne koristi u
odluci o pristupu — korisnik ga može mijenjati sam.

### Pisanje admin naloga rukom — dvije zamke

`seed.sql` od taska 23 nosi po jednog `salon_admin` za oba demo salona. Ko bude pisao takav red
ponovo (novi tenant, test fixture, migracija podataka), tu su dvije stvari koje se **ne vide u
bazi** nego tek na ekranu za prijavu:

- **Oba uslova moraju postojati istovremeno.** `raw_app_meta_data` sa `role` i `salon_id` (odatle
  GoTrue puni JWT) **i** red u `public.users`. Samo jedan od njih daje korisnika koji se uspješno
  prijavi i **ne vidi nijedan red** — na ekranu izgleda kao prazna baza, a zapravo je pogrešno
  postavljen nalog. Admin app to razlikuje i daje drugu poruku nego za pogrešnu lozinku.
- **Nullable text kolone u `auth.users` moraju biti prazan string, ne `NULL`.** GoTrue ih skenira u
  Go `string`, pa `NULL` obara prijavu sa `500 Database error querying schema` — porukom koja ne
  kaže koja je kolona kriva. Red pritom izgleda ispravno u `psql`, i **cijela pgTAP suita prolazi**,
  jer pgTAP glumi claimove kroz `set_config` i nikad ne prolazi kroz GoTrue. Kolone su
  `confirmation_token`, `recovery_token`, `email_change`, `email_change_token_new`,
  `email_change_token_current`, `phone_change`, `phone_change_token`, `reauthentication_token`;
  seed ih puni petljom, da nova kolona u budućoj verziji GoTrue-a ne obori prijavu nijemo.

Ovo drži `rest_admin_login.ts` — jedini test u repou koji pada ako se u admin app-i ne može
prijaviti.

## `private.*` — gdje živi autorizacija

Sve provjere su `security definer` funkcije u `private` shemi sa `set search_path = ''`. Politike ih
zovu; ne pišu logiku same. Kad dodaješ tabelu ili politiku, **zovi postojeću funkciju** umjesto da
prepisuješ uslov — prepisan uslov je uslov koji se sljedeći put ispravi na jednom mjestu od tri.

| Funkcija | Odgovara na |
|---|---|
| `private.salon_active(uuid)` | postoji li taj salon i je li `status='active'` |
| `private.is_super_admin()` | claim **i** red u `users` sa `role='super_admin'` |
| `private.is_admin(uuid)` | super admin, ili `salon_admin` čiji se claim `salon_id` poklapa sa argumentom **i** sa redom u `users` |
| `private.client_salon_id()` | koji salon je klijent izabrao kroz `x-salon-id`, ako je aktivan; inače `NULL` |
| `private.owns_identity(uuid)` | je li taj `auth_identities` red moj i nije obrisan |
| `private.is_client()` | nije `super_admin`, `salon_admin` ni `employee` |

`search_path = ''` nije stil: bez toga `security definer` funkcija može biti navučena na tabelu iz
tuđe sheme. Sve reference su zato potpuno kvalifikovane (`public.users`, ne `users`).

## `x-salon-id` bira kontekst, ne daje prava

Klijentska app radi u jednom salonu odjednom i to kaže headerom. `private.client_salon_id()`:

- pročita `request.headers` → `x-salon-id`,
- vrati ga **samo ako je to aktivan salon**,
- vrati `NULL` na sve ostalo, uključujući neispravan UUID (hvata se `invalid_text_representation`).

`NULL` znači **"nema konteksta"**, i sve klijentske politike ga tretiraju kao "ništa se ne vidi",
jer `salon_id = NULL` nikad nije istinito. To je namjerno: nedostajući ili pokvaren header ne
smije slučajno otvoriti globalni pogled.

Header uvijek ide **uz** provjeru vlasništva (`private.owns_identity(...)`), nikad umjesto nje.
Header kaže *gdje* gledam; identitet kaže *šta je moje*. Sam header ne dokazuje ništa — pošiljalac
ga bira.

## Grantovi: prvo sve oduzeto, pa vraćeno taksativno

Migracija na svakoj od 16 tabela radi `enable row level security`, pa
`revoke all ... from anon, authenticated`, pa `grant all to service_role`. Tek onda se vraća tačno
ono što treba: `select` javnog kataloga za `anon` i `authenticated`, i uži `insert/update/delete` set
za `authenticated`.

**Nova kolona je druga priča od nove tabele.** Grantovi su pisani tabelarno
(`grant select on public.services to anon, authenticated`), ne kolonski, pa nova kolona ulazi u
postojeći grant sama, a politika je `using(...)` nad redom i ne nabraja kolone. To je udobno, ali
znači i da se **ne vidi iz migracije** — da su grantovi ikad postali kolonski, nova kolona bi bila
nevidljiva `anon`-u i javni katalog bi tiho izgubio podatak. Zato svaka nova kolona u javnom
katalogu dobija aserciju u `rest_public_catalog.ts`, koja je traži **bez tokena** (task 22).

Zato **nova tabela nije automatski dostupna** i **mora dobiti i grant i politiku**. Tabela sa
politikom bez granta je nevidljiva; tabela sa grantom bez politike je nevidljiva dok neko ne doda
politiku koja je previše široka. `config.toml` namjerno ne postavlja `auto_expose_new_tables`.

Isto važi za funkcije: `revoke all on all functions in schema private from public`, pa eksplicitan
`grant execute` po funkciji. Nova `private.*` funkcija koju politika treba mora dobiti svoj grant.

## Agregat je isto tako izlaz — `salon_rating_summary`

`public.reviews` nosi običnu politiku (`is_published and private.salon_active(salon_id)`), ali
ekran recenzija ne čita redove nego **prosjek i histogram**. Taj sažetak daje pogled
`public.salon_rating_summary`, i pogled je mjesto gdje izolacija najlakše tiho padne:

- **`with (security_invoker = true)` nije opcija nego uslov.** Bez njega pogled radi sa pravima
  svog vlasnika i zaobilazi RLS tabele ispod — `anon` tada dobije prosjek koji uključuje sakrivene
  recenzije i neaktivne salone. Ništa ne pukne, samo je broj drugi.
- **Zato je curenje napravljeno vidljivim kao vrijednost.** Seed drži jednu sakrivenu jedinicu, pa
  je tačan prosjek `4.8`, a procurio `4.7`. Test koji broji redove ovo ne bi uhvatio; test koji
  mjeri prosjek hvata. Asercije su u `006_reviews.test.sql` i `rest_public_catalog.ts`, i obje su
  provjerene tako što je opcija uklonjena i test pao.

Pravilo koje iz ovoga slijedi: **svaki novi pogled nad tabelom sa RLS-om ide sa
`security_invoker = true`**, i dobija asercij nad vrijednošću, ne nad brojem redova.

## Tabela bez `salon_id` — `app_policies`

Pravilo „svaka nova tabela nosi `salon_id`" ima dva namjerna izuzetka: `vertical_packs` i, od
taska 21, **`public.app_policies`**. Oba nose isti oblik politike — `using(true)` za čitanje,
`private.is_super_admin()` za pisanje — i oba postoje zato što je podatak **platformski**, ne
tenantski.

Kod pravila razlog nije udobnost nego odgovornost. Šest sekcija sa `15-pravila-koristenja.png`
nisu iste vrste: Zakazivanje, Cijene i Vaši podaci obavezuju **firmu pod čijim imenom app stoji u
storeu**; Otkazivanje, Kašnjenje i Kontakt obavezuju salon. Te druge žive u `public.salon_policies`
(`salon_id`, `private.is_admin(salon_id)` za CRUD, `private.salon_active(salon_id)` za javno
čitanje). Politika privatnosti je u cijelosti platformska i `check (document = 'terms')` na
`salon_policies` to provodi u bazi, ne u komentaru.

**Negativan test koji ovo drži je `salon_admin` nad `app_policies`.** `insert` mora pasti na
`42501`, a `update`/`delete` pogoditi **nula** redova — grant postoji, zaustavlja ga politika, pa
asercija ide na učinak (v. „`update` sa klijenta ne baca"). Provjereno obaranjem: `super_manage`
oslabljen na `private.is_admin(...)` ili na `true` obara četiri asercije u
`007_policies.test.sql`. Kad bi te asercije otišle, tenant bi mogao prepisati izjavu o obradi
ličnih podataka koju firma ne vidi.

Obrazloženje oblika i odbačene opcije (jedna tabela sa nullable `salon_id`, `jsonb` na
`salon_settings`, kolona na `salons`): `docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`.
Jedna tabela sa nullable `salon_id` je odbijena baš zbog `NULL` grane u guardu — isti oblik koji je
u tasku 14 pustio zahtjev bez `x-salon-id` headera.

## Kompozitni strani ključevi — druga brava

Politike provjeravaju *ko* pita. Kompozitni FK-ovi provjeravaju *da li podaci uopšte pripadaju
zajedno*: termin ne može pokazivati na radnika ili uslugu iz drugog salona ni kad payload nosi
ispravan `salon_id`. To hvata klasu grešaka koju RLS ne vidi — napad kroz ispravno autorizovan
zahtjev sa pomiješanim ID-evima. Kad dodaješ tabelu vezanu za salon, nosi `salon_id` i veži se
kompozitno, ne samo po `id`.

## Rezervacija — jedini put kojim termin nastaje

`public.book_appointment(...)` (`20260911090000_availability_engine.sql`) je jedina funkcija kojom
klijent ili admin kreira termin. `security definer` je, dakle zaobilazi RLS, pa autorizaciju radi
sama i eksplicitno: **admin salona**, ili **klijent koji je vlasnik tog `customers` reda u salonu
iz `x-salon-id`**. Nepostojeći klijent i tuđi klijent vraćaju **istu** grešku (`42501`) — inače bi
funkcija bila endpoint za nabrajanje tuđih klijenata.

Slot se **re-validira u istoj transakciji** neposredno prije upisa, a preklapanje hvata i
exclusion constraint `appointments_no_overlap` na nivou tabele. Oboje je namjerno: provjera prije
upisa ne pomaže kad dva zahtjeva stignu istovremeno, a constraint sam ne zna za radno vrijeme.
Konflikt izlazi kao `PT409`, što PostgREST prevodi u HTTP `409`.

Na Dart strani ovu funkciju zove **isključivo** `BookingRepository.book(...)` (task 11) — jedini
upis u cijeloj aplikaciji. `PostgrestException.code` tada nosi `PT409`, **ne** `409`: status se
prevodi, kod u tijelu odgovora ne. `mapError` zato mapira oba (v. `error_mapper.dart`); da mapira
samo `409`, konflikt bi ispao `ServerError` i korisnik bi na zauzet termin dobio generičku grešku
umjesto osvježene liste. Isto vrijedi za `PT404` iz iste funkcije.

`get_available_slots` i `get_available_dates` su takođe `security definer` jer čitaju
`appointments` i `blocked_slots`, koje `anon` ne smije vidjeti. Izlaz su samo izvedena slobodna
vremena — nijedan podatak o klijentu. Pregled slobodnih termina zato ne traži prijavu, a
rezervacija traži (`grant execute ... to authenticated`).

### `blocked_slots` se od taska 31 čita i iz aplikacije

Do kalendara je ta tabela postojala samo kao ulaz u `security definer` funkcije iznad — ništa u
Dartu je nije dodirivalo. Admin kalendar je čita direktno (`BlockedSlotRepository.forDay`), i to je
ispravno: `staff_manage` politika iz init migracije (`for all ... using(private.is_admin(salon_id))`)
presijeca na članstvo, pa admin koji pošalje tuđi `salon_id` dobije **praznu listu**, ne tuđe
blokade. Klijentska app je i dalje ne čita i ne smije — njoj je blokada odsustvo slota, a ne podatak.

**Grantovi ovdje nisu isti kao nad `appointments`.** Init migracija daje
`select,insert,update,delete` nad `blocked_slots` roli `authenticated` i nikad ih nije oduzela, za
razliku od `appointments`, gdje ih je task 24 povukao da bi „samo kroz `rpc`" bila tvrdnja baze a ne
konvencija. Prijavljen `salon_admin` zato **može** direktno upisati i obrisati blokadu — provjereno
pozivom u tasku 31, ne čitanjem migracije. Repozitorij svejedno samo čita; pisanje i odluka ide li
kroz validiranu funkciju pripadaju tasku 34.

### Cjenovnik — aktivno je javno, neaktivno je tenant podatak

Aktivne `services` redove namjerno čita i `anon`: cjenovnik mora raditi prije prijave. Zato tvrdnja
„admin A ne može pročitati aktivnu uslugu salona B" nije sigurnosna granica — isti red može
pročitati neprijavljen korisnik. Granica je da drugi salon ne vidi **neaktivni** red kroz
`staff_manage` i ne može promijeniti nijedan red.

Od taska 32 `authenticated` nad `services` ima samo `select`. Kreiranje, izmjena i promjena
`is_active` idu kroz `create_service`, `update_service` i `set_service_active`; sve tri su
`security definer`, traže `private.is_admin(p_salon_id)` i za nepostojeći i tuđi ID vraćaju istu
`42501`. Fizičko brisanje nije aplikacijska operacija: deaktivacija čuva termine i
`employee_services` veze za historiju i moguću ponovnu aktivaciju.

Termin snapshotuje `service_name`, `service_price` i `service_duration_minutes` triggerom prije
upisa. Pozivalac te vrijednosti ne bira. Promjena cjenovnika zato utiče na budući availability i
nove rezervacije, ali ne prepisuje dogovorenu cijenu ni trajanje postojećeg termina.

### Realtime availability bez otvaranja termina

Klijentski `appointments` stream ne može osvježiti slot nakon **tuđe** rezervacije: politika
`own_appointments` ispravno sakrije taj red. Širenje te politike bi riješilo UX tako što bi
napravilo curenje. Migracija `20260916120000_availability_realtime.sql` zato uvodi
`public.availability_signals` sa samo dvije kolone: `salon_id` i nasumični `revision_id`.

- `anon` i `authenticated` imaju samo `select`, i samo za aktivan salon;
- nema datuma termina, vremena, klijenta, statusa ni kumulativnog broja promjena;
- `private.bump_availability_signal()` je trigger-only `security definer` bez app execute granta;
- trigger mijenja reviziju nakon promjene usluga, radnika, mapiranja, radnog vremena, termina,
  blokada ili booking postavki;
- tabela je u `supabase_realtime` publikaciji; događaj znači samo „ponovo pozovi
  `get_available_slots`", nikad „vjeruj payloadu kao izvoru slotova".

Povezani klijent može zaključiti da se availability nekad promijenio — to je nužno da bi se lista
osvježila — ali tabela ne čuva vrijeme ni brojač prometa. Grantovi, RLS, oblik kolona, izolacija
drugog salona i članstvo u publikaciji drži `010_availability_realtime.test.sql`.

## Šta još nije zatvoreno

Ovo su poznate rupe, ne previdi. Ne piši kod koji se oslanja na to da su zatvorene:

- **`devices` upisi** su zatvoreni validiranim RPC-ovima iz taska 25, v. „Push uređaji" ispod.
  `customers` je **zatvoreno** u tasku 14, v. odjeljak ispod.
- ~~**Direktan admin `insert`/`update` nad `appointments` zaobilazi validaciju slota**~~ —
  **zatvoreno** u tasku 24, v. „Admin akcije" ispod.
- **Termin bez dodijeljenog radnika nije pokriven constraintom** (`where employee_id is not null`).
  `book_appointment` uvijek dodijeli radnika; takav red može nastati samo ručnim upisom **kroz
  `service_role`** (migracija, seed) — od taska 24 `authenticated` više nema `insert` grant, pa iz
  aplikacije ne može nastati. `get_available_slots` ga i dalje konzervativno tretira kao zauzeće
  cijelog salona.
- ~~**Brisanje/anonimizacija naloga**~~ — **zatvoreno** u tasku 17, v. odjeljak ispod.

## Upsert klijenta — `public.ensure_customer`

Drugi i zadnji put kojim klijentska app piše u bazu (uz `book_appointment`). `security definer`,
pa autorizaciju radi sama:

- **identitet se izvodi iz tokena** (`auth.uid()` → `auth_identities`), nikad ne stiže kao
  argument. Da stiže, funkcija bi bila način da se napravi klijent vezan za tuđu osobu;
- **salon mora doći iz `x-salon-id`** i poklopiti se sa `p_salon_id`. Argument sam po sebi ne
  dokazuje ništa — pošiljalac ga bira;
- osoblje je namjerno **isključeno**: admin unos telefonskih klijenata je drugi tok sa drugom
  validacijom (Sprint 3);
- `on conflict do nothing`, ne `do update`: drugi poziv ne prepisuje ime koje je salon ispravio.

Nepostojeći identitet, tuđi salon i neprijavljen pozivalac vraćaju **istu** grešku (`42501`).

> **Dvije zamke nađene testom, ne čitanjem** (task 14) — obje vrijede za svaku sljedeću
> `security definer` funkciju u ovom repou:
>
> 1. **`not (A and B)` je rupa kad `B` može biti `NULL`.** `private.client_salon_id()` vraća `NULL`
>    za nedostajući header; `true and NULL` je `NULL`, `not NULL` je `NULL`, a `if NULL then` se ne
>    izvršava — zahtjev **bez headera** je prolazio kroz guard. Provjeru rastavi i hvataj `NULL`
>    prvi, umjesto da se oslanjaš na to da `not` pretvara nepoznato u odbijanje.
> 2. **`revoke all on function ... from public` ne skida ništa.** Supabase kroz `pg_default_acl`
>    daje `execute` na nove funkcije u `public` shemi **direktno** rolama `anon` i `authenticated`
>    (`select defaclacl from pg_default_acl` → `anon=X/postgres`), ne kroz `PUBLIC`. Nova funkcija
>    koja ne smije biti javna traži **`revoke ... from public, anon`**. Isti propust je stajao na
>    `book_appointment` od taska 05 — tok je bio branjen logikom (`auth.uid()` je `NULL` za `anon`),
>    ali granica koju je ovaj dokument opisivao nije postojala. Zatvoreno u istoj migraciji.


## Tajne

- Ništa iz `supabase status -o env` ne ide u repo. Service role ključ zaobilazi RLS u potpunosti i
  smije postojati samo u CI secretsima i na serveru.
- `google-services.json` u `apps/client/android/app/src/<flavor>/` je **placeholder** koji generator
  proizvodi. Pravi fajl dolazi iz CI secreta kad se FCM uključi; ne commituj ga.
- iOS potpisni materijal (certifikati, profili) nikad u repo.
- `supabase/tests/rest_isolation.ts` odbija remote host i briše samo svoje UUID fixture. Ne mijenjaj
  to ponašanje da bi "testirao na stagingu" — test koji smije pisati po tuđoj bazi je test koji će
  jednom obrisati tuđe podatke.

## Checklist prije nego što otvoriš PR koji dira `supabase/`

1. Ima li nova tabela `salon_id`, RLS uključen, **i** grant **i** politiku? Ako namjerno nema
   `salon_id` (kao `vertical_packs` i `app_policies`), stoji li razlog u ADR-u i negativan test
   da tenant ne može pisati po njoj?
2. Zove li politika `private.*` helper umjesto da prepisuje uslov?
3. Je li klijentska politika vezana i za `private.client_salon_id()` **i** za `private.owns_identity()`?
4. Može li se osoblje jednog salona domoći reda drugog salona kroz join, view ili FK?
5. Vidi li `anon` samo ono što je javni katalog aktivnog salona? (`get_available_slots` je izuzetak
   koji je promišljen: izvedena vremena, bez podataka o klijentu.)
6. Je li dodan pgTAP test koji **pada** ako se politika ukloni? Politika bez negativnog testa je
   pretpostavka.
7. Je li suite prošla lokalno (`supabase start && supabase test db` + dva Deno REST testa)? Na
   `main`-u to ponovi workflow `Supabase tests` iz čistog checkouta — v. `.claude/docs/workflows.md`.

## Otkazivanje — `public.cancel_appointment`

Treći i zadnji put kojim klijentska app piše u bazu. `security definer`, sa istom strukturom kao
`ensure_customer`:

- vlasništvo se izvodi iz tokena, salon iz `x-salon-id`, i oboje mora stajati;
- **rok vrijedi za klijenta, ne za salon.** `salon_settings.min_cancel_hours` zaustavlja klijenta
  (`PT403` → HTTP 403); salon otkazuje kad mora, i tada klijent dobije obavijest, ne zabranu;
- `cancelled_by` kaže **ko** je otkazao (`customer` / `salon` / `system`) — admin ekran i
  statistika zavise od toga, a `system` je istekao `pending` i piše ga scheduler;
- **idempotentno**: već otkazan termin vraća isti red bez greške. Dva uređaja i dva tapa nisu kvar.

Nepostojeći i tuđi termin vraćaju **istu** grešku (`42501`).

> **`update` sa klijenta ne baca — ne radi ništa.** `authenticated` *ima* `update` grant na
> `appointments` i `customers`; ono što ga zaustavlja je odsustvo klijentske `for update` politike,
> pa RLS filtrira sve redove i `update` pogodi **nula** redova. Nula redova nije greška u
> Postgresu. Test koji od direktnog `update`-a očekuje `42501` će zato pasti — a tvrdnja je
> pogrešna, ne kod. Asercija ide na **učinak** (red je netaknut). `insert` je druga priča: njega
> hvata `with check` politike i on stvarno baca.

## Admin akcije nad terminima — `set_appointment_status` i ručni unos

Task 24. Ovaj odjeljak zatvara rupu koju je gornja lista godinu dana vodila kao otvorenu.

**Rupa nije zatvorena dodavanjem funkcija nego oduzimanjem granta.** Dok je `authenticated` imao
`insert`/`update` na `appointments`, svaka validirana funkcija bila je konvencija: admin je mogao
jednim PostgREST pozivom upisati termin u nedjelju u 3 ujutro. Migracija
`20260914150000_admin_akcije_nad_terminima.sql` zato radi:

```sql
revoke insert, update on public.appointments from authenticated;
```

`select` i `delete` ostaju — greškom unesen termin salon mora moći obrisati, a brisanje ne može
proizvesti nevalidan raspored. `staff_manage` politika (`for all`) ostaje netaknuta: ona brani
**tuđi salon** i to i dalje radi za `select` i `delete`.

Od tada u `appointments` pišu samo tri `security definer` funkcije:

| Funkcija | Ko | Šta radi |
|---|---|---|
| `book_appointment` | admin ili vlasnik `customers` reda | jedini upis novog termina |
| `set_appointment_status` | admin salona | `confirmed` / `completed` / `no_show` |
| `cancel_appointment` | admin ili vlasnik | `cancelled`, sa rokom koji vrijedi samo klijentu |

**Otkazivanje namjerno nije u `set_appointment_status`.** Ono nosi rok iz
`salon_settings.min_cancel_hours` i `cancelled_by`; dvije funkcije koje pišu isti status bile bi
dva mjesta na kojima se pravilo o roku može razići. `set_appointment_status` zato odbija
`cancelled` sa `PT400` i uputi na `cancel_appointment`.

### Admin izuzetak vrijedi samo za `min_advance_booking_hours`

`get_available_slots` je dobio peti argument `p_ignore_min_advance`. Salon upisuje klijenta koji
stoji na vratima, a prag od 2 h to zabranjuje — prag je pravilo **prema klijentu**, ne fizičko
ograničenje salona. Isti oblik kao `min_cancel_hours`, koji takođe obavezuje klijenta a ne salon.

**Radno vrijeme, pauze, blokade i preklapanje vrijede i za admina.** Izuzetak nulira jedan `where`
uslov i ništa više; pgTAP to drži sa dvije strane — ručni termin u nedjelju u 3 ujutro je odbijen,
i lista sa izuzetkom nikad nije kraća ni duža nego što prag opravdava.

**Klijent izuzetak ne može dobiti ni greškom**: `p_ignore_min_advance` nije argument
`book_appointment` nego izvedena vrijednost iz `private.is_admin(p_salon_id)`. Da je argument,
klijentska app bi ga mogla poslati.

> **Zamka: `create or replace` sa novim parametrom pravi preopterećenje, ne zamjenu.** Obje verzije
> ostaju u bazi, obje sa grantom, a PostgREST bira po imenima argumenata iz tijela zahtjeva — poziv
> bez `p_ignore_min_advance` bi i dalje išao na staru funkciju, onu koja ne zna za izuzetak, pa bi
> ručni unos tiho radio po starom pravilu. Migracija zato ima `drop function if exists` nad starim
> potpisom **prije** `create`. Nađeno upitom nad `pg_proc`, ne čitanjem.

### Telefonski klijent — `upsert_walkin_customer`

`ensure_customer` (task 14) je namjerno isključio osoblje: identitet tamo dolazi iz tokena, a
telefonski klijent nema token. `upsert_walkin_customer` je taj drugi tok — samo admin salona,
`auth_identity_id` ostaje `null`.

To nije propust nego suština: čovjek koji je salon nazvao telefonom nema nalog. Ako se kasnije
prijavi u aplikaciji, `ensure_customer` pravi **zaseban** red, jer po telefonu ne može dokazati da
je to on. Spajanje ta dva reda je odluka salona iz admin ekrana, ne baze koja pogađa po broju.

Za razliku od `ensure_customer`, ovdje je `do update` a ne `do nothing`: tamo bi drugi poziv
prepisao ime koje je salon ispravio, a **ovdje ispravku piše sam salon**.

### Ručni termin je odmah `confirmed`

`pending` znači „salon još nije odgovorio". Kad salon sam upisuje termin, odgovor je sam upis —
ostavljen `pending` bi čekao potvrdu od onoga ko ga je već potvrdio i istekao bi kroz
`pending_expires_at`. Zato admin put daje `confirmed` + `source = 'manual'` + `pending_expires_at
is null`, i potvrda postojećeg termina takođe skida rok isteka.

### Brojači se pune, prag ne postoji

`no_show` diže `customers.no_show_count`, `completed` diže `visit_count` i `last_visit_at`. Obje
kolone su do sada bile mrtve. **Prag („tri nedolaska u šest mjeseci") namjerno nije provođen** — on
je pravilo vertikale (`vertical.features.noShowTracking`) i traži vlastitu odluku u Sprintu 3.
Brojač se puni sada da statistika ne počne od nule kad ekran dođe.

`cancel_reason` nosi obrazloženje **svake** akcije, ne samo otkazivanja: kolona je imenovana po
prvom slučaju, a odbijanje („radnik na bolovanju") i no-show („nije se pojavio") su isti podatak —
zašto termin nije održan.

## Brisanje naloga — `public.delete_my_account`

Četvrti i zadnji upis kojim klijentska app dira bazu. Apple traži da brisanje bude **u
aplikaciji**, ne link na mail podrške (`docs/06` §8.2) — bez njega iOS submission pada.

**Ovo je jedini upis u repou koji namjerno prelazi granicu salona**, i zato traži da se pročita
prije nego što se kopira kao obrazac. Sve ostalo je tenant-scoped; identitet nije. Isti čovjek
može biti klijent u više salona (task 15), a brisanje naloga je odluka o **osobi**. Salon-scoped
verzija bi obrisala nalog u jednom salonu i ostavila ime u drugom, bez ijednog ekrana s kojeg bi
korisnik to mogao ponoviti.

Granica je zato pomjerena sa salona na **identitet**: funkcija dira isključivo redove vezane za
`auth_identities` red pozivaoca. **`x-salon-id` se namjerno ne traži** — ne bi ništa dokazao, a
sugerisao bi salon-scoped operaciju koja ovo nije. Pravilo „header uvijek ide uz provjeru
vlasništva" time nije prekršeno: ostala je provjera vlasništva, otpao je izbor konteksta.

Dvokoračno je, i **redoslijed nije kozmetički**:

1. `public.delete_my_account()` — soft-delete identiteta (`deleted_at`) i anonimizacija, pod
   tokenom korisnika;
2. Edge Function `delete-account` — `auth.admin.deleteUser` nad `auth.users`, pod service role
   ključem, koji nikad ne smije u klijentsku app.

Obrnuto bi pad drugog koraka ostavio `customers` red sa punim imenom i telefonom, a korisnikov
token više ne bi postojao — ne bi imao čime ponoviti brisanje. Ovako je najgori ishod siroče u
`auth.users`, uz nalog koji je **već neupotrebljiv**.

**Sam `deleted_at` gasi pristup svemu** — gate je ušiven od init migracije (`private.owns_identity`,
politike `own_identity`/`own_customer`/`own_appointments`, `ensure_customer`, i trigger
`sync_auth_identity` koji radi `on conflict do update ... where deleted_at is null`). Nijedna nova
politika nije trebala. Trigger je najvažniji: bez tog `where` bi sljedeća prijava istim mailom
**uskrsnula** obrisani nalog.

> **Denormalizovani lični podaci su druga polovina brisanja.** `appointments` nosi
> `customer_name`, `customer_phone` i `customer_note` kao vlastite kolone, ne samo `customer_id`.
> Anonimizacija koja dira samo `customers` ostavlja puno ime i telefon u svakom terminu tog
> čovjeka — obrisan nalog čije ime i dalje stoji u salonovoj listi nije obrisan nalog. Svaka
> sljedeća tabela koja kopira lični podatak mora ući i ovdje.

Šta ostaje, a šta odlazi:

| Ostaje | Odlazi |
|---|---|
| `customers` red, `visit_count`, `no_show_count`, `first_seen_at` | `name` → „Obrisan klijent", `phone` → `NULL`, `note` → `NULL` |
| `appointments` red: datum, vrijeme, usluga, radnik, status | `customer_name`, `customer_phone`, `customer_note` |
| `auth_identities` red (kao nadgrobni kamen) | `email`, `display_name`, `providers` |

Dvije zamke iz šeme: `customers.name` je `not null` pa mora dobiti tekst, a `unique(salon_id,
phone)` znači da `phone` mora ići na **`NULL`** — konstanta bi oborila drugu anonimizaciju u istom
salonu.

**Rok `min_cancel_hours` se ovdje ne primjenjuje.** Budući termini se otkazuju bez obzira na rok:
nalog koji se ne može obrisati zato što je termin sutra nije nalog koji se može obrisati. Cijena je
otkazivanje u zadnji čas, pa `cancel_reason` kaže zašto, a `cancelled_by` je `customer` — čovjek je
to pokrenuo, `system` ostaje scheduleru.

`supabase_user_id` se **zadržava** do drugog koraka: dok `auth.users` red postoji, on je jedino što
sprječava da trigger napravi novi identitet za istog korisnika. Brisanjem `auth.users` ga FK
`on delete set null` sam pretvori u `NULL`, pa sljedeća prijava istim mailom dobije čist nalog.

Osoblje je namjerno isključeno (`private.is_client()`): admin nalog je salonov podatak i ne gasi ga
ekran u klijentskoj app-i. Posljedica koju treba znati — ko je istovremeno `salon_admin` ne može
obrisati svoj klijentski nalog iz app-e.

> **`update` na `auth_identities` baca, ne filtrira tiho.** Ovo je izuzetak od pravila opisanog kod
> otkazivanja: `appointments` i `customers` *imaju* `update` grant za `authenticated`, pa ih
> zaustavlja tek odsustvo politike — nula redova, bez greške. `auth_identities` ima samo
> `grant select` i samo `for select` politiku, pa update pada na samom grantu (`42501`). Asercija
> zato ide na **grešku**, ne na učinak. Nađeno pokretanjem: prva verzija testa je očekivala tihi
> filter i oborila cijeli fajl.

## Čime je izolacija dokazana

Tvrdnje iz ovog dokumenta nisu opis namjere nego opis onoga što suite provjerava. Kad mijenjaš
politiku, mijenjaj i test — i **provjeri da test pada kad politiku oslabiš**, inače ne testira
ništa.

| Test | Šta dokazuje |
|---|---|
| `001_tenant_isolation.test.sql` | politike na nivou SQL-a, po roli |
| `002_availability.test.sql` | `book_appointment` i `PT409` na nivou baze |
| `003_customer_upsert.test.sql` | `ensure_customer` — NULL u guardu, grantovi, idempotentnost |
| `rest_isolation.ts` | dva stvarna JWT-a; `user_metadata` ne širi pristup |
| `rest_public_catalog.ts` | katalog radi **bez** tokena, sa kolonama koje `core_api` stvarno šalje |
| `rest_customer_upsert.ts` | cijeli put app-e: prijava → identitet → klijent → termin → HTTP 409 |
| `004_cancel_appointment.test.sql` | `cancel_appointment` — vlasništvo, rok, `cancelled_by`, oslobađanje slota |
| `rest_cross_salon_isolation.ts` | isti čovjek u dva salona; admin A ne vidi salon B kroz `id`, `auth_identity_id`, embed ni header |
| `005_delete_my_account.test.sql` | brisanje naloga — anonimizacija u **oba** salona, otkazivanje budućih termina, gašenje pristupa, trigger ne uskrsava nalog |
| `007_policies.test.sql` | pravila i politika privatnosti — `anon` čita bez prijave, **`salon_admin` ne može pisati po `app_policies`**, sekcije neaktivnog salona su nevidljive |
| `rest_delete_account.ts` | brisanje kroz Edge Function sa pravim JWT-om; obrisan identitet dobija **`200` sa praznom listom**, ne `401` — pristup gasi `deleted_at`, ne istek tokena |
| `rest_admin_login.ts` | **seed admin se stvarno prijavi kroz GoTrue** i vidi samo svoj salon; tuđi `x-salon-id` ne mijenja šta vidi, upis u tuđi salon je `403`, `anon` je `401` |

> **Test koji mjeri kalendar ne mjeri kod.** Tri testa u ovoj suiti su bila zelena samo u
> dijelu dana ili sedmice, i sva tri su nađena tek pokretanjem u tasku 17 — `004` je padao
> poslije 09:30 (pomjerao je `start_time` a ostavljao `end_time`, pa je padao na
> `check(end_time > start_time)` i obarao cijeli fajl), `002` je padao svakog ponedjeljka
> (`mon - 7` je početak *tekuće* sedmice, dakle ponedjeljkom danas), a `rest_public_catalog`
> je padao od trenutka kad je barber salon dobio sve fotografije. Nijedan se nije vidio, jer
> je CI blokiran, pa suitu niko nije pokrenuo van jednog doba dana. Kad test zavisi od
> `now()`, biraj vrijednost koja je **uvijek** na pravoj strani granice, i provjeri da ne
> prolazi iz drugog razloga (zatvoren dan umjesto prošlog datuma).

**Curenje kroz embed i kroz filter je češće od curenja kroz direktan upit.** Admin zna
`auth_identity_id` — on stoji u njegovom vlastitom redu — pa je filter po njemu prvo što bi
probao. Isto vrijedi za `select=*,customers(...)`: kompozitni FK-ovi ga čine dvosmislenim
(`PGRST201`, HTTP **300**), ali to je prepreka koja traži samo da se pročita poruka o grešci.
Svaki novi REST test zato mora tretirati `300` kao grešku, ne kao uspjeh.
## Push uređaji — Task 25

`register_device` dozvoljava anonimnu registraciju u aktivnom salonu iz `x-salon-id`, zatim
vezanje na vlastiti `auth_identities` red iz JWT-a. Gost iz budućeg auth toka takođe ima svoj
JWT/identitet. `p_staff=true` zahtijeva admin claim i odgovarajući `public.users` red u salonu;
admin app salon izvodi iz članstva. ID identiteta i vlasnika nisu RPC argumenti.

UUID instalacije nije dokaz vlasništva. Aplikacija čuva zasebnu nasumičnu tajnu od 32 bajta u
Keychain/secure storage; baza čuva samo SHA-256 hash u `private.device_credentials`, bez
klijentskih grantova. Postojeći uređaj se mijenja samo uz istu tajnu. Anon/klijent nema direktne
`insert/update/delete` grantove na `devices`. `unregister_device` provjerava tajnu i salon,
uklanja token/identitet i gasi `queued` poruke; radi i kada sesija više ne postoji.

Trigger `validate_appointment_device` dodatno provjerava da FK iz termina pripada istom
klijentskom identitetu, uz postojeći kompozitni FK za salon. Sam salon nije dovoljan za vezanje
tuđeg uređaja. Promjena naloga gasi poruke koje čekaju, a claim ponovo provjerava aktivan salon,
identitet koji nije obrisan i postojeće staff članstvo.

`notification_logs` se puni triggerom promjene termina. Samo `service_role` smije pozvati
`claim_push_notifications`; korisnik ne bira ni primaoca ni sadržaj slanja. Unique ključ i
`FOR UPDATE SKIP LOCKED` sprečavaju ponovno preuzimanje istog događaja. Klijentski SELECT nad
logovima nije uveden; `/notifications` je i dalje prazno stanje.

Cron čita Vault i šalje HMAC nad `send-push:<unix-sekunde>`, valjan 60 sekundi. **Trajna tajna
ne ide kroz `pg_net`**: njegove objekte posjeduje `supabase_admin`, a lokalni `postgres` ne može
oduzeti sve postojeće grantove. Worker odbija obični anon/korisnički JWT. Kratki replay može
samo pokrenuti idempotentno preuzimanje već postojećeg reda.

Isporuka na uređaj nije dokazana lokalnim testovima. `sent` znači FCM prihvat. Neponovljiv
`sending`/`failed` red može zahtijevati operativnu intervenciju; detalji i ograničenje exactly-once
su u `supabase/functions/send-push/README.md`. Već predatu poruku odjava ne može povući, zato je
tekst generički i detalji se ponovo čitaju uz RLS.

Dokaz: `009_push_devices.test.sql` (izolacija, claim, scenariji i transport u rollbacku),
`rest_push_devices.ts` (dva stvarna JWT-a i dva salona) i `send-push/handler_test.ts` (autorizacija,
duplikati i nepoznat ishod). Anon registracija je javni RPC; produkcijski gateway mora ograničiti
zloupotrebu broja registracija prije javnog puštanja. Mutacija `own_devices using(true)` je
oborila test „Drugi klijent ne vidi prvi uređaj”; rollback je vratio politiku i suite je opet zelena.
