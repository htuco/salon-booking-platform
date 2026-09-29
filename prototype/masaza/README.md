# `prototype/masaza/` — handoff teme za masažu (vertikala `health`)

Dizajnerski handoff za klijentsku aplikaciju masažnog studija („Studio Masaže Mostar", radni
naziv): 18 ekrana, iPhone 402×874, **svijetla i tamna** tema, bosanski. Nacrtan je kao varijanta
baznog handoffa `prototype/ui/`: isti shell, a druga boja, fotografija, rječnik i pisma. Ulaz je
za [task 53](../../tasks/sprint-5/53-vertikala-health.md), dio koji se odnosi na masažu.
Fizioterapija je u `fizio/` kao drugi tenant iste vertikale (v. niže).

**Status: kandidat.** Handoff nije vizuelni izvor istine, dok ga ADR iz taska 53 ne usvoji.
Do tada za klijentsku aplikaciju važi `prototype/ui/`, a ovdje se samo gleda.

## Šta je gdje

| Putanja | Šta je |
|---|---|
| `SPEC.md` | **Puna specifikacija** iz handoffa: ekrani `5a`–`5r`, komponente, stanja, tokeni za light i dark, rječnik, tabela odstupanja od baze. Prvo što se čita. |
| `screens-flat.html`, `screens-flat-dark.html` | Svi ekrani kao statični HTML pune dužine, bez JS-a. |
| `screenshots/light/`, `screenshots/dark/` | PNG na 2×, `01…18-*.png`, u redoslijedu flowa. |
| `canvas/` | `.dc.html` canvas sa svim ekranima i neizabranom paletom „glina", plus `support.js`. **Ne portuje se.** |
| `fizio/` | Fizioterapija („Fizio Centar Zenica"): 15 ekrana, light + dark, isti raspored foldera. Njen `SPEC.md` navodi **samo razlike** u odnosu na masažu. |

Ekrani nose iste identifikatore kao `prototype/ui/` (`5a`–`5q`), pa se mogu diffati jedan pored
drugog. `5r` (sheet „Prijavi sliku") je nov: ovdje je prvi put nacrtan sheet koji task 51 pravi u
klijentu ([PR #116](https://github.com/htuco/salon-booking-platform/pull/116)).

Canvas se otvara bez servera, jer mu treba samo `support.js` pored njega. Pisma Newsreader i Public
Sans stižu sa Google Fontsa, pa bez mreže ekran pada na sistemsko pismo.

## Šta se uzima kad bude usvojen

Isto pravilo kao za `ui/` i `beauty/`: **oblik da, boja i tekst ne u ekran.**

- Tokeni iz `SPEC.md` §Tokeni su paleta **teme**, ne salona. Tenant bira samo `primaryFill`, a
  `onPrimary`, `primaryPressed` i dark vrijednost se izvode, kao brand uloge u `beauty/`.
  Izvođenje ide u `core_ui`, ne u ekran.
- Rječnik (`Tretman`, `Terapeut`, `Rezerviši tretman`, „Napomena za terapeuta" sa hintom) ide u
  `vertical.terms`. Tačkasto podvlačenje u prototipu samo označava šta dolazi iz rječnika i nije stil.
- Oblik komponenti se poklapa sa `core_ui`. Nove su tri: segment dužine unutar service rowa,
  kartica terapeuta sa specijalizacijom i dan u kalendaru kad terapeut ne radi (precrtan).

## Gdje se sudara sa repoom

Provjereno 2026-09-29 na `main`-u. Ovo je spisak posla, ne greške u handoffu.

| Handoff traži | Stanje u repou | Kome pripada |
|---|---|---|
| Pisma **Newsreader + Public Sans** | [ADR-0019](../../docs/adr/0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md): klijent ima jedan par, DM Serif Display + Archivo | ADR iz taska 53 (pismo po temi). Pisma se pakuju uz aplikaciju, ne sa Google Fontsa |
| Svijetla topla tema kao osnovna, dark kao varijanta | U `tenant.yaml` postoje teme `modern_barber` i `elegant_beauty` | Task 53: nova tema. ADR odlučuje dijeli li je fizio |
| **Više dužina po tretmanu** (60 / 90 min, cijena po dužini) | `services` ima jedan `duration_minutes` i jednu cijenu | Van taska 53. Traži migraciju i promjenu availability enginea, pa ide kao zaseban task |
| Terapeut sa specijalizacijom i godinama iskustva | Na radniku nema tih kolona | Zaseban task: migracija i admin forma |
| Izbor terapeuta obavezan, bez „Bilo ko od nas" | `require_staff_choice` postoji po salonu | Task 53, seed za `health` |
| Otkazivanje do 12h, dugme onemogućeno uz objašnjenje | `min_cancel_hours` postoji, a `5h` već crta onemogućeno dugme i rok | Fali samo link „Pozovi studio" (task 58, kontakt jednim tapom) |
| Checkbox pristanka u koraku 4 | `vertical_packs.required_consents` postoji, booking flow ga ne crta | Ekran plus logiranje `consentVersion` i `consentAt` (`docs/05` §7) |
| Galerija ambijenta | `docs/05` §5: galerija je za `health` ❌ | ADR iz taska 53 ili izmjena `docs/05`: flag za `health` na ⚠️ |
| „Klijent", ne „Pacijent" | `docs/05` §3: `health` kaže „Pacijent" | Task 53: `terminologyOverride` za masažu |
| Prijava Apple, Google ili email, bez telefona | Već tako radi (task 41, `docs/06`) | — |

## `fizio/` — isti oblik, druge neutralne boje

Fizio je provjera da jedan handoff pokriva obje vrste `health` tenanta. Oblik, pisma, komponente i
ponašanje su isti kao kod masaže. Razlike su četiri:

1. **Neutralne boje su hladne** (`#F4F7F5` podloga, petrolej `#2F6F6D` umjesto kadulje). Handoff ih
   zove „tokeni tenanta", ali po modelu platforme tenant bira samo `primaryFill`. Podloga, linije i
   tekst su tema. Fizio je zato **druga tema istog oblika**, ne samo druga boja salona. To odlučuje
   ADR iz taska 53.
2. **Galerija je isključena**: nema `5l`, `5q` ni `5r`, niti reda „Galerija" na Početnoj.
   Screenshotovi 12, 17 i 18 zato ne postoje.
3. **Rječnik**: Terapija, Pacijent, „Zakaži termin", „Razlog dolaska", „centar" umjesto „studio".
4. **Sadržaj tenanta** (katalog, tim, recenzije) je podatak, ne dizajn.

Kontrast iz `fizio/SPEC.md` je preračunat i slaže se: svi parovi teksta su ≥ 4,5:1, a
`borderStrong` je 3,3:1 (granica za UI).

### Rječnik traži ključeve kojih `VerticalTerms` danas nema

`packages/core_domain/lib/src/vertical/vertical_terms.dart` ima samo nominativ. Handoff uvodi:

- `note.hint`: hint uz napomenu. Obično polje, bez zamke.
- `service.acc` i `venue` u padežu („terapiju", „potvrdu **centra**"): padeži po vertikali, novo
  polje uz `serviceSingular` i `businessSingular`.
- **`service.pronoun` („rade **je**") ne može biti ključ vertikale.** Zamjenica zavisi od roda
  *naziva usluge*, koji dolazi iz baze: „Manuelna terapija" traži *je*, a masažni „Vruće kamenje"
  *ga* i „Duboka tkiva" *ih*. Rečenicu na `5d` treba složiti bez zamjenice, npr. „Manuelna
  terapija · 45 min — terapeuti za ovaj termin:".
