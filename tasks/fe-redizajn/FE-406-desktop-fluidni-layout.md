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
- [ ] Na 1920 i 2560 px sadržaj zauzima punu širinu; nema praznih margina oko bloka od 1176 px
- [ ] `_maxSirinaListe` i `_maxSirina` ili nestaju, ili ostaju **samo** na tekstualno teškim
      ekranima sa zapisanim razlogom (duga linija teksta je nečitljiva, tabela nije)
- [ ] Definisana četiri pojasa širine, na jednom mjestu, kao i postojeći prag — ne po ekranima
- [ ] Ispod 900 px sidebar se sklapa, sadržaj ostaje čitljiv
- [ ] Nijedan ekran ne prelijeva ni ne siječe sadržaj između 900 i 2560 px
- [ ] Tabela skroluje horizontalno **unutar sebe**, nikad cijela strana
- [ ] Nema fiksnih visina na blokovima koji nose tekst

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

Nije počet.
