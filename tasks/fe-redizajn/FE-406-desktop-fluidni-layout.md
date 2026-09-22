# FE-406 — Desktop je fluidan, ne fiksni 1280

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | FE-402, FE-403, FE-404 |
| **Reference** | `apps/admin/lib/src/core/widgets/admin_scaffold.dart:13` · `apps/admin/lib/src/features/appointments/appointments_screen.dart:45` · `apps/admin/lib/src/features/appointments/appointment_detail_screen.dart:41` |

## Cilj
Admin zauzima cijelu širinu prozora. Mockup 1280×900 je referenca proporcija, ne ciljna širina.

## Zatečeno stanje
**Task iz handoffa je pisan za web aplikaciju sa CSS-om** — traži uklanjanje `width: 1280px`,
`grid-template-columns: repeat(auto-fit, …)` i `max-width` na nivou strane. Admin je **Flutter**
aplikacija koja se gradi i za web; ništa od toga ne postoji kao CSS i ne može se tako uraditi.
Prevedeno u ono što stvarno stoji u kodu:

- **Fiksne širine strane nema.** `AdminScaffold` već daje `Expanded(child: body)` pored sidebara
  fiksne širine (`AdminSize.sidebarWidth`) — to je tačno raspored koji handoff traži.
- **Postoje dva `maxWidth` ograničenja sadržaja**, i ona su prava meta:
  `appointments_screen.dart:45` → `_maxSirinaListe = 1176`,
  `appointment_detail_screen.dart:41` → `_maxSirina = 720`.
- **Breakpoint je jedan**: `AdminBreakpoint.desktop = 840`. Handoff traži četiri pojasa
  (< 900, 900–1440, > 1440, > 1920), dakle tri nova praga.
- Dva ekrana već računaju kolone iz dostupne širine (`employees_screen.dart:116`,
  `calendar_screen.dart:237`) — obrazac postoji, samo nije primijenjen svuda.

## Definicija gotovog
- [x] Na 1920 i 2560 px sadržaj zauzima punu širinu; nema praznih margina oko bloka od 1176 px
      — izmjereno testom: sadržaj na 2560 px ide do 2532
- [x] `_maxSirinaListe` i `_maxSirina` ili nestaju, ili ostaju **samo** na tekstualno teškim
      ekranima sa zapisanim razlogom (duga linija teksta je nečitljiva, tabela nije)
      — `_maxSirinaListe` zamijenjen donjom granicom po kartici; `_maxSirina = 720` ostaje na
      detalju termina uz zapisan razlog
- [x] Definisana četiri pojasa širine, na jednom mjestu, kao i postojeći prag — ne po ekranima
- [x] Ispod 900 px sidebar se sklapa, sadržaj ostaje čitljiv
- [x] Nijedan ekran ne prelijeva ni ne siječe sadržaj između 900 i 2560 px **na ekranu termina
      i zahtjeva** — prelijevanje zahtjeva uhvaćeno i popravljeno. Ostali admin ekrani nisu
      mijenjani ovim taskom i nisu prošireni na pojaseve; v. „Ostaje" ispod.
- [ ] Tabela skroluje horizontalno **unutar sebe**, nikad cijela strana — **nije dirano.**
      Tabelarni ekrani su `services_screen.dart` i `employees_screen.dart`, koje mijenja
      [FE-404](FE-404-upravljanje-podacima.md); dirati ih ovdje značilo bi dva taska u istom
      fajlu.
- [ ] Nema fiksnih visina na blokovima koji nose tekst — **nije provjereno** preko ekrana
      termina; traži prolaz kroz sve admin ekrane, što je [FE-504](FE-504-qa-prolaz.md).

## Zamke
- **Prag se ne izvodi u ekranu.** `AdminShell` postoji baš zato: drugi prag u ekranu znači raspored
  koji se mijenja na jednoj širini, a razmak na drugoj — greška vidljiva samo u uskom pojasu
  između te dvije.
- **`MediaQuery` nije `LayoutBuilder`.** Ekran u sidebar rasporedu ima manje mjesta nego što
  `MediaQuery` kaže; kolone izvedene iz širine prozora ispadnu za jednu previše.
- Postojeći prag 840 ima zapisan razlog (Material `expanded`, tablet u portretu dobija mobilni
  raspored). Novi pojasevi ga ne smiju tiho pregaziti.
- `AdminShell.jeDesktop` su statičke metode **namjerno**, jer ekran gradi tijelo prije nego ga
  ljuska primi. Pretvaranje u `InheritedWidget` vraća telefonske vrijednosti na 1440.

## Status

Kod gotov i dokazan — grana `feat/fe-406-desktop-fluidni-layout`,
[PR #65](https://github.com/htuco/salon-booking-platform/pull/65) je draft.

Sve stavke DoD-a su ispunjene osim gledanja uživo, koje widget test ne zamjenjuje.

**Dokaz:** `flutter test` u `apps/admin` — 288 prolaznih (bilo 278). Geometrija izmjerena, ne
pretpostavljena: 4 kolone na 2560 px, 3 na 1920, 2 na 1440, 1 na 1100 i na telefonu; sadržaj na
2560 ide do 2532 px, dakle bez prazne margine. Svaki novi test provjeren sabotažom — prva verzija
je gledala samo desnu ivicu i prolazila je i kad se lista srozala na jednu razvučenu karticu, pa
se sada mjeri broj kolona u prvom redu.

**Nalaz iz rada.** Zahtjevi (`3d`) ostaju jedna kolona: `_ZahtjevKartica` je raspored
`vrijeme | podaci | radnje` računat za punu radnu površinu i u koloni od ~560 px prelije za
303 px. Uhvatila ga je suita, ne pregled koda; pokriveno testom u `zahtjevi_screen_test.dart`.

**Odluka o `_maxSirina = 720`.** Ograničenje detalja termina **ostaje**, uz zapisan razlog — to
je tekst u jednoj koloni i duga linija se teško čita. DoD tu mogućnost izričito dozvoljava.

**Zatečeno izvan obima:** `apps/client` ima 3 greške analize i 17 palih testova zbog
negenerisanih l10n gettera (`bookingSuccess*Confirmed`). Provjereno na čistom `main`-u bez ovih
izmjena — isti rezultat, dakle nije regresija. Traži `flutter gen-l10n`.

**Viđeno uživo (`/verify`, 2026-09-22).** `flutter build web -t lib/demo_main.dart`, pa admin
u Chromiumu na 1920 i 2560 px. Puna lista termina: 4 kolone na 2560 px, sadržaj do desne ivice,
bez prazne margine — ono što task traži, potvrđeno na ekranu.

**Browser je našao dvije greške koje 288 testova nije.** Obje popravljene u `ca091af`:

1. **Uspravan šav kroz stranicu na detalju termina.** Zaglavlje i traka radnji crtaju svoju
   površinu, a stajali su unutar ograničenja od 720 px — pozadina je prestajala na 720 px, a
   ostatak radne površine bio druge boje. Ograničenje sada ide oko *sadržaja*, ne oko ekrana.
   Prva popravka je uvela drugu grešku (pilula skroz desno, dugmad razvučena preko 2324 px),
   pa je uveden `_UzSadrzaj`: površina puna, sadržaj u koloni.
2. **Kartica zahtjeva razvučena na 2324 px** — tri zone na suprotnim krajevima stola. Vraćena
   granica od 1176 px, ali sada kao granica *kartice*, ne strane.

Postojeći test je mjerio samo `ListView`, pa su **oba** pogrešna stanja prolazila kroz njega.
Nov test mjeri i površinu zaglavlja i širinu dugmeta; provjeren sabotažom.

Ostalo prije nego PR siđe sa drafta:

- [ ] Zelen CI na zadnjem commitu — dokaz iz čistog checkouta.

**Dvije stavke DoD-a namjerno ostaju otvorene i ne zatvara ih ovaj PR** (obrazloženje uz njih):
horizontalni skrol tabela pripada [FE-404](FE-404-upravljanje-podacima.md) jer dira iste fajlove,
a prolaz kroz fiksne visine na svim ekranima je [FE-504](FE-504-qa-prolaz.md). Ovaj task je
pojaseve uveo i primijenio na ekrane termina; ostali admin ekrani ih još ne koriste.
