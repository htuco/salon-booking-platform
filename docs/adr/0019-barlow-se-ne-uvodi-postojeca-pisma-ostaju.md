# Barlow se ne uvodi — postojeća pisma ostaju

## Status

prihvaćen

## Kontekst

Dizajnerski handoff FE epika traži **Barlow** (tijelo, forme, dugmad) i **Barlow Condensed**
(naslovi, sekcijske oznake, navigacija) u obje aplikacije. `tasks/fe-redizajn/README.md` to vodi
kao odluku 1; [FE-102](../../tasks/fe-redizajn/FE-102-tipografija-barlow.md) je čeka i ona blokira
FE-3xx i FE-4xx.

Zatečeno stanje, provjereno u repou:

- `apps/admin`: **Space Grotesk** + **JetBrains Mono**, oba varijabilna, zapakovana lokalno uz
  `OFL-SpaceGrotesk.txt` i `OFL-JetBrainsMono.txt`.
- `apps/client`: **DM Serif Display** + **Archivo** (`Archivo[wdth,wght].ttf`, dvije ose),
  uz `OFL-Archivo.txt` i `OFL-DMSerifDisplay.txt`.
- Oba para su **izričito propisana** u svojim handoffovima: `prototype/admin/SPEC.md:54` i
  `prototype/ui/SPEC.md:110`. Klijentski SPEC uz to nosi punu skalu veličina i `line-height` po
  stilu, i traži isporuku sa aplikacijom, ne sa mreže.
- **Barlow se ne pojavljuje nigdje u kodu** — ni u `pubspec.yaml`, ni u `.dart`, ni u jednom
  `SPEC.md`. Odluka je stvarno otvorena.
- `packages/core_ui/lib/src/tokens/typography.dart` već drži skalu klijenta po **stilovima**
  (`kSerifFamily`, `kBodyFamily`, mapiranje na `display*`/`title*`), dakle zamjena pisma je
  tehnički lokalizovana.

Dvije činjenice odlučuju, i obje su protiv zamjene:

1. **Barlow nema mono rez.** Mono u adminu nije dekoracija: `prototype/admin/SPEC.md:65` ga vezuje
   za inline podatak — `13:00`, `82%`, `26 MIN`, telefon. Zamjena bi morala odlučiti šta nosi taj
   sloj, a nijedna opcija nije bolja od postojeće: tabularne brojke u Barlowu nisu isto što i mono
   za poravnanje vremena u koloni.
2. **Zamjena pisma mijenja visinu svakog reda.** FE-102 to sam navodi kao zamku: ekrani koji su
   „taman stali" počinju prelijevati. Admin blok (FE-401…FE-406) je **završen i dokazan** protiv
   postojećih pisama — šest taskova, preko 300 testova. Zamjena pisma bi taj dokaz poništila i
   tražila ponovni QA prolaz kroz sve admin ekrane.

Treća, sporedna: zamjena bi značila i izmjenu oba `SPEC.md`-a, koji pisma propisuju — dakle
mijenja se **handoff**, ne samo kod.

## Odluka

**Barlow i Barlow Condensed se ne uvode. `apps/admin` ostaje na Space Grotesk + JetBrains Mono,
`apps/client` na DM Serif Display + Archivo.**

Mehanika:

- Iz handoffa se uzima **tipografska skala i hijerarhija** — veličine, težine, `line-height`,
  uppercase kickeri sa letterspacingom — a ne porodica pisma. To je isti princip koji
  [ADR-0018](0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md) primjenjuje na boju:
  uzima se oblik, ne vrijednost.
- Uppercase i letterspacing ostaju **stil**, nikad `toUpperCase()` nad stringom — veliko slovo
  upisano u tekst razbija čitače ekrana i prevod.
- `TextTheme` ostaje definisan po stilovima, ne po ekranima. Nijedan widget ne postavlja
  `fontFamily` sam.
- Varijabilna pisma se i dalje težinom podešavaju kroz `FontVariation`, ne `fontWeight`.

## Razmatrane opcije

- **Barlow u obje aplikacije, kako handoff traži** — odbačeno: nema mono rez za inline podatak
  admina, poništava dokaz završenog admin bloka i traži izmjenu oba `SPEC.md`-a. Trošak je ponovni
  QA svih ekrana, dobitak je poklapanje sa PNG-om u pismu.
- **Barlow samo u klijentu** — odbačeno: mono problem nestaje, ali ostaje da klijent gubi
  DM Serif Display, koji `prototype/ui/SPEC.md:110` vezuje za naslove i **brojeve** (vrijeme
  termina, cijena, 44–58px). To je karakter klijentskog izgleda, ne slučajan izbor.
- **Barlow Condensed samo za navigaciju i sekcijske oznake, ostalo ostaje** — odbačeno: treće
  pismo u aplikaciji koja ih već ima dva, zarad sloja koji `Archivo`/`Space Grotesk` nose sa
  letterspacingom.
- **Zamjena pisama** — odgođeno, ne odbačeno: vraća se na sto ako stigne handoff koji **imenuje
  šta nosi inline podatak u adminu** umjesto JetBrains Mono, i ako se planira QA prolaz kroz sve
  admin ekrane kao dio tog posla. Tada je to zaseban epik, ne stavka u FE-102.

## Posljedice

- **FE-102 je zatvoren kao „neće se raditi"**, ne kao gotov. FE-3xx i FE-4xx su time odblokirani.
- Klijentski i admin ekrani se **neće poklapati sa handoff PNG-ovima u pismu**, kao što se po
  ADR-0018 ne poklapaju u boji. Poklapa se skala, težina i ritam.
- Oba `SPEC.md`-a ostaju **tačna** u dijelu tipografije — ovo je jedina od tri odluke koja ne
  traži izmjenu handoffa.
- **Izgleda kao propušten zahtjev handoffa, a nije**: Barlow je svjesno odbijen, s imenovanim
  uslovom pod kojim se vraća.
