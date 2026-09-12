---
name: continuous-work
description: Radi taskove redom bez nadzora — task po task, PR po PR, dok ne ponestane taskova ili sesije.
argument-hint: "[NN NN NN] — bez argumenta ide redom po tabeli sprinta"
---

# Continuous work

Petlja koja uzima taskove iz `tasks/` **redom**, provodi svaki kroz puni `/task` ciklus i ostavlja
otvoren PR, pa odmah kreće na sljedeći. Namijenjena je da se pokrene i ostavi: sesija radi dok ne
ponestane nezablokiranih taskova ili dok ne pukne context.

Ovo **nije** novi proces. Svaki korak je postojeći `/task` korak — ovaj skill samo ukida pauzu
između taskova i propisuje šta se radi umjesto pitanja kad nema kome da se postavi.

## Prije pokretanja

**Permisije.** Petlja bez nadzora nema smisla ako svaka komanda traži klik. Sesija se pokreće sa:

```sh
claude --dangerously-skip-permissions
```

ili se u već pokrenutoj sesiji uključi `/permissions` → **bypassPermissions**. Skill **ne dira**
`.claude/settings.json` ni `settings.local.json` — nema širenja permisija koje ostaje uključeno
nakon sesije. `PreToolUse` hook za `main` i dalje radi; to je i poenta (v. „Šta se nikad ne radi").

**Provjeri prije prve iteracije:**

```sh
git status --short && gh auth status && gh pr list --state open
```

Prljavo radno stablo → prvo ga riješi (commit na granu ili stash), petlja ne kreće preko tuđih izmjena.

## Orijentacija (jednom, na početku sesije)

Sesija je vjerovatno već pukla jednom. Stanje se **rekonstruiše iz repoa**, ne pamti:

1. `tasks/CURRENT.md` — ima li aktivnog taska i u kojem je statusu.
2. `git branch --show-current`, `git log --oneline -5`, `gh pr list --state open` — postoji li grana
   i PR za taj task, i dokle je stigao.
3. Tabela u `tasks/sprint-N/README.md` — oznake ✅ / 🟡 i status blokovi.

Zatim reci u jednoj rečenici odakle nastavljaš i kreni. Ne pitaj za potvrdu.

## Red taskova

Bez argumenta: redom po tabeli u `tasks/sprint-2/README.md` (pa sljedeći sprint kad se isprazni).
Sa argumentom (`/continuous-work 13 14 22`): samo ti brojevi, tim redom.

Task se uzima samo ako su mu **zavisnosti iz kolone „Blokira" gotove** — ✅ u tabeli, ili 🟡 čiji
ostatak ne dira ono što ovaj task treba. Task koji nije spreman se preskače i nastavlja se dalje;
na kraju sesije se nabroji šta je preskočeno i zašto.

## Iteracija — jedan task

Za svaki task, redom, bez preskakanja:

1. **`/task load <NN>`** — DoD naspram stvarnog stanja repoa. Korak 4 te akcije redovno nađe da je
   dio taska već isporučen; to skraćuje posao, ne opravdava preskakanje.
2. **`/task start`** — grana sa svježeg `main`-a, status `U toku`, 🟡 u tabeli.
   **Stacked grana:** ako task zavisi od prethodnog čiji PR još nije mergan, grana kreće sa te
   grane, a PR ide `--base <roditeljska-grana>`. To je izuzetak od „baza je `main`"
   (`.claude/docs/ai-interaction.md` §6) koji je ovdje izričito dogovoren — mora pisati u opisu PR-a,
   sa napomenom da se rebase-uje na `main` kad roditelj bude mergan.
3. **Implementacija korak po korak.** Prije koda za korak pročitaj dokument koji taj korak spominje
   (`security.md` za `supabase/`, `tenant-factory.md` za flavore, `prototype/ui/SPEC.md` za ekrane).
4. **Commit i push nakon svakog zaokruženog koraka**, ne na kraju taska. Sesija puca bez najave —
   ono što nije na remoteu ne postoji. Draft PR se otvara odmah nakon prvog commita.
5. **`/task review`** — DoD stavku po stavku plus subagent po tipu diffa (`rls-auditor`,
   `dart-reviewer`, `flutter-ui-reviewer`). Nalazi se popravljaju prije verifikacije.
6. **`/task verify`** — recept iz `/verify` za taj tip promjene, sa **stvarnim izlazom** u status blok.
7. **`/task complete`** — status blok, tabela, dokumenti po tabeli sinhronizacije iz `CLAUDE.md`,
   commit, `gh pr ready`.
8. **Vrati se na `main`** (`git checkout main && git pull`) i kreni na sljedeći task. PR ostaje
   otvoren — merga korisnik.

Između iteracija ne rezimiraj opširno: jedan red o tome šta je zatvoreno i koji task ide sljedeći.

## Dokaz dok je CI blokiran

GitHub Actions je blokiran do **29.09.2026.** — crven ček na PR-u nije nalaz i ne popravlja se.
`/task complete` korak 7 („sačekaj CI") se do tada zamjenjuje lokalnim dokazom:

```sh
melos run format && melos run analyze && melos run test
dart run tool/gen_flavors.dart --check     # ako je dirano generisano
./tool/test_supabase.sh                    # ako je dirano supabase/
./tool/verify_clean.sh                     # čist checkout, umjesto CI-ja
```

U PR opis ide stvaran izlaz tih komandi i rečenica da CI čeka reset kvote. Ono što traži macOS,
uređaj ili emulator se imenuje kao nedokazano — ne prepričava se kao dokazano.

## Kad nešto zapne

Petlja nema kome postaviti pitanje, pa umjesto pitanja ostavlja **zapis**:

| Situacija | Šta se radi |
|---|---|
| Treba tuđa konzola, ključ, keystore, nalog | Uradi sve što ide bez toga. Status blok dobije 🟡 sa tačnom listom šta fali i gdje se to unosi; isto u tabelu sprinta i u PR opis. Task se zatvara kao 🟡, petlja ide dalje. |
| Nova zavisnost (`pubspec.yaml`, `package.json`) | Ne dodaje se. Napiši u status blok koju zavisnost bi trebalo i zašto, riješi bez nje ako se može, inače 🟡. |
| Traži se veći refaktor ili promjena arhitekture | Ne radi se usput. Zapiši kao prijedlog u status blok (ili ADR nacrt u `docs/adr/` ako je odluka), uradi najmanju izmjenu koja zatvara task. |
| Isti korak pada treći put | Stani sa tim taskom. Zapiši šta je probano i šta je pretpostavljeni uzrok, ostavi granu i PR kakvi jesu (draft), pređi na sljedeći task. Ne uklanjaj provjeru koja pada. |
| Task se pokaže većim nego što je raspisan | Zatvori dio koji je zaokružen i dokazan, ostatak u „ostalo za sljedećeg" sa komandom za nastavak. Ne sužavaj task tiho. |

Nijedan od ovih slučajeva ne zaustavlja petlju — zaustavljaju je samo uslovi ispod.

## Kontekst i kompaktiranje

Petlja je napisana da preživi kraj context windowa — ali preživljava samo ono što je **u repou**,
ne ono što je u chatu. Zato se kontekst ne čeka da pukne, nego se pripremi.

**Kompaktiranje ne pokrećem ja.** Nema alata kojim bih ga zvao; `/compact` je komanda koju kuca
korisnik, a Claude Code ionako sam kompaktira kad prozor dođe do kraja. Ono što je u mojim rukama
je da taj trenutak ne košta ništa: da se stanje uvijek može rekonstruisati iz `git`-a i
`tasks/`, bez ijedne rečenice iz chata.

**Znakovi da je trenutak blizu:** prošao je cijeli task, upravo je otvoren ili zatvoren PR,
`melos run test` je odrađen i dokaz je zapisan, ili se u istoj sesiji već prošlo kroz dva-tri
taska.

**Šta se tada radi — checkpoint, redom:**

1. Sve što je urađeno je commitovano i **pushovano**. Nedovršen korak ide kao `wip:` commit na
   granu, ne ostaje u radnom stablu.
2. `tasks/CURRENT.md` opisuje stvarno stanje: koji task, koja grana, koji PR, šta je dokazano i
   šta je sljedeći korak. Piše se za nekoga ko **nije vidio ovu sesiju** — jer nakon
   kompaktiranja to je tačan opis mene.
3. Dokaz koji je pokrenut u ovoj sesiji (izlaz `melos run test`, `./tool/verify_clean.sh`) ide u
   status blok taska ili u PR opis. Izlaz komande koji postoji samo u chatu nestaje sa chatom, a
   tvrdnja bez izlaza više nije dokaz.
4. Jedna rečenica korisniku: gdje je stalo i koji task ide sljedeći.

Nakon kompaktiranja se **ne nastavlja po sjećanju** — radi se „Orijentacija" sa vrha ovog
dokumenta: `tasks/CURRENT.md`, `git branch --show-current`, `git log --oneline -5`,
`gh pr list --state open`, pa tabela sprinta. Stanje je u repou; chat je bio samo put do njega.

Ako je posao takav da checkpoint ne stane između koraka (migracija napola, generator u toku),
završi taj korak pa checkpoint — polovična migracija u `wip:` commitu je gora od jednog koraka
više.

## Kad petlja staje

- Nema više nezablokiranih taskova u redu.
- Radno stablo je u stanju koje se ne može automatski riješiti (konflikt pri `git pull`, npr.).
- Korisnik je upao u sesiju.

Pri stajanju napiši kratak izvještaj: zatvoreni taskovi sa brojevima PR-ova, taskovi zatvoreni kao
🟡 i šta im fali, preskočeni taskovi i zašto, i koji task ide prvi sljedeći put.

## Šta se nikad ne radi

- **Ne merga se PR i ne briše se grana.** Ni kad su svi testovi zeleni. To je korisnikov potez.
- **Ne commituje se na `main`.** `PreToolUse` hook pita — u bypass modu ne pita, pa pravilo čuvaš ti.
- **Ne mijenjaju se permisije u `.claude/settings.json` ni u `settings.local.json`.**
- **Ne diraju se generisani fajlovi rukom** — mijenja se `tenant.yaml`, pa se pokrene generator.
- **Ne commituju se tajne**, ni „privremeno da testiram".
- **Ne izmišlja se dokaz.** Komanda koja nije pokrenuta nije dokaz, a „kod izgleda ispravno" nije
  verifikacija. Nedokazano se piše kao nedokazano.
- **Ne oslanja se na chat kao na skladište stanja.** Sve što sljedeća iteracija treba mora biti
  u repou prije nego što kontekst pukne — v. „Kontekst i kompaktiranje".
- **Nema potpisa AI-ja** u commitu ni u PR opisu.
