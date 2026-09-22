# FE-405 — Prijava (admin)

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 0,5 dan |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/auth/login_screen.dart` · `apps/admin/test/login_screen_test.dart` · `prototype/adminv2/export/3j-prijava.png`, `3u-telefon-prijava.png` |

## Cilj
Forma lijevo, fotografija salona desno sa svijetlim prelazom.

## Zatečeno stanje
Ekran postoji, nosi znak `SO` i natpis „Salon OS" (`login_screen.dart:505`) i
`CircularProgressIndicator`. `login_screen_test.dart:121` tvrdi da „Salon OS" postoji na ekranu — ta
asercija pada čim [FE-401](FE-401-admin-shell.md) preimenuje proizvod, pa se mijenja u istoj promjeni.

## Definicija gotovog
- [x] „Prijavi se" je koralno dugme, tekst `#2C2C2C` — dolazi iz teme
      (`FilledButton` → `action`/`onAction`), ne iz ekrana. Bijela na koralu pada AA
      (3,05:1), pa `onAccent` ovdje **ne** ide.
- [x] Fotografija nestaje ispod 1000 px, forma zauzima punu širinu — `kPragFotografije`,
      namjerno **nije** `AdminBreakpoint.desktop` (840): taj prag bira ljusku, a prijava
      nema ljusku
- [x] Greška prijave stoji **iznad forme**, ne kao alert ni SnackBar — zatečeno stanje,
      nije mijenjano, ali je sada provjereno
- [x] Generička poruka za pogrešne podatke — `AuthRejectedError` daje „Pogrešan email ili
      lozinka.", bez razdvajanja na „nema naloga" i „pogrešna lozinka"
- [x] Indikator u toku prijave nije Material spinner — `_IndikatorPrijave`, tri tačke u
      boji `onAction`
- [x] Melura wordmark umjesto „Salon OS" — urađeno uz FE-401 (`AdminWordmark`)

## Zamke
- **Poruka o grešci ne smije razlikovati „nema naloga" od „pogrešna lozinka".** To je endpoint
  kojim se nabrajaju nalozi; ista je odluka već donesena za `book_appointment`.
- Prijava je jedini ekran koji vidi neprijavljen korisnik — ovdje se bijeli bljesak iz
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) najviše vidi.

## Status

Kod gotov i dokazan — grana `feat/fe-405-prijava`.

**Dokaz:** `flutter test` u `apps/admin` — **299 prolaznih** (bilo 294), čista analiza i format.

**Polovina DoD-a je bila zatečena.** Greška iznad forme, generička poruka i wordmark su već
stajali (posljednji iz FE-401). Stvarni rad su bila tri: prag od 1000, indikator i komentar uz
dugme koji je tvrdio da je „akcentna plava" po starom canvasu.

**Browser je našao bug koji suita nije: dugme „Prijavi se" se na 960 px crtalo dvaput.**
Raspored je prešao na `kPragFotografije` (1000), ali je `_forma` i dalje pitala
`AdminShell.jeDesktop` (840) hoće li nacrtati dugme u koloni — pa su se u pojasu 840–1000
palila oba puta, jednom u formi i jednom u traci ispod skrola. **To je tačno zamka o dva praga
koju FE-406 opisuje**, samo unutar jednog ekrana. Nijedan test je nije hvatao jer su testne
širine (1440, 1920, 402) preskakale taj pojas; sada se mjere četiri širine, uključujući 960.

Sve tri promjene provjerene sabotažom: prag vraćen na `jeDesktop` obori test raspored**i**
duplo dugme, Material spinner vraćen u dugme obori test indikatora.

**Jedna sabotaža je u prvom pokušaju lažno prošla** — `dart format` je liniju sklopio u jednu,
pa `sed` nije pogodio i izmjena se nije ni desila. Ponovljena nad stvarnim tekstom i tada je
test pao kako treba. Vrijedi zapamtiti: poslije sabotaže provjeriti da je fajl stvarno izmijenjen.

Viđeno uživo na obje strane praga (`flutter build web` + Chromium): **960 px** — tamno zaglavlje
iznad forme, jedno dugme u donjoj traci, napomena o pristupu ispod polja; **1440 px** — forma
lijevo u koloni od 560, tamna ploha desno, dugme u koloni.

Ostalo:

- [x] Zelen CI — `Analiza, format i testovi` pass, 3m25s.
