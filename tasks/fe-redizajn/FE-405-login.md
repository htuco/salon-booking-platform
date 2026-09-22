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
- [ ] „Prijavi se" je koralno dugme, tekst `#2C2C2C`
- [ ] Fotografija nestaje ispod 1000 px, forma zauzima punu širinu
- [ ] Greška prijave stoji **iznad forme**, ne kao alert ni SnackBar
- [ ] Generička poruka za pogrešne podatke — ne otkriva postoji li nalog
- [ ] Indikator u toku prijave nije Material spinner
- [ ] Melura wordmark umjesto „Salon OS"

## Zamke
- **Poruka o grešci ne smije razlikovati „nema naloga" od „pogrešna lozinka".** To je endpoint
  kojim se nabrajaju nalozi; ista je odluka već donesena za `book_appointment`.
- Prijava je jedini ekran koji vidi neprijavljen korisnik — ovdje se bijeli bljesak iz
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) najviše vidi.

## Status

Nije počet.
