# Admin je 1:1 sa `adminv2` — Barlow, svijetla tema, crtež jači od izostavljanja

## Status

prihvaćen — za `apps/admin` zamjenjuje [ADR-0019](0019-barlow-se-ne-uvodi-postojeca-pisma-ostaju.md).
Klijentska aplikacija ostaje na ADR-0019.

## Kontekst

Novi podatak: vlasnik proizvoda je, gledajući živi admin uz `prototype/adminv2/export/`, tražio
da admin bude **1:1 sa izvozom**. Razlika nije bila u mjerama nego u tri stvari:

- **Pismo.** Izvoz je od naslova do vremena u tabeli crtan u Barlowu. ADR-0019 ga je odbio zbog
  mono sloja (JetBrains Mono za `13:00`, `82%`) i cijene ponovnog QA prolaza.
- **Tema.** Admin je imao `ThemeMode.system`, pa je vlasnik sa dark modom OS-a vidio tamnu radnu
  površinu koju izvoz ne crta nigdje.
- **Izostavljeni elementi.** Dashboard je izostavio „Slobodno vrijeme", procenat zauzetosti,
  „Otvoreno do", pretragu klijenta i „prije N min", uz obrazloženja da čekaju taskove 33–35 i da
  `appointments.created_at` ne postoji. Taskovi su u međuvremenu zatvoreni, a kolona postoji od
  init migracije.

## Odluka

1. **Admin prelazi na Barlow** (400/500/600/700, statični rezovi, zapakovani uz OFL). Mono se ne
   zamjenjuje drugim pismom: posao poravnanja cifara radi `FontFeature.tabularFigures()` nad
   Barlowom (`barlowTabular` u `admin_typography.dart`).
2. **Admin je svijetle teme** (`ThemeMode.light`). Tamna tema ostaje izgrađena i vraća se jednim
   redom kad handoff dobije tamnu varijantu.
3. **Crtež iz `adminv2` je jači od izostavljanja.** Element se crta kad podatak postoji. Kad ne
   postoji, crta se kao placeholder koji ne laže (ugašen ili „Uskoro"), a ne izostavlja se.
   Izuzetak je prelaz na mrežu lokacija (`▾`, „‹ Nazad na mrežu"): `3a` nema ni rutu ni podatak.
4. **Primarno dugme je verzal** (`AdminVerzal` + `AdminText.actionLabel`), sekundarno ostaje u
   rečenici.
5. **Prelaz između ekrana je pretapanje od ~150 ms**, ne Material „dizanje" ekrana.

## Razmatrane opcije

- **Ostati na ADR-0019 i uzimati samo skalu** — odbačeno: vlasnik je izričito tražio 1:1, a
  pismo je najvidljivija razlika na svakom ekranu.
- **Barlow bez tabularnih cifara** — odbačeno: vrijeme u koloni tabele bi se pomjeralo po cifri.
- **Pratiti sistemsku temu** — odbačeno dok izvoz nema tamnu varijantu.

## Posljedice

- Admin testovi koji tvrde staro pismo, stare tekstove i tri kartice na dashboardu padaju dok se
  ne prepišu; ekrani iz ove promjene su pregledani ručno, a ne testovima.
- `prototype/admin/SPEC.md` (tabela „Šta canvas crta, a aplikacija namjerno nema") i
  `.claude/docs/conventions.md` treba uskladiti sa ovim ADR-om.
- Klijentska aplikacija se ne mijenja: ADR-0018 i ADR-0019 za nju i dalje važe.
