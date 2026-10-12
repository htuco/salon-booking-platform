# Task 65 — Limit otvorenih zahtjeva po klijentu

| | |
|---|---|
| **Procjena** | 0,5 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | `docs/research/auth-krajnji-korisnik.md` §6 · `book_appointment` (`20260922100000_automatsko_potvrdjivanje.sql`) |

## Cilj
Zaštita od spama bez 2FA (ADR-0029): jedan račun ne može zatrpati salon zahtjevima.
`book_appointment` danas nema nikakav limit.

## Definicija gotovog
- [ ] Najviše **2** `pending` termina po klijentu po salonu (broj u `salon_settings`, default 2)
- [ ] Prekoračenje vraća vlastiti kod (`PT429`) i poruku „Već imate zahtjeve koji čekaju potvrdu"
- [ ] Admin ručno zakazivanje nije ograničeno
- [ ] `p_note` ograničen dužinom (npr. 500 znakova)
- [ ] pgTAP: treći pending pada, potvrđeni se ne broje, drugi salon ima svoj brojač
- [ ] Klijent: `ApiError` mapiranje i poruka na koraku 4

## Status
Nije počet.
