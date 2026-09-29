# Pismo i uloge izbora vežu se za temu — `elegant_beauty` dobija Jost

## Status

prihvaćen. Za klijenta dopunjuje [ADR-0019](0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md):
„jedan par pisama" postaje „jedan par pisama **po temi**".

## Kontekst

Handoff teme `elegant_beauty` (`prototype/beauty/README.md`, 2026-09-27) traži tri stvari koje
barber nema:

1. **Jost za sav tekst** — zamjenjuje i DM Serif Display (naslovi, cijene, vremena) i Archivo (UI).
   Handoff izričito kaže da je `Beauty Tema.dc.html` sa DM Serif + Archivo zastario.
2. **Brand boja nosi izbor** — izabrani slot, izabrani dan, progres, rub izabranog reda, traka u
   tab baru. U barberu (`prototype/ui/SPEC.md`) izbor je **invertovan u boji teksta**, bez brenda.
3. **Modal bez blura** — samo scrim.

ADR-0019 je klijentu dao jedan par pisama. Činjenice u repou:

- Ekrani ne postavljaju pismo sami: `fontFamily`, `serif(` i `archivo(` se van
  `packages/core_ui/lib/src/tokens/typography.dart` ne pojavljuju. Sve ide kroz `TextTheme`, plus
  četiri poziva `kicker()`. Zamjena pisma po temi je dakle lokalizovana u `buildTextTheme`.
- Komponente (`TimeSlotChip`, `CalendarMonth`, `SelectableRow`, `StepProgressBar`,
  `AppBottomNavBar`) izbor crtaju iz `onSurface`/`surface`. Brand boju kao izbor nemaju gdje
  pročitati.
- Sirova `#B76E79` sa bijelim tekstom daje ~3.8:1 i pada AA. Handoff zato daje algoritam koji iz
  jedne boje izvodi `primary`, `primaryPressed`, `brandLine`, `brandContainer` i `brandInk`.
- Task 53 (vertikala `health`) ima isti problem sa pismom i planirao je isti ADR.

## Odluka

**Tema nosi par pisama i uloge izbora, uz svjetlinu i neutralnu paletu.** Salon i dalje daje samo
brand boju (ADR-0018); sve ostalo zna tema.

Pismo:

- `AppTheme.fonts` vraća `AppFonts` (pismo naslova, njegova težina, pismo tijela).
  `modern_barber` i `clinical_calm` ostaju na DM Serif Display + Archivo. `elegant_beauty` dobija
  **Jost** (varijabilan, `wght` osa) za oboje, naslovi na težini 500.
- **Skala se ne mijenja** — iste veličine i proredi za sve teme. Mijenja se pismo, ne oblik.
- Pisma se pakuju uz aplikaciju sa OFL licencom, kao i do sada.
- Ekran i dalje ne postavlja `fontFamily`. Kicker se čita iz teme (`textTheme.kicker()`), ne iz
  konstante.

Uloge izbora:

- `AppSelectionColors` (`ThemeExtension`) nosi `selected`, `onSelected`, `selectedPressed`,
  `selectedContainer`, `accentLine` i `accentInk`. Komponente izbor crtaju iz nje.
- `modern_barber` i `clinical_calm` je pune **tačno današnjim vrijednostima** (`onSurface`,
  `surface`, blagi preliv), pa se barber ne mijenja ni za piksel.
- `elegant_beauty` ih izvodi iz brand boje algoritmom iz handoffa (OKLCH, potamni dok ne pređe
  prag): `primary` ≥ 4.5:1 sa bijelim, `brandLine` ≥ 3:1 na pozadini, `brandInk` ≥ 4.5:1 na
  `brandContainer`. Isti algoritam daje `colorScheme.primary` za primarno dugme te teme.
- Bez `AppSelectionColors` u temi (admin) komponente padaju na `onSurface` — admin se ne mijenja.

Blur:

- **Modal zadržava `blur(1.5px)` u svim temama**, i u beautyju. Iz handoffa se uzima scrim token
  (`rgba(31,26,23,.52)`), ali ne i uklanjanje blura. Blur je dio `AppDialog` oblika koji dijele sve
  teme (`app_dialog.dart` objašnjava zašto); jedna tema bez njega bi značila granu po temi u
  komponenti zarad razlike koja se na svijetloj pozadini jedva vidi.

## Razmatrane opcije

- **Beauty ostaje na DM Serif + Archivo** — odbačeno: handoff je autoritativan za pismo teme i
  izričito proglašava DM Serif verziju zastarjelom; uz to bi 53 morao pisati isti ADR odmah poslije.
- **Pismo po salonu (`tenant.yaml`)** — odbačeno: drugi beauty salon bi mogao dobiti treće pismo
  bez dizajna i bez QA-a. Pismo je odluka teme, isto kao neutralna paleta.
- **Brand boja za izbor u svim temama** — odbačeno: barber je 1:1 sa `prototype/ui/SPEC.md`, koji
  izbor namjerno drži u boji teksta („mreža od trideset brand polja bi progutala CTA").
- **Algoritam izvođenja za sve teme** — odgođeno, ne odbačeno: barberov `primary` je tačna brand
  boja sa izračunatim `onPrimary` i dokazan je tako. Vraća se ako `health` handoff (53) traži isto.
- **Blur po temi (beauty bez blura)** — odbačeno za sada: grana u `AppDialog` zarad jedne teme.
  Vraća se ako dizajner na uređaju pokaže da blur na svijetloj temi smeta.

## Posljedice

- Beauty ekrani se **ne poklapaju sa handoffom u modalu** (imaju blur) — namjerno, ne propust.
- Svaka nova tema mora odlučiti tri stvari: neutrale, pisma i da li izbor ide brandom.
  `AppTheme` to traži kroz `switch`, pa zaboravljena grana ne kompajlira.
- Zamjena pisma mijenja visinu redova na beautyju. Snimci prije i poslije su dio dokaza, a ekrani
  koji su „taman stali" moraju se pogledati na 402 širine.
- Jost dodaje pismo u APK/IPA svakog tenanta, ne samo beautyja — font asset se ne može pakovati po
  flavoru bez generatora. Varijabilni fajl je ~135 KB.
