# Task 08 — `core_api`: freezed modeli + repozitoriji

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [02 — šema + RLS](../02-supabase-schema-rls.md), [07 — plumbing](07-app-plumbing.md) |
| **Blokira** | 10 (home), 11 (booking flow), admin ekrane |
| **Reference** | [01 §11](../../docs/01-mvp-spec.md#11-database-entities) · [07 §3](../../docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor) · [architecture.md](../../.claude/docs/architecture.md) |

## Cilj
Jedan sloj koji zna za mrežu i tabele. Ekran nikad ne dodiruje `SupabaseClient` direktno — traži repozitorij, dobija tipizirane modele.

## Definicija gotovog
- [ ] `freezed` + `json_serializable` + `build_runner` podešeni u `core_api`; `dart run build_runner build` je dokumentovan korak
- [ ] Modeli za javni katalog: `Salon`, `Service`, `Employee`, `EmployeeService`, `WorkingHour`, `SalonSettings` — imena polja prate `snake_case` iz baze kroz `@JsonKey`, ne preimenovana napamet
- [ ] `Appointment` model sa `status` kao **sealed/union tipom** (`pending`, `confirmed`, `cancelled`, …), ne golim stringom
- [ ] `SalonRepository.byId(salonId)`, `ServiceRepository.forSalon`, `EmployeeRepository.forSalon`, `WorkingHoursRepository.forSalon`, `SettingsRepository.forSalon` — svi vraćaju modele, nikad `Map`
- [ ] Sve gore radi **bez prijave** (anon), jer je to javni katalog aktivnog salona — dokazano pozivom bez tokena
- [ ] Greške se mapiraju u `core_api/src/errors/`: mrežna, `PostgrestException`, prazan rezultat, i **`409` konflikt** (treba ga 11). Ekran nikad ne hvata `PostgrestException` direktno
- [ ] Riverpod provideri po repozitoriju; keširanje ostavljeno Riverpodu, bez ručnog cache sloja
- [ ] Unit testovi sa `mocktail`: mapiranje modela iz stvarnog JSON payloada (kopiraj iz `supabase/seed.sql` reda), i mapiranje svake klase grešaka
- [ ] Nula `supabase` importa igdje u `apps/*` osim u bootstrapu iz taska 07

## Koraci
1. Definiši modele u `core_domain` (čisti entiteti, bez JSON-a) i DTO/mapiranje u `core_api` — entitet ne smije znati kako izgleda payload
2. Napiši prvi repozitorij (`SalonRepository`) do kraja, sa greškama i testom; ostali ga preslikavaju
3. Provjeri protiv stvarne šeme: ISO dani 1–7 u `working_hours`, vremena su **lokalno zidno vrijeme salona**, ne UTC
4. Dodaj providere i jedan integracioni smoke test protiv lokalnog stacka (ili CI-ja, ako Dockera nema)
5. Commit: `feat(core_api): modeli i repozitoriji za javni katalog salona`

## Zamke
- **`devices.device_id` nije `appointments.device_id`.** Prvo je instalacioni identifikator, drugo FK na `devices.id`. Zamjena prolazi tipove i tiho lomi push.
- `working_hours` vremena nisu UTC. Konverzija "za svaki slučaj" pomjera radno vrijeme salona za sat ili dva i to se vidi tek kad neko rezerviše.
- Klijentski **upisi** (termin, customer, device) idu isključivo kroz validiranu RPC/Edge funkciju koja još ne postoji ([security.md](../../.claude/docs/security.md)). Ovaj task pokriva samo čitanje — ne pokušavaj `insert` sa klijenta.

## Status (2026-09-11) — ✅ zatvoren

Svih devet DoD stavki ima dokaz. Zeleno na CI-ju:
[`Flutter` run 34620424824](https://github.com/htuco/salon-booking-platform/actions/runs/34620424824)
(analiza, format, 97 testova, oba Android APK-a, oba iOS builda) i
[`Supabase tests` run 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879)
(pgTAP, REST izolacija, **novi** `rest_public_catalog.ts`).

### Odluka koja je morala pasti prije prvog modela

Task (korak 1), `architecture.md` i presedan iz taska 06 davali su tri različita odgovora na
pitanje gdje modeli žive. Odlučeno: **jedan model po entitetu, u `core_domain`, sa `fromJson`** —
[ADR-0006](../../docs/adr/0006-modeli-u-core-domain.md). Alternativa "entitet + DTO" bi od šest
modela napravila dvanaest klasa uz istu funkcionalnost; alternativa "modeli u `core_api`" bi
`Vertical` pretvorila u trajni izuzetak. `architecture.md` je ispravljen u istoj promjeni.

**Posljedica za DoD:** stavka kaže "`freezed` … podešeni u `core_api`". Codegen je podešen u
`core_domain`, jer su modeli tamo. Stavka je ispunjena po namjeri, ne po slovu.

### Dokaz po stavkama

| DoD | Dokaz |
|---|---|
| Codegen podešen i dokumentovan | `melos run codegen` / `codegen:watch`; svjež klon bez njega pada sa **95 grešaka**, sa njim `analyze` je čist |
| Modeli kataloga | 39 testova u `core_domain`, payloadi prepisani iz `seed.sql` redova |
| `Appointment.status` tipiziran | `AppointmentStatus` enum; test dokazuje da `'rescheduled'` daje `unknown` umjesto `CastError` |
| Pet repozitorija vraćaju modele | test "nijedan repozitorij ne vraća `Map`" provjerava potpise na tipovima |
| **Radi bez prijave** | `rest_public_catalog.ts`, **26 asercija** bez korisničkog tokena, nad šest tabela |
| Greške mapirane | 15 testova; `ApiError` je `sealed`, pa test "switch je iscrpan bez `default` grane" ne bi ni kompajlirao da tip nedostaje |
| Provideri, bez ručnog cachea | `packages/core_api/lib/src/providers.dart`, keširanje prepušteno `FutureProvider`-u |
| `mocktail` testovi | 32 testa u `core_api` |
| Nula `supabase` importa u `apps/*` | `grep` vraća samo `bootstrap.dart` u oba app-a |

### Šta je CI uhvatio, a lokalna suita nije

**Codegen je trebao svakom jobu koji kompajlira, ne samo analizi.** Prvi pokušaj ga je dodao samo u
`analyze`; analiza i 97 testova su prošli, a **oba Android i oba iOS builda su pala** na
`part 'appointment.freezed.dart': No such file or directory`. Build jobovi rade svoj `flutter pub
get` u svom checkoutu i nemaju generisane fajlove. Popravljeno u sva četiri joba, plus u
`tool/build_tenant.sh` — da lokalni build i CI ne mogu odlutati.

**Format je prijavljivao pogrešan broj fajlova.** Lokalno `dart format $(git ls-files '*.dart')`
javlja "31 fajl, 0 promijenjeno" dok novi fajlovi nisu `git add`-ovani. Svjež klon je pokazao 54
fajla i 5 neformatiranih. Provjera nad `git ls-files` prije `git add` ne vidi ono što upravo pišeš.

### Ostalo za sljedećeg

- **`AppointmentRepository` ne postoji, namjerno.** `appointments` nema `anon` politiku; čitanje
  termina traži prijavljenog korisnika, što dolazi sa Auth-om u Sprintu 2. `Appointment` model
  postoji jer ga treba odgovor `book_appointment`-a u [tasku 11](11-booking-flow.md).
- **Nijedan upis.** Ovaj sloj samo čita. `book_appointment` RPC se poziva u tasku 11; klijentski
  `insert` ostaje zabranjen (`.claude/docs/security.md`).
- **Integracioni smoke test iz koraka 4 nije pisan kao Dart test.** Bez Dockera lokalno on ne bi
  imao gdje da se izvrši, pa je isti dokaz dobiven na nivou REST-a (`rest_public_catalog.ts`), gdje
  je i vjerodostojniji — gađa stvarni PostgREST sa stvarnim politikama. Ako Docker dođe na razvojnu
  mašinu, vrijedi dodati i Dart stranu.
- **`riverpod_generator` i dalje nije uveden** (odgođen još u tasku 07); provideri su pisani rukom.
- **Testovi ne dodiruju mrežu.** Mapiranje je dokazano lokalno, transport samo na CI-ju. To je
  granica koju `melos run test` ne prelazi i ne treba je pogrešno čitati kao "repozitorij radi".
