# Rad sa AI-jem — ponašanje, git, commitovi, PR-ovi

Ovaj dokument je **kanonski** za saradnju: kako se ponašam, kako se grana, kako izgleda commit i
kako izgleda PR. Konvencije pisanja koda su u `.claude/docs/conventions.md`, a ljudski sažetak za
kolege u `docs/TEAM_HANDBOOK.md` — oba pokazuju ovdje umjesto da ponavljaju pravila.

## 1. Kako radim

- **Kratko i direktno.** Objašnjavam ono što nije očigledno, ne prepričavam ono što se vidi iz diffa.
- **Ne sužavam zadatak da bih ga zatvorio.** Ako nešto ne mogu dovršiti, dovršim sve ostalo i
  **imenujem** šta je ostalo i zašto — to nije neuspjeh, to je predaja (`/handoff`).
- **Ne dodajem ono što nije traženo.** Nema "korisno bi bilo i…" funkcionalnosti, nema refaktora
  koda koji zadatak ne dira, nema preimenovanja usput.
- **Radim najmanju izmjenu koja rješava zadatak** i pratim postojeći obrazac umjesto da uvodim svoj.
- **Ne brišem fajlove i ne pokrećem destruktivne git komande bez pitanja.** Prije bilo čega
  destruktivnog provjerim `git status` — rad na grani je ovdje često necommitan.
- **Dokaz, ne tvrdnja.** "Kod izgleda ispravno" nije verifikacija. Ako nešto nisam mogao pokrenuti
  (Docker, macOS, uređaj, tuđi nalog), to piše u sažetku i u PR-u, a ne prešuti se.
- **Odluke koje su donesene se ne otvaraju usput.** Tabela u `docs/README.md` i `docs/adr/` vrijede
  dok ne stigne novi podatak; kad stigne, to je ADR, ne usputna promjena koda.

## 2. Kad pitam, a kad odlučim sam

**Odlučim sam:** izbor imena, raspored fajlova unutar postojeće strukture, koji test napisati, kako
formulisati komentar ili dokument, sitnice u kojima bi svako razumno rješenje prošlo.

**Pitam prije nego uradim:**
- veći refaktor ili promjena arhitekture
- nova zavisnost (paket u `pubspec.yaml` ili `package.json`)
- promjena koja dira već deployanu migraciju ili briše podatke
- bilo šta što traži tvoj nalog ili tajnu (keystore, Supabase ključevi, Apple/Google konzole)
- odustajanje od dijela zadatka

**Zapnem li:** ako nešto ne radi nakon dva-tri pokušaja, stanem i objasnim šta sam probao i šta
mislim da je uzrok. Ne nižem nasumične izmjene i ne "popravljam" tako što uklonim provjeru koja pada.

## 3. Radni tok

```
/task load <NN>   → CURRENT.md, DoD naspram stvarnog stanja repoa
/task start       → grana sa main, status U toku
   implementacija korak po korak
/task review      → DoD stavku po stavku + odgovarajući subagent
/task verify      → dokaz po receptu iz /verify
/task complete    → status blok, dokumenti, commit, PR
/handoff write    → ako posao ostaje otvoren za nekog drugog
```

Jedan aktivni task odjednom (`tasks/CURRENT.md`). Jedan task = jedna grana = jedan PR.

## 4. Grane

- Otvaraju se sa `main`, svježe povučenog. PR ide **protiv `main`**.
- Imena: `feat/<kratko>`, `fix/<kratko>`, `chore/<kratko>`, `docs/<kratko>` — kebab-case, bez
  brojeva taskova u imenu (broj je u PR opisu, gdje se može pročitati).
- Grana živi koliko i task. Nakon merge-a se briše, i lokalno i na remoteu.
- **Ne mergujem i ne brišem granu bez tvoje potvrde.**

## 5. Commit konvencija

```
<tip>(<scope>): <šta, u imperativu, na bosanskom, bez tačke>

<zašto — problem koji se rješava, ne prepričan diff>
<zamka koja je nađena, ako je ima>
<dokaz — komanda i stvarni izlaz, ili link na CI run>

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

- **Tipovi:** `feat`, `fix`, `chore`, `docs`, `ci`, `refactor`, `test`.
- **Scope** je dio sistema, ne fajl: `client`, `admin`, `core_api`, `core_ui`, `supabase`, `ci`,
  `tenants`, `tool`, `tasks`.
- **Naslov do ~70 znakova.** Bez tačke na kraju, bez "dodao sam" — imperativ: `dodaj`, `popravi`.
- **Tijelo nosi *zašto* i *dokaz*.** Postojeći `git log` je pisan tako namjerno: šta je bio simptom,
  šta uzrok, i šta je konkretno pokazalo da je popravljeno. To je standard koji se prati.
- **Jedan commit = jedna zaokružena promjena.** Ne miješaj refaktor sa popravkom, ni generisano sa
  ručno pisanim ako se može razdvojiti.
- **Co-Authored-By trailer da, marketinška linija ne.** Nikad "Generated with …" u poruci.
- **Ne commitujem bez tvoje potvrde** dok lokalne provjere ne prođu (`melos run analyze`,
  `dart format`, `melos run test`, `gen_flavors --check` ako je dirano generisano).

**Nikad u commit:** tajne (`.env`, izlaz `supabase status -o env`, service role ključ, pravi
`google-services.json`, iOS potpisni materijal), artefakti (`build/`, APK/AAB/IPA), ručne izmjene
generisanih fajlova.

## 6. PR konvencija

- **Naslov PR-a = naslov commita** (isti Conventional Commits oblik). Kad PR ima više commitova,
  naslov opisuje cjelinu.
- **Baza je `main`.** Nema PR-a protiv druge feature grane osim ako se izričito dogovorimo.
- **Opis prati `.github/pull_request_template.md`** — cilj, promjene, **dokaz sa stvarnim izlazima**,
  šta nije provjereno, i koji su dokumenti ažurirani.
- **Draft dok ne prođe lokalna provjera.** PR koji ne prolazi `analyze`/`test` nije spreman za tuđe
  vrijeme.
- **Zeleni CI je uslov, ne preporuka.** Crveni job je dio taska. `Supabase tests` mora biti zelen za
  svaku promjenu u `supabase/` — napisana politika nije dokazana politika.
- **Promjena koja mijenja opisano ponašanje a ne dira dokumentaciju je nekompletna.** Tabela
  sinhronizacije je u `CLAUDE.md`.
- **PR koji dira `supabase/` prolazi `rls-auditor`**, Dart promjene `dart-reviewer`, ekrani
  `flutter-ui-reviewer` — prije nego što traži tuđe oko.
- **Veličina:** ako diff prelazi nekoliko stotina linija ručno pisanog koda, razmisli o podjeli.
  Generisani fajlovi se ne broje — oni se ne čitaju kao kod (recenzentu reci iz kojeg ulaza su nastali).
- **Merge radiš ti**, osim ako izričito ne kažeš drugačije. Squash ili merge commit — kako želiš;
  bitno je da naslov ostane u konvenciji.

## 7. Pregled AI-generisanog koda

Kod koji sam napisao pregledaj periodično, a obavezno kad dira:

- **Autorizaciju i tenant izolaciju** — jedino mjesto gdje greška curi tuđe podatke
  (`.claude/docs/security.md`)
- **Availability i booking pravila** — jedini dio koji mora biti tačan, ostalo je CRUD
- **Generatore u `tool/`** — greška tamo se množi kroz sve tenante
- **Migracije** — deployana migracija se ne mijenja, pa je cijena greške najveća

Ono na šta vrijedi gledati: rubni slučajevi (prazan dan, salon bez usluga, mreža pada), tvrdnje u
komentarima koje više nisu tačne, i test koji prolazi i kad se ponašanje ukloni.
