# Task 06 — `VerticalPack` + `Vertical` klasa u `core_domain`

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [02 — schema + RLS](02-supabase-schema-rls.md) (treba `VerticalPack` tabelu), [01 — repo skeleton](01-repo-skeleton.md) (treba `core_domain` paket) |
| **Blokira** | svaki ekran koji prikazuje tekst — doslovno prvi ekran u Sprint 1 |
| **Reference** | [01 §10](../docs/01-mvp-spec.md#10-customization--white-label) · [05 vertical-packs.md](../docs/05-vertical-packs.md) |

## Cilj
Terminologija (frizer/beautician/doktor, "termin"/"pregled", radna pravila po vertikali) je **config koji se čita u runtime-u**, nikad hardkodiran string u widgetu — postavljeno prije prvog ekrana, jer je popravka poslije prepisivanje svakog ekrana koji je već napisan.

## Definicija gotovog
- [ ] `packages/core_domain/lib/src/vertical/vertical.dart` definiše `Vertical` klasu: `key`, `terms` (mapa termina: `appointmentLabel`, `providerLabel`, `serviceLabel`, ...), `defaultSettings`, `defaultTheme`
- [ ] Seed podaci za `barber` i `beauty` vertikale (bar te dvije za MVP, [05 §2](../docs/05-vertical-packs.md))
- [ ] `VerticalPack` tabela u Supabase (iz taska 02) ima `key`, `terminology` (JSONB), `defaultSettings` (JSONB), `defaultTheme`, `defaultServices` (JSONB) popunjenu seed migracijom
- [ ] `core_api` repozitorij učitava `VerticalPack` za dati `salonId` i mapira ga na `Vertical` iz `core_domain`
- [ ] Mehanizam (provider/inherited widget) koji čini `vertical.terms.*` dostupnim kroz cijelo stablo widgeta u `apps/client`
- [ ] Lint pravilo ili barem konvencija u `CONTRIBUTING`/code review checklisti: **nijedan literal string vezan za uslugu/pružaoca/termin ne ide direktno u widget** — mora ići kroz `vertical.terms.*`
- [ ] `Salon.verticalPackKey` i `Salon.terminologyOverride` (nullable JSONB) postoje u šemi za per-salon override iznad vertikalnog default-a
- [ ] Test: promjena `vertical.terms.appointmentLabel` sa "Termin" na "Pregled" mijenja tekst na ekranu bez rebuild-a app-a (dokaz da je zaista runtime, ne compile-time)

## Koraci
1. Definiši `Vertical` i `VerticalTerms` klase u `core_domain` (freezed, immutable)
2. Popuni seed za `barber` (frizer, termin, usluga) i `beauty` (beautician, termin, tretman) — v. [05 §2](../docs/05-vertical-packs.md) za tačnu terminologiju
3. Dodaj `VerticalPack` seed red u `supabase/seed.sql` (nastavak taska 02) za oba demo salona
4. Napiši `VerticalRepository` u `core_api` koji čita `VerticalPack` po `salonId`, primjenjuje `Salon.terminologyOverride` preko default-a
5. Napravi Riverpod provider (`verticalProvider`) koji izlaže trenutni `Vertical` cijeloj app-i nakon što se salon učita
6. Napiši jedan placeholder ekran koji koristi `vertical.terms.appointmentLabel` da dokažeš da mehanizam radi end-to-end (baza → repo → provider → widget)
7. Dokumentuj konvenciju u `CONTRIBUTING.md` ili top-level komentaru u `core_domain` — "svaki vertical-zavisan string ide ovuda, ne kao literal"
8. Commit: "feat(domain): VerticalPack — runtime terminology, barber + beauty seed"

## Zašto ovo prije prvog pravog ekrana
[01 §17](../docs/01-mvp-spec.md#17-build-order) ovo eksplicitno naziva "2–3 dana rada koje, ako se odgode, znače kasnije prepisivanje svakog ekrana" — čak i ako je prvi klijent frizer i "za sada" nema potrebe za vertikalama, cijena odgađanja je veća od cijene rađenja odmah, jer svaki naredni ekran koji ne prati ovu konvenciju je dug koji se plaća pri prvom dentalnom ili beauty klijentu.
