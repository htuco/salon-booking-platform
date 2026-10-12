# Task 79 — Firebase: push i Crashlytics od nule

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [73](73-nalozi-i-vlasnistvo.md), [75](75-id-evi-aplikacija.md), [77](77-apple-developer-produkcija.md) |
| **Blokira** | [80](80-tajne-i-ci-okruzenja.md), [83](83-crashlytics.md), [86](86-backup-nadzor-alarmi.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | task 39 · `tool/firebase_defines.dart` · `.claude/docs/tenant-factory.md` §Firebase |

## Cilj
Push i praćenje rušenja na produkcijskim Firebase projektima, sa konačnim ID-evima aplikacija.

## Definicija gotovog
- [ ] Firebase projekti: **produkcija** i **staging**
- [ ] Android i iOS app po flavoru + admin (Melura), sa konačnim `applicationId`/`bundleId` iz 75
- [ ] APNs ključ (`.p8`) iz Apple Developera uploadovan u Firebase (iOS push)
- [ ] Service account za `send-push` u Supabase secrets (produkcija i staging zasebno)
- [ ] `google-services.json` / `GoogleService-Info.plist` samo u CI tajnama (`FIREBASE_*_<FLAVOR>`),
      placeholder u repou ostaje
- [ ] Crashlytics uključen (83)
- [ ] Push uživo na Androidu i iOS-u, za klijent i Meluru, na produkcijskom projektu

## Status
Nije počet.
