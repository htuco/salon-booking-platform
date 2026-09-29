# Vertikala `health` dobija dvije svijetle teme — Newsreader + Public Sans, izbor brandom

## Status

prihvaćen. Dopunjuje [ADR-0025](0025-pismo-i-uloge-izbora-vezu-se-za-temu.md) za vertikalu
`health` i usvaja `prototype/masaza/` (sa `fizio/`) kao vizuelni izvor istine za **paletu,
pismo i rječnik** tih tema. Za oblik ekrana i dalje važi `prototype/ui/`.

## Kontekst

Handoff `prototype/masaza/` (2026-09-29) crta dva tenanta vertikale `health`: studio masaže i
fizioterapeutski centar. Isti shell kao `prototype/ui/`, a razlike su:

1. **Pisma Newsreader** (naslovi, 400) **+ Public Sans** (UI, 400/500/600) za oba tenanta.
2. **Neutrale se razlikuju**: masaža je topla (bjelokost `#F4EDE3`, kadulja), fizio hladna
   (`#F4F7F5`, petrolej). `fizio/SPEC.md` ih zove „tokeni tenanta", ali po ADR-0018 tenant bira
   samo brand boju — podloga, linije i tekst su tema.
3. **Izbor ide brandom** (slot, dan, progres, tab traka, rub izabranog reda), a `onPrimary` i
   `primaryPressed` se izvode iz jedne boje — isti model kao `elegant_beauty`.
4. **Light i dark** varijanta za oba.
5. **Galerija** postoji kod masaže, a kod fizija je isključena. `docs/05` §5 za `health` kaže ❌.
6. **Oblik ekrana se mijenja** na nekoliko mjesta: hero 3:4 sa naslovom ispod i bez gradijenta,
   „Naš tim" i sedmično radno vrijeme na Početnoj, 5g bez fotografije, otkazivanje sa
   onemogućenim dugmetom i objašnjenjem, više dužina po tretmanu, kartica terapeuta sa
   specijalizacijom, checkbox pristanka u koraku 4.

Činjenice u repou:

- `AppTheme` ima jednu svjetlinu po temi, a klijent ne prati sistemski dark mode.
- `clinical_calm` postoji (hladna svijetla, DM Serif + Archivo), ali ga ne koristi nijedan tenant
  ni seed red — samo testovi. Bio je rezervisan za `dental`/`health`, a `dental` je van sprinta.
- Feature flagovi su po vertikali (`vertical_packs.feature_flags`). Override po salonu postoji
  samo za terminologiju (`salons.terminology_override`), ne za flagove.
- `VerticalTerms` nosi samo nominativ. Handoff traži `note.hint`, akuzativ usluge i naziv
  mjesta u padežu („potvrdu **centra**").

## Odluka

**Dvije svijetle teme istog oblika, jedan par pisama i izbor brandom.**

| Tema | Tenant iz handoffa | Neutrale | Pisma | Izbor |
|---|---|---|---|---|
| `warm_wellness` (nova) | masaža | `prototype/masaza/SPEC.md` §Tokeni, light | Newsreader + Public Sans | brand, izvedeno |
| `clinical_calm` (prepisana) | fizio | `prototype/masaza/fizio/SPEC.md` §Tokeni, light | Newsreader + Public Sans | brand, izvedeno |

- `clinical_calm` **se prepisuje** fizio neutralama i pismima. Nijedan tenant ga ne koristi, pa
  se nema šta pokvariti. Kad `dental` stigne, dobija svoju odluku o temi. Veći dentalni body font
  (`TODO(dental-tipografija)`) se ovdje ne uvodi.
- Newsreader i Public Sans se pakuju uz aplikaciju (OFL, varijabilni `wght`), kao Jost. Skala se
  ne mijenja — iste veličine i proredi kao ostale teme.
- `primary`, `onPrimary`, `primaryPressed` i uloge izbora se izvode iz brand boje salona istim
  algoritmom (`BrandRoles.derive`, ADR-0025). Kadulja `#56664F` i petrolej `#2F6F6D` idu u
  `tenant.yaml` demo tenanata, ne u temu.
- **Samo light.** Dark tokeni iz handoffa ostaju kandidat za zaseban task, koji bi uveo praćenje
  sistema za sve teme odjednom.
- **Oblik ekrana ostaje bazni** (`prototype/ui/`). Razlike iz tačke 6 konteksta nisu dio ove
  odluke — svaka je kandidat za zaseban task, a one sa podacima (dužine, specijalizacija,
  pristanak) traže migraciju.
- **Galerija ostaje ❌ za `health`**, po `docs/05` §5. Masaža je dobija kad postoji override
  flagova po salonu — zaseban task sa migracijom.

Rječnik:

- Pack `health` prati `docs/05` §3 i fizio handoff: Pacijent, Terapija/Terapije, Terapeut,
  „Zakaži termin", „Razlog dolaska".
- Salon za masažu to mijenja kroz `terminology_override`: Klijent, Tretman/Tretmani,
  „Rezerviši tretman", „Napomena za terapeuta".
- `VerticalTerms` dobija `serviceAccusative` („uslugu" · „tretman" · „terapiju") za naslov
  prvog koraka. Pack bez ključa pada na „uslugu", pa barber ostaje 1:1 sa handoffom.
- `noteHint` i naziv mjesta u padežu („potvrdu **centra**") se **ne** uvode sada: bazni shell
  nema polje za napomenu u koraku 4, a „salon" u porukama je zajednički copy svih vertikala.
  Oba idu uz task koji doda polje napomene, odnosno prođe kroz copy po vertikali.
- Zamjenica po rodu usluge (`service.pronoun`) **ne** postaje ključ: rod zavisi od naziva usluge
  iz baze, pa se rečenica na `5d` slaže bez zamjenice.

## Razmatrane opcije

- **Jedna `health` tema za oba tenanta** — odbačeno: podloga, linije i tekst su tema (ADR-0018),
  a fizio i masaža ih imaju različite. Jedna tema bi značila neutrale po salonu.
- **Dvije nove teme, `clinical_calm` ostaje dentalu** — odbačeno: `clinical_calm` nema korisnika
  ni dizajna, a čuvanje prazne teme za vertikalu van sprinta je treća grana u svakom `switch`-u
  bez razloga.
- **Neutrale iz `tenant.yaml`** — odbačeno: drugi fizio salon bi dobio podlogu bez QA-a kontrasta;
  ADR-0018 drži samo brand boju u tenantu.
- **Dark varijanta u ovom tasku** — odgođeno, ne odbačeno: traži `ThemeMode.system` i par tema
  za barber i beauty, koji nemaju dark (odnosno light) handoff. Vraća se kao zaseban task.
- **Override feature flagova po salonu odmah** — odgođeno: nova kolona, RLS, pgTAP i domen u
  tasku koji je već najveći u sprintu.
- **Oblik po temi (hero ispod, bez gradijenta)** — odgođeno: grana po temi u Početnoj, a task
  obećava isti shell. Vraća se ako se pokaže da hero sa gradijentom na svijetloj temi ne čita.

## Posljedice

- Health ekrani se **ne poklapaju sa handoffom** u obliku (Početna, 5g, otkazivanje, dužine,
  kartica terapeuta) ni u darku — namjerno, ne propust. Snimke porediti sa handoffom po paleti,
  pismu i rječniku.
- Masaža nema galeriju iako je handoff crta.
- Svaki flavor nosi pet pisama (DM Serif, Archivo, Jost, Newsreader, Public Sans). Font asset
  se ne pakuje po flavoru bez generatora.
- Newsreader ima drugu visinu reda od DM Serif — ekrani na 402 moraju se pogledati na obje nove
  teme.
