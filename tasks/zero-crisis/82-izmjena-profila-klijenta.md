# Task 82 — Izmjena profila klijenta

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md), [81](81-potvrda-emaila-kodom.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | `docs/research/auth-krajnji-korisnik.md` §7.5 · `account_screen.dart` |

## Cilj
Danas se email i telefon ne mogu promijeniti — samo brisanje računa i novi. Klijent mijenja ime,
telefon i email u „Moj račun".

## Definicija gotovog
- [ ] Ime i telefon: izmjena odmah, propagira se u `customers` svakog salona tog korisnika
- [ ] Email: `updateUser(email)` sa kodom (Secure email change — kod na obje adrese)
- [ ] Apple relay email se ne nudi za izmjenu; Google/Apple korisnik vidi odakle je račun
- [ ] „Moj račun" prikazuje ime, telefon, email i stvarni način prijave (danas uvijek „Email i lozinka")
- [ ] RPC za klijentski profil sa RLS dokazom (samo svoj identitet)

## Status
Nije počet.
