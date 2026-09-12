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
| **anon** (neprijavljen) | bez JWT-a | čita aktivne salone, njihove aktivne usluge i radnike, mapiranja, radno vrijeme i postavke. **Nema nijedan write grant.** |
| **klijent** | JWT bez privilegovane uloge (`private.is_client()`) | sve što i anon, plus **svoj** `auth_identities` red, i **svoj** `customers`/`appointments`/`devices` red **u salonu iz `x-salon-id`** |
| **osoblje** | `app_metadata.role = salon_admin` **i** red u `public.users` sa istim `salon_id` | pun CRUD nad podacima **svog** salona |
| **super admin** | `app_metadata.role = super_admin` **i** red u `public.users` sa `role='super_admin'` | sve; iznad tenant izolacije |

**Uloga u tokenu sama po sebi ne znači ništa.** `private.is_super_admin()` i `private.is_admin()`
oba traže i claim iz JWT-a **i** postojeći red u `public.users`. Falsifikovan ili zastario token bez
članstva u bazi ne prolazi. `user_metadata` je isključivo prikazni podatak i nikad se ne koristi u
odluci o pristupu — korisnik ga može mijenjati sam.

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

Migracija na svakoj od 15 tabela radi `enable row level security`, pa
`revoke all ... from anon, authenticated`, pa `grant all to service_role`. Tek onda se vraća tačno
ono što treba: `select` javnog kataloga za `anon` i `authenticated`, i uži `insert/update/delete` set
za `authenticated`.

Zato **nova tabela nije automatski dostupna** i **mora dobiti i grant i politiku**. Tabela sa
politikom bez granta je nevidljiva; tabela sa grantom bez politike je nevidljiva dok neko ne doda
politiku koja je previše široka. `config.toml` namjerno ne postavlja `auto_expose_new_tables`.

Isto važi za funkcije: `revoke all on all functions in schema private from public`, pa eksplicitan
`grant execute` po funkciji. Nova `private.*` funkcija koju politika treba mora dobiti svoj grant.

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

## Šta još nije zatvoreno

Ovo su poznate rupe, ne previdi. Ne piši kod koji se oslanja na to da su zatvorene:

- **`devices` upisi** i dalje nemaju validiranu funkciju — dolaze sa push radom (task 25).
  `customers` je **zatvoreno** u tasku 14, v. odjeljak ispod.
- **Direktan admin `insert`/`update` nad `appointments` zaobilazi validaciju slota.** Exclusion
  constraint sprječava preklapanje, ali radno vrijeme, blokade i `min_advance_booking_hours` ne
  provjerava niko na tom putu. Admin ekran mora ići kroz `book_appointment`.
- **Termin bez dodijeljenog radnika nije pokriven constraintom** (`where employee_id is not null`).
  `book_appointment` uvijek dodijeli radnika; takav red može nastati samo ručnim upisom, i
  `get_available_slots` ga zato konzervativno tretira kao zauzeće cijelog salona.
- **Brisanje/anonimizacija naloga** dolazi u kasnijoj migraciji.

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

1. Ima li nova tabela `salon_id`, RLS uključen, **i** grant **i** politiku?
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

**Curenje kroz embed i kroz filter je češće od curenja kroz direktan upit.** Admin zna
`auth_identity_id` — on stoji u njegovom vlastitom redu — pa je filter po njemu prvo što bi
probao. Isto vrijedi za `select=*,customers(...)`: kompozitni FK-ovi ga čine dvosmislenim
(`PGRST201`, HTTP **300**), ali to je prepreka koja traži samo da se pročita poruka o grešci.
Svaki novi REST test zato mora tretirati `300` kao grešku, ne kao uspjeh.
