# Salon Booking Platform

Personalizovane **native** booking aplikacije za frizere, beauty salone, stomatološke ordinacije i ostale uslužne djelatnosti.

**Model:** jedan Flutter codebase + jedan multi-tenant backend → N brandiranih aplikacija u storeovima. Novi klijent = novi flavor i config, ne novi projekat.

**Stack:** Flutter (client + admin, Android + iOS) · Supabase (Postgres, RLS, Auth, Storage, pg_cron) · Firebase FCM (samo push) · Next.js (super admin konzola + politika privatnosti po tenantu)

---

## 📖 Dokumentacija

**Počni sa [docs/README.md](docs/README.md)** — index sa redoslijedom čitanja.

| # | Dokument |
|---|---|
| 01 | [MVP Specifikacija](docs/01-mvp-spec.md) — proizvod, DB shema, pricing, build order |
| 02 | [User Flows & Wireframes](docs/02-user-flows-wireframes.md) — svi ekrani, push flow, UX copy, design system |
| 03 | [Market Research](docs/03-market-research-cutlio.md) — Cutlio, Rezervo, Rezervacija, Barberly |
| 04 | [Flutter Tenant Factory](docs/04-flutter-tenant-factory.md) — flavors, CI/CD, store submission |
| 05 | [Vertikalni paketi](docs/05-vertical-packs.md) — frizeri, beauty, zubari, health, generic |
| 06 | [Auth & Login Flow](docs/06-auth-login-flow.md) — Apple, Google, Email OTP, Facebook · Supabase Auth |
| 07 | [Tehnička arhitektura](docs/07-tech-architecture.md) — struktura foldera, izbor paketa (Flutter/Next.js/Supabase), monorepo alati |

---

## ✅ Taskovi

**[tasks/](tasks/)** — raspisani taskovi za Sprint 0, jedan `.md` po tasku sa ciljem, definicijom gotovog i koracima. Počni sa [tasks/README.md](tasks/README.md).

---

## 🤖 Rad sa Claude Code

Repo je opremljen tako da nova sesija (tvoja ili kolegina) može krenuti bez usmenog uvoda.

| Putanja | Šta je |
|---|---|
| [CLAUDE.md](CLAUDE.md) | router — kaže koji dokument treba za koji tip promjene |
| [CONTEXT.md](CONTEXT.md) | domenski rječnik — koja riječ za koji pojam |
| [.claude/docs/](.claude/docs/) | arhitektura, konvencije, sigurnost, komande, tenant factory |
| [.claude/skills/](.claude/skills/) | `/task` `/verify` `/handoff` `/new-tenant` `/cleanup` `/research` |
| [.claude/agents/](.claude/agents/) | recenzenti: RLS, Dart, duplikacija, UI |
| [docs/adr/](docs/adr/) | zašto je nešto odlučeno i šta je odbačeno |
| [docs/TEAM_HANDBOOK.md](docs/TEAM_HANDBOOK.md) | uloge u proizvodu + kako se doprinosi repou |

Uobičajen tok: `/task load <NN>` → `/task start` → `/task review` → `/task verify` →
`/task complete`, pa `/handoff write` ako posao ostaje otvoren za nekog drugog.

Dva pravila koja drže sve ovo živim: **dokument se ažurira u istoj promjeni koja mijenja ono što
opisuje**, i **dokaz je artefakt ili zeleni CI job, nikad "kod izgleda ispravno"**.

---

## 🏗 Flutter monorepo (Sprint 0)

Pub workspace (Dart SDK ^3.13.1) sa Melos-om — [task 01](tasks/01-repo-skeleton.md) je odradio skeleton, ostali taskovi u [tasks/](tasks/) ga popunjavaju.

```bash
dart pub global activate melos   # jednom
melos bootstrap                  # flutter pub get za sve pakete u workspace-u
melos run analyze                # dart analyze u svih 5 paketa
melos run test                   # flutter test u svih 5 paketa

npm i && npx lefthook install    # git hooks (dart format na pre-commit)

supabase init                    # već urađeno — v. supabase/config.toml
```

> `apps/client`, `apps/admin` i `packages/core_*` su trenutno prazni skeletoni (Flutter default), bez state managementa/routinga — to dolazi tek u Sprint 1 kad se piše prvi ekran ([07 §3](docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor)).

---

## 🖥 Interaktivni wireframe prototip

```bash
npm i
npm run dev
```

Otvori `/` za pregled svih ekrana grupisanih po tri dijela sistema.

> **Ovo je React/web prototip za validaciju flowa i vizuala, ne production kod.**
> Produkt je Flutter. Mapiranje ekrana → Flutter screen: [docs/02 §2](docs/02-user-flows-wireframes.md).

### Ekrani u prototipu

**Client app** (brandiran po salonu)
`/s/barber-studio-vitez` · `/s/beauty-studio-travnik` · `/s/:slug/book/service` · `/book/employee` · `/book/datetime` · **`/s/:slug/auth/login`** · `/book/details` · `/book/success` · `/s/:slug/appointments` · **`/s/:slug/account`**

> Login ekran ima demo prekidač iOS/Android i podekrane preko query parametra:
> `?screen=email` · `?screen=otp` · `?platform=android`

**Admin app** (jedna za sve salone)
`/admin/login` · `/admin/dashboard` · `/admin/appointments` · `/admin/calendar` · `/admin/services` · `/admin/employees`

**Super admin** (Flutter Web)
`/super-admin/salons/new`

---

## 📂 Struktura

```
.
├── CLAUDE.md                # router za Claude Code
├── CONTEXT.md               # domenski rječnik
├── .claude/                 # docs/, skills/, agents/ — v. "Rad sa Claude Code"
├── docs/                    # ⬅ dokumentacija — počni ovdje (+ adr/, agents/, source/)
├── design/                  # ⬅ dizajnerski handoff — vizuelni izvor istine (17 ekrana)
├── tasks/                   # raspisani taskovi za Sprint 0
├── pubspec.yaml             # root — Dart pub workspace + Melos config (melos: key)
├── apps/
│   ├── client/              # Flutter — N flavora (skeleton, task 01)
│   └── admin/               # Flutter — generička app (skeleton, task 01)
├── packages/
│   ├── core_domain/         # entiteti, Vertical (skeleton, task 01)
│   ├── core_api/            # Supabase repozitoriji (skeleton, task 01)
│   └── core_ui/             # design system (skeleton, task 01)
├── supabase/                # migrations/, functions/, seed.sql, tests/ (init, task 01)
├── tenants/                 # build config po klijentu — v. docs/04 §3
├── tool/                    # new_tenant.dart, gen_flavors.dart — v. tasks/03
└── prototype/               # React wireframe + svoj toolchain — ZAMRZNUT
    └── src/app/routes.tsx   # rute prate docs/01 §12
```

Puna struktura sa obrazloženjem svakog foldera: [docs/07-tech-architecture.md §1](docs/07-tech-architecture.md#1-puna-struktura-repozitorija).

Originalni `.docx` draftovi su u `docs/source/`, zadržani za referencu. Konvertovani su u markdown
i značajno dorađeni u `docs/`.

`design/` je vizuelni izvor istine za ekrane; `prototype/` je stariji React wireframe koji je time
zamrznut i ostaje samo kao referenca za flow. Root `package.json` drži samo `lefthook`.

---

Autor: Hamza Tuco · v4 native (Flutter) + auth · Supabase · 20.08.2026.
Originalni Figma dizajn: https://www.figma.com/design/TLSFbOGogCsWH4sfNBSBnG/Salon-Booking-App-Design
