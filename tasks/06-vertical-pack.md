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
- [x] `packages/core_domain/lib/src/vertical/vertical.dart` definiše `Vertical` klasu: `key`, `terms` (mapa termina: `appointmentLabel`, `providerLabel`, `serviceLabel`, ...), `defaultSettings`, `defaultTheme`
- [x] Seed podaci za `barber` i `beauty` vertikale (bar te dvije za MVP, [05 §2](../docs/05-vertical-packs.md))
- [x] `VerticalPack` tabela u Supabase (iz taska 02) ima `key`, `terminology` (JSONB), `defaultSettings` (JSONB), `defaultTheme`, `defaultServices` (JSONB) popunjenu seed migracijom
- [x] `core_api` repozitorij učitava `VerticalPack` za dati `salonId` i mapira ga na `Vertical` iz `core_domain`
- [x] Mehanizam (provider/inherited widget) koji čini `vertical.terms.*` dostupnim kroz cijelo stablo widgeta u `apps/client`
- [x] Lint pravilo ili barem konvencija u `CONTRIBUTING`/code review checklisti: **nijedan literal string vezan za uslugu/pružaoca/termin ne ide direktno u widget** — mora ići kroz `vertical.terms.*`
- [x] `Salon.verticalPackKey` i `Salon.terminologyOverride` (nullable JSONB) postoje u šemi za per-salon override iznad vertikalnog default-a
- [x] Test: promjena `vertical.terms.appointmentLabel` sa "Termin" na "Pregled" mijenja tekst na ekranu bez rebuild-a app-a (dokaz da je zaista runtime, ne compile-time)

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

---

## Status (2026-09-11) — ✅ zatvoren

Vertikala je od ovog taska **config koji se čita u runtime-u**, a ne literal u ekranu.

**Šta je isporučeno**

- `packages/core_domain/lib/src/vertical/` — `Vertical`, `VerticalTerms`, `BookingRules`,
  `VerticalFeatures`. Paket je uz to preveden na **čist Dart** (bez `flutter` zavisnosti), kako
  `.claude/docs/architecture.md` i traži za taj sloj.
- `packages/core_api/` — `VerticalRepository` čita `vertical_packs` i `salons.terminology_override`
  **jednim** upitom kroz embed po FK-u.
- `apps/client/lib/src/core/vertical_provider.dart` — `verticalProvider` i `verticalOf(ref)`.
- Placeholder ekran u `main.dart` uzima CTA i nazive iz `vertical.terms`.

**Dokaz** — `melos run analyze` (5/5 paketa "No issues found"), `dart format
--set-exit-if-changed` (0 changed) i `melos run test`: **32 testa PASS** (core_domain 13,
client 12 + 1 skip, core_api 5, admin 1, core_ui 1).

Ključni test je `apps/client/test/vertical_terminology_test.dart` → "promjena terminologije
mijenja tekst bez rebuilda aplikacije": mijenja odgovor repozitorija na **istoj** instanci app-e,
bez `pumpWidget` ispočetka, i potvrđuje da je mehanizam runtime, a ne compile-time.
`tenant_theme_test.dart` sa `--dart-define=SALON_ID=<barber>` i dalje prolazi, sad i sa
terminologijom na ekranu.

**Zamke koje su nas koštale**

- **`core_domain` je bio Flutter paket** iz `flutter create --template=package`. Dok je to tako,
  sloj koji arhitektura opisuje kao "bez Fluttera" tiho zavisi od njega. Testovi zato idu na
  `package:test`, ne `flutter_test` — inače zavisnost uđe na mala vrata.
- **Override mora ići po ključu.** Zamjena cijelog objekta salonu koji mijenja samo
  `customerSingular` obriše ostalih dvanaest termina.
- **PostgREST ugniježđeni objekat zna stići kao `Map<dynamic, dynamic>`** — direktan
  `as Map<String, dynamic>` puca u runtime-u. Pokriveno testom.
- **Regex nad `seed.sql` se ne veže za kraj reda.** Fajl je u repou sa CRLF krajevima, a red
  završava zarezom; `$` je tu dvostruko krhak.
- **`melos run test` pada na paketu koji ima prazan `test/` folder**, ne preskače ga.

**Ostalo za sljedećeg**

- **Ekran još ne čita živu bazu** — `Supabase.initialize` dolazi u
  [tasku 07](sprint-1/07-app-plumbing.md). Dotad `verticalProvider` u testu ide preko override-a,
  a u aplikaciji bi pao na `Vertical.fallback`. Lanac je dokazan do repozitorija, ne kroz mrežu.
- **`dental` i `health` nisu u seedu** — namjerno: nose recall, kartoteku i pristanke
  ([05 §6](../docs/05-vertical-packs.md), §7), što je zaseban task.
- **`freezed` nije upotrijebljen** iako ga korak 1 spominje; `==`/`hashCode` su ručno pisani da se
  `build_runner` ne uvodi u sloj bez ijednog drugog generisanog fajla. Ako paket poraste, ovo je
  prvo mjesto za ponovnu procjenu.
- **Nema lint pravila** koje mehanički zabranjuje literal u ekranu — konvencija je zapisana u
  `core_domain` dokumentaciji i `.claude/docs/conventions.md`, ali je za sada stvar code reviewa.
  Custom lint (`custom_lint`) je opcija kad ekrana bude više.
