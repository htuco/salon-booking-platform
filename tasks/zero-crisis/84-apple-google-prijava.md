# Task 84 — Apple i Google prijava do kraja

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md), [75](75-id-evi-aplikacija.md), [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | tasks 12, 13 · `docs/06` §7 · `docs/research/auth-krajnji-korisnik.md` §3 |

## Cilj
Prijava jednim tapom, bez kucanja imena: ime (i Google slika) stižu od providera, a fali samo ono
što provider ne daje.

## Definicija gotovog
- [ ] Google client ID-evi po flavoru, Sign in with Apple capability; `APPLE_SIGN_IN` uklonjen iz
      produkcijskih buildova (ostaje za lični tim)
- [ ] Apple ime se čuva pri **prvoj** autorizaciji (već postoji — dokazati na uređaju)
- [ ] Google `picture` se čuva na identitetu i prikazuje u „Moj račun"
- [ ] Ekran **„Dopuni profil"** samo kad fali telefon (ili Apple ime) — nikad ponovo email ni ime
      koje je provider dao (Apple HIG / 4.0)
- [ ] Brisanje računa **opoziva Apple token** (`delete-account/index.ts:116`)
- [ ] Uživo na oba OS-a, na pravom buildu

## Status
Nije počet.
