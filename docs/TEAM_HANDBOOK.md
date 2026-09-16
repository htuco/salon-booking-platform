# Team Handbook — Salon Booking Platform

Kratki priručnik za rad na ovom projektu: ko šta smije u proizvodu, kako se doprinosi repou, i kako
se posao predaje između ljudi koji rade kroz Claude Code na različitim mašinama.

Držati u sinhronizaciji sa kodom — v. tabelu u root `CLAUDE.md`.

---

## 1. Uloge u proizvodu

Ovo je plain-language sažetak; tehnička pravila pristupa su u `.claude/docs/security.md`, a puni
opis uloga u `docs/01 §5`.

**Super admin — vlasnik platforme**
- Kreira i uređuje salone, podešava logo, ikonu, boje i temu, dodaje vlasnika salona
- Aktivira i deaktivira salon; deaktivacija odmah gasi klijentski pristup tom salonu
- Pokreće build i store submission za novog klijenta
- Jedini je iznad tenant izolacije — vidi sve salone
- Radi kroz Next.js web konzolu (još nije napravljena)

**Salon admin — vlasnik salona**
- Vidi današnje termine, kalendar, i potvrđuje / odbija / otkazuje termine
- Ručno dodaje termine, uređuje usluge (cijena, trajanje), radnike, radno vrijeme, blokade
- Vidi podatke svojih klijenata — i **samo** svojih; ne postoji pogled preko granice salona
- Radi kroz **jednu generičku admin aplikaciju** za sve salone

**Radnik**
- U Fazi 1 **nema login**. Postoji kao resurs: ima usluge, raspored i termine, ali nije korisnik
- Faza 2: dobija login u istu admin app i vidi samo svoje termine

**Klijent salona**
- Pregled salona, usluga, cijena, tima i slobodnih termina **nikad ne traži prijavu**
- Prijava se traži tek na **kraju** booking flowa: Apple (iOS), Google, Email + lozinka, Facebook
  (Facebook je iza flaga i default isključen)
- **Broj telefona se ne traži.** Push zamjenjuje i poziv i SMS
- Vidi i otkazuje svoje termine, do `minCancelHours` prije termina; poslije toga samo salon
- Ista osoba u tri salona ima jedan identitet, ali tri odvojena zapisa — salon ne vidi da klijent
  ide i kod konkurencije

---

## 2. Kako se doprinosi

**Prije nego što išta napišeš**
1. `CLAUDE.md` u rootu — router; kaže koji dokument treba za tvoj tip promjene
2. Task u `tasks/` na kojem radiš, uključujući njegov status blok
3. Dokument koji task spominje — obavezno `.claude/docs/security.md` ako diraš `supabase/`

**Grane**
- **Svaki rad ima svoju granu i otvoren PR protiv `main`. Na `main` se ne commituje direktno** —
  hook u `.claude/settings.json` traži potvrdu za svaki `commit`/`push`/`merge` koji cilja `main`
- PR se otvara **čim postoji prvi commit** (draft), ne tek kad je sve gotovo
- Imena: `feat/<kratko>`, `fix/<kratko>`, `chore/<kratko>`
- Ne otvaraj task čije zavisnosti nisu gotove — redoslijed u `tasks/sprint-<N>/README.md` nije formalnost

**Commit poruke i PR-ovi**
- Conventional Commits sa scopeom (`feat(client):`), naslov na bosanskom u imperativu, tijelo nosi
  **zašto** i **čime je dokazano**. Postojeći `git log` je uzor
- PR opis prati `.github/pull_request_template.md`: cilj, dokaz sa stvarnim izlazima, i **šta nije
  provjereno i zašto**
- Crveni CI job je dio taska, ne tuđi problem
- Promjena koja mijenja opisano ponašanje a ne dira dokumentaciju je nekompletna promjena
- **Bez potpisa AI-ja** — nema `Co-Authored-By: Claude` ni "Generated with" ni u commitu ni u PR-u
- Puna konvencija (kad se pita, kad se ne mergea, veličina PR-a): `.claude/docs/ai-interaction.md`

**Šta se nikad ne commituje**
- Tajne: `.env`, izlaz `supabase status -o env`, service role ključ, pravi `google-services.json`,
  iOS potpisni materijal
- Artefakti: `build/`, APK/AAB/IPA
- Ručne izmjene generisanih fajlova (nestaju pri sljedećem generisanju, a CI ih odbija)

---

## 3. Rad sa Claude Code

Repo je opremljen tako da nova sesija — tvoja ili kolegina — može krenuti bez usmenog uvoda.

**Šta gdje stoji**

| Putanja | Šta je |
|---|---|
| `CLAUDE.md` | router; učitava se uvijek, zato je kratak |
| `CONTEXT.md` | domenski rječnik — koja riječ za koji pojam |
| `.claude/docs/` | arhitektura, konvencije, sigurnost, komande, tenant factory, način rada — čitaju se po potrebi |
| `.claude/skills/` | `/task`, `/verify`, `/handoff`, `/new-tenant`, `/cleanup`, `/research` |
| `.claude/agents/` | recenzenti: `rls-auditor`, `dart-reviewer`, `duplication-scanner`, `flutter-ui-reviewer` |
| `.claude/settings.json` | `SessionStart` hook (ubaci aktivni task i git stanje) + odobreni MCP serveri |
| `supabase/`, `apps/client/`, `tool/`, `prototype/` — `CLAUDE.md` | pravila tog foldera; učitavaju se sama kad se radi u njemu |
| `prototype/ui/` | kako ekran treba da izgleda — handoff sa 17 ekrana, tokeni, komponente |
| `docs/adr/` | zašto je nešto odlučeno i šta je odbačeno |
| `tasks/` | šta se radi sada i dokle se stiglo |

**Uobičajen tok**

```
/task load 05      → pročitaj task, zavisnosti i šta je stvarno ostalo
/task start        → grana, pa korak po korak
/task review       → DoD stavku po stavku + odgovarajući subagent
/task verify       → dokaz, ne tvrdnja
/task complete     → status blok, dokumenti, commit, PR
/handoff write     → ako posao ostaje otvoren
```

**Pravila koja vrijede u svakoj sesiji**
- Dokument se ažurira u **istoj** promjeni koja mijenja ono što opisuje
- Dokaz je artefakt ili zeleni CI job, nikad "kod izgleda ispravno"
- Ono što se nije moglo provjeriti se **imenuje**, ne prešuti

---

## 4. Mašine se razlikuju — i to je dio procesa

| Ograničenje | Posljedica |
|---|---|
| CI radi u **dvije brzine** | PR: `Supabase tests` + `analyze` (~7 min). Push u `main`: sve, uključujući APK i iOS (~86 min). Svakodnevno lokalno: `melos run analyze`, `melos run test`, `./tool/test_supabase.sh` |
| iOS traži **macOS + Xcode** | `tool/gen_ios_flavors.sh` i iOS build se ne mogu pokrenuti na Windowsu; dokaz ide na CI job `build-ios` ili na macOS mašinu |
| Instalacija dva APK-a traži **emulator/uređaj** | API 36 x86_64 je verifikovan; bez uređaja ostaje `aapt2 dump badging` kao djelimičan dokaz |

Zato predaja posla nije formalnost nego mehanizam: ono što jedna mašina ne može dokazati, druga
može. `/handoff write` to zapisuje, `/handoff pickup` to preuzima — i prvo što preuzimatelj radi
jeste da provjeri šta **njegova** mašina može, a prethodna nije mogla.

---

## 5. Odluke se ne otvaraju usput

`docs/README.md` ima tabelu odluka koje su donesene i obrazložene. Ne otvaraju se bez **novog
podatka**, a kad se otvore — to je ADR u `docs/adr/`, ne usputna promjena koda. Isto važi za
prihvaćene ADR-ove: ne prepravljaju se, nego se zamjenjuju novim.
