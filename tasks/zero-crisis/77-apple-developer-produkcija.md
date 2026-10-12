# Task 77 — Apple Developer i App Store Connect od nule

| | |
|---|---|
| **Procjena** | 2 dana + Apple verifikacija |
| **Zavisi od** | [73](73-nalozi-i-vlasnistvo.md), [74](74-domena-dns-email-hosting.md), [75](75-id-evi-aplikacija.md) |
| **Blokira** | [79](79-firebase-produkcija.md), [80](80-tajne-i-ci-okruzenja.md), [84](84-apple-google-prijava.md), [89](89-prelazak-na-produkciju.md), [90](90-release-i-store.md) |
| **Reference** | `docs/04` §6 · `docs/06` §7.2 · `tasks/sprint-2/12-konzole-checklist.md` §2 |

## Cilj
iOS buildovi se potpisuju i objavljuju sa organizacijskog naloga, kroz CI, bez ručnog Xcode-a.

## Definicija gotovog
- [ ] Team ID upisan gdje build treba (CI, ne repo — v. 80)
- [ ] App ID po flavoru + admin, sa capability: Push, Sign in with Apple, Keychain sharing
- [ ] Distribucijski sertifikat i profili kroz CI (App Store Connect API ključ ili `fastlane match`)
- [ ] **APNs ključ** (`.p8`) → Firebase (79)
- [ ] **Sign in with Apple ključ** za Supabase Apple provider **i** za opoziv tokena pri brisanju računa (84)
- [ ] **Private Email Relay**: registrovana domena i adresa pošiljaoca (`mail.<domena>`) — inače
      mailovi korisnicima sa skrivenim emailom ne stižu
- [ ] App Store Connect: aplikacija po salonu + Melura; TestFlight interna grupa
- [ ] Ljudi sa pristupom: najmanje dva, uloge po potrebi (Admin, App Manager)

## Zamke
- Lokalni potpis ličnim timom (`APPLE_SIGN_IN=false`, 7 dana) ostaje samo za razvoj.

## Status
Nije počet.
