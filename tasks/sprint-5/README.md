# Sprint 5 — slike, vertikale, čist admin i rupe iz MVP-a

Sprint 4 je zatvorio pristup zaposlenih. Admin danas pokriva svakodnevni rad salona, ali salon i
dalje ne može postaviti nijednu svoju sliku, beauty izgleda prazno, a dva obećanja iz MVP-a
(`docs/01` §6.2 — podsjetnici D-1/H-3 i povratak zaboravljene lozinke) nigdje ne postoje.

**Redoslijed je namjeran.** Slike idu prve jer ih traže i beauty (52) i health tenanti (53) — tenant bez
fotografija ne može se ni procijeniti, a kamoli dotjerati. Rupe iz MVP-a (56–58) ne zavise ni od
čega i mogu ići paralelno. Regresija (60) je zadnja: prolazi kroz sve što je sprint dirao i hvata
bugove usput, umjesto da se oni nagađaju unaprijed.

| # | Task | Vrsta | Blokira | Procjena |
|---|---|---|---|---|
| [48](48-storage-bucket-po-salonu.md) | Storage bucket po salonu ✅ | feature | 49, 50, 51 | 1–2 dana |
| [49](49-slike-usluga-i-radnika.md) | Vlasnik postavlja sliku usluge i radnika ✅ | feature | 52, 53 | 1–2 dana |
| [50](50-galerija-logo-cover.md) | Galerija salona, logo i cover | feature | 52, 53 | 2 dana |
| [51](51-ciscenje-bucketa-i-prijava-sadrzaja.md) | Čišćenje bucketa i prijava neprikladnog sadržaja | feature | — | 1–2 dana |
| [52](52-beauty-dotjeran.md) | Beauty tenant dotjeran | refinement | — | 1–2 dana |
| [53](53-vertikala-health.md) | Vertikala `health` — masaža i fizioterapija, vlastita tipografija i boje | feature | — | 4–5 dana |
| [54](54-uklanjanje-nepotrebnog-iz-admina.md) | Uklanjanje nepotrebnog iz admina | popravka | 55 | 0,5–1 dan |
| [55](55-prerada-dashboarda.md) | Prerada admin dashboarda | redizajn | — | 2–3 dana |
| [56](56-podsjetnici-d1-h3.md) | Push podsjetnici D-1 i H-3 | feature | — | 2 dana |
| [57](57-reset-lozinke.md) | Povratak zaboravljene lozinke | feature | — | 1–2 dana |
| [58](58-kontakt-jednim-tapom.md) | Kontakt klijenta jednim tapom | feature | — | 0,5–1 dan |
| [59](59-radnik-u-seedu.md) | Radnik u lokalnom seedu | chore | 60 | 0,5 dan |
| [60](60-regresija-i-testiranje.md) | Regresija i testiranje | test | — | 2–3 dana |

Ukupno 18–26 dana — više od jednog sprinta, kao i Sprint 4. **Obavezni su 48–50, 56 i 57**:
bez njih ni salon ni klijent nemaju ono što MVP obećava. 52–55 i 58 idu redom kako stignu; 59 i 60
zatvaraju sprint bez obzira na to koliko je ostalih stiglo.

## Šta ovaj sprint **ne** zatvara

**Zubari (`dental`).** Namjerno van sprinta. `docs/05` ih stavlja iza 3+ zadovoljna beauty klijenta,
uz DPA i politiku privatnosti, jer nose pravni teret koji nedokazan sistem ne treba. Traže i veći
body font (`TODO(dental-tipografija)` u `app_theme.dart`) i `date_only` zakazivanje.

**Pomjeranje termina.** Dugme „Pomjeri" nema RPC iza sebe. Nije MVP (`docs/01` §6.3), a
drag-and-drop je Faza 2 — kandidat za Sprint 6. Task 54 odlučuje da li dugme do tada ostaje.

**Super admin konzola** (`docs/01` §6.1, Next.js). MVP kriterij §13.1 je traži, a u `apps/` je nema.
Da li je još MVP ili se odgađa je odluka za ADR, ne za ovaj sprint.

**iOS push.** I dalje čeka Apple developer nalog.

## Odluke donesene prije koda

| Odluka | ADR |
|---|---|
| Slike idu u Supabase Storage, javni bucket sa upisom po salonu | [ADR-0015](../../docs/adr/0015-slike-idu-u-supabase-storage-javni-bucket.md) |
| Admin je 1:1 sa `adminv2` — **tasks 54 i 55 ga mijenjaju i počinju dopunom ADR-a** | [ADR-0020](../../docs/adr/0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md) |
| Iz handoffa se uzima oblik, ne boja — vertikala se razlikuje podatkom, ne kodom | [ADR-0018](../../docs/adr/0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md) |
| Klijent ima jedan par pisama — **task 53 ga veže za temu i počinje novim ADR-om** | [ADR-0019](../../docs/adr/0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md) |

## Status

Sprint raspisan 2026-09-25.

### 48 — Storage bucket po salonu (🟡, 2026-09-26)

Bucket `salon-media` i politike po salonu gotovi i dokazani lokalno (624 pgTAP, `rest_storage` 19).
Čeka `Supabase tests` na PR-u (CI kvota do 29.09.) i `supabase db push` poslije merge-a. 49 i 50
mogu krenuti na stacked grani.

### 48 — zatvoren (2026-09-26)

Mergan kao #110, migracija je na hostovanom projektu (`supabase migration list` pokazuje
`20260926100000` i lokalno i remote).

### 49 — Slike usluga i radnika (✅, 2026-09-26)

PR #112 i #113. Upload iz admina → slika u klijentu, viđeno uživo **na oba tenanta** (Vitez i
beauty), za uslugu i za radnika. Dijalog osoblja sada piše termin vertikale („Uredi stilisticu“).
Admin testovi daju 459 PASS. Izbor iz galerije na Android/iOS uređaju prebačen je u 60.
