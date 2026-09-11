# Modeli žive u `core_domain` i nose `fromJson`

## Status

prihvaćen

## Kontekst

[Task 08](../../tasks/sprint-1/08-core-api-repozitoriji.md) uvodi prve modele javnog kataloga
(`Salon`, `Service`, `Employee`, `WorkingHour`, `SalonSettings`, `Appointment`). Tri postojeća
izvora su davala tri različita odgovora na pitanje gdje ti modeli stoje:

- **Korak 1 samog taska** traži čiste entitete u `core_domain` i odvojene DTO klase sa mapiranjem
  u `core_api` — "entitet ne smije znati kako izgleda payload".
- **[`.claude/docs/architecture.md`](../../.claude/docs/architecture.md)** opisuje `core_api` kao
  sloj koji drži "Supabase repozitorije, **modele**, greške".
- **Task 06 je već isporučio treću varijantu**: `Vertical` stoji u `core_domain` i **ima**
  `Vertical.fromJson`, koji čita `vertical_packs` red zajedno sa `salons.terminology_override`.

Odluka se nije mogla odgoditi: oblik prvog modela određuje oblik svih ostalih, a prepravka poslije
znači dirati svaki ekran koji ih koristi.

## Odluka

**Jedan model po entitetu, u `core_domain`, sa `fromJson` na sebi.** Nema odvojenih DTO klasa.

`core_api` drži repozitorije, mapiranje grešaka i Riverpod providere — ne modele. Codegen
(`freezed`, `json_serializable`, `build_runner`) je zato podešen u `core_domain`, ne u `core_api`
kako DoD taska 08 doslovno kaže.

Granica koja ostaje na snazi: `core_domain` i dalje **ne smije** zavisiti od Fluttera ni od mreže.
`freezed_annotation` i `json_annotation` su čist Dart i nose samo anotacije, pa to pravilo ne krše.

## Razmatrane opcije

- **Entitet u `core_domain` + DTO u `core_api`** (doslovno po koraku 1) — odbačeno. Šest modela
  postaje dvanaest klasa plus šest `toEntity` funkcija, a sve tri kopije nose ista polja. Cijena je
  stvarna i plaća se na svakoj izmjeni šeme; korist je teoretska sve dok postoji tačno jedan izvor
  podataka. Ako se ikad pojavi drugi izvor sa drugačijim payloadom (drugi backend, keš na disku),
  ovo se ponovo otvara — i to je novi podatak koji bi tražio novi ADR.
- **Modeli u `core_api`** (doslovno po `architecture.md`) — odbačeno. Terao bi `Vertical` da se
  preseli iz `core_domain`, ili da ostane kao trajni izuzetak koji svako sljedeći mora objasniti
  sebi. Uz to bi `core_ui` i buduća domenska logika morali uvesti `core_api` — a time i
  `supabase_flutter` — da bi uopšte imenovali `Salon`.
- **Ostaviti kako jeste i odlučivati po modelu** — odbačeno. To nije odluka nego njeno odgađanje, i
  rezultat je da svaki sljedeći model dobije oblik po tome ko ga je pisao.

## Posljedice

- **`architecture.md` je ispravljen u istoj promjeni** — red koji je tvrdio da modeli žive u
  `core_api` sada kaže suprotno i pokazuje na ovaj ADR.
- **Codegen je u `core_domain`**, pa `melos run codegen` mora proći prije `analyze` i `test` na
  svježem klonu. Generisani fajlovi nisu u gitu — v.
  [ADR-0002](0002-generisani-fajlovi-se-commituju.md), koji vrijedi za `tenants.g.dart` (izlaz
  generatora nad `tenant.yaml`), ne za izlaz `build_runner`-a nad anotacijama. Ta dva se u gitu
  tretiraju suprotno i `.gitignore` to eksplicitno razdvaja.
- **Entitet zna kako izgleda payload.** To je svjesno prihvaćena cijena. Praktična posljedica:
  preimenovanje kolone u migraciji mijenja `@JsonKey` u `core_domain`, a ne u `core_api` — i to je
  mjesto gdje se traži kad se šema i model raziđu.
- **`MappingError` postoji baš zbog ovoga.** Kad payload ne odgovara modelu, repozitorij to ne
  pušta kao `TypeError` iz generisanog koda nego kao grešku koja se u logu čita kao "šema i model
  su se razišli".
