<!--
Naslov PR-a prati Conventional Commits, isto kao commit: feat(client): …
Puna konvencija: .claude/docs/ai-interaction.md §6
-->

## Cilj

<!-- Jedna do dvije rečenice: šta ovaj PR rješava. Link na task: tasks/NN-….md -->

Task:

## Šta je promijenjeno

<!--
Po dijelovima sistema, ne po fajlovima. Generisane fajlove izdvoji i reci iz kojeg
ulaza su nastali — ne čitaju se kao ručno pisan kod.
-->

-

## Dokaz

<!--
Stvarni izlaz, ne prepričan. Komanda + skraćen izlaz, ili link na CI run.
Provjerava se artefakt, ne konfiguracija iz koje je nastao (v. /verify).
-->

```

```

## Šta NIJE provjereno

<!--
Obavezno popuniti — prazno znači "sve je provjereno" i tako će biti pročitano.
Tipično: nema Dockera lokalno (supabase/ ide na CI), nema macOS-a (iOS), nema uređaja,
traži tuđi nalog ili tajnu.
-->

-

## Dokumenti ažurirani u istoj promjeni

<!-- Tabela sinhronizacije je u CLAUDE.md. Označi šta je promjena dotakla. -->

- [ ] `.claude/docs/security.md` — šema, RLS, `private.*`, grantovi
- [ ] `.claude/docs/architecture.md` — struktura, slojevi, tok podataka
- [ ] `.claude/docs/tenant-factory.md` + `tenants/README.md` — generatori, `tenant.yaml`, flavori
- [ ] `.claude/docs/conventions.md` — obrazac pisanja koda
- [ ] `.claude/docs/workflows.md` — komanda, CI job, env varijabla
- [ ] `CONTEXT.md` — domenski pojam
- [ ] `docs/adr/` — odluka koja se ne vidi iz koda
- [ ] `tasks/CURRENT.md`, task fajl i `tasks/sprint-<N>/README.md` — status i "ostalo za sljedećeg"
- [ ] Ništa od navedenog nije dotaknuto

## Provjere

- [ ] `melos run analyze`, `dart format --set-exit-if-changed`, `melos run test` prolaze
- [ ] `dart run tool/gen_flavors.dart --check` prolazi (ako je dirano `tenants/`, `tool/` ili flavori)
- [ ] `Supabase tests` job je **zelen** (ako je dirano `supabase/`) — napisana politika nije dokazana politika
- [ ] Novi tenant je dodan u **sve tri** CI matrice (`build-flavors`, `build-ios`, `release-artifacts`)
- [ ] Nema tajni, artefakata ni ručno editovanih generisanih fajlova u diffu

## Za recenzenta

<!-- Zamke koje si našao, mjesta gdje ti treba drugo oko, odluke o kojima nisi siguran. -->

-
