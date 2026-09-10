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
