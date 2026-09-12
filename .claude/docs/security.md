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

- **Upis `customers` i svi `devices` upisi** i dalje nemaju validiranu funkciju. `book_appointment`
  traži da klijent **već postoji** — upsert identiteta u klijenta dolazi sa auth radom (Sprint 2).
- **Direktan admin `insert`/`update` nad `appointments` zaobilazi validaciju slota.** Exclusion
  constraint sprječava preklapanje, ali radno vrijeme, blokade i `min_advance_booking_hours` ne
  provjerava niko na tom putu. Admin ekran mora ići kroz `book_appointment`.
- **Termin bez dodijeljenog radnika nije pokriven constraintom** (`where employee_id is not null`).
  `book_appointment` uvijek dodijeli radnika; takav red može nastati samo ručnim upisom, i
  `get_available_slots` ga zato konzervativno tretira kao zauzeće cijelog salona.
- **Brisanje/anonimizacija naloga** dolazi u kasnijoj migraciji.

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
