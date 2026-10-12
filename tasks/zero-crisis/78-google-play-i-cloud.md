# Task 78 — Google Play i Google Cloud od nule

| | |
|---|---|
| **Procjena** | 1–2 dana + Google verifikacija |
| **Zavisi od** | [73](73-nalozi-i-vlasnistvo.md), [74](74-domena-dns-email-hosting.md), [75](75-id-evi-aplikacija.md) |
| **Blokira** | [80](80-tajne-i-ci-okruzenja.md), [84](84-apple-google-prijava.md), [89](89-prelazak-na-produkciju.md), [90](90-release-i-store.md) |
| **Reference** | task 04 · `docs/06` §7.1 · `tasks/sprint-2/12-konzole-checklist.md` §1 |

## Cilj
Android buildovi se potpisuju i objavljuju sa organizacijskog naloga; Google prijava radi sa pravim
client ID-evima.

## Definicija gotovog
- [ ] Play Console: aplikacija po salonu + Melura; **Play App Signing** uključen
- [ ] **Upload keystore** napravljen jednom, u trezoru i u CI tajnama; nikad u repou (task 04)
- [ ] Internal testing traka sa testerima
- [ ] Google Cloud: OAuth consent screen (ime firme, domena, politika privatnosti) i verifikacija
- [ ] OAuth klijenti **po flavoru**: Android (SHA-1 upload ključa **i** Play App Signing ključa),
      iOS, web (za Supabase) — v. `docs/06` §7.1 zašto ne jedan zajednički
- [ ] Client ID-evi u GitHub `vars` po flavoru (`GOOGLE_*_CLIENT_ID_<FLAVOR>`)
- [ ] Data safety formular (podaci iz ADR-0029 + Crashlytics)
- [ ] Web link za brisanje računa upisan u Play Console (74)

## Status
Nije počet.
