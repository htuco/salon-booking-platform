# Task 75 — ID-evi aplikacija na pravoj domeni

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [74](74-domena-dns-email-hosting.md) |
| **Blokira** | [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md), [79](79-firebase-produkcija.md), [84](84-apple-google-prijava.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | `tenants/*/tenant.yaml` · `docs/04` §6 · `docs/research/auth-krajnji-korisnik.md` §3 |

## Cilj
Sve aplikacije su danas `ba.nasadomena.*` — placeholder. ID se **poslije prve objave ne može
mijenjati**, pa ovo mora prije nje. Salon ne kupuje domenu: jedna domena projekta pokriva sve.

## Definicija gotovog
- [ ] `applicationId`/`bundleId` → `<domena>.<flavor>` za sve tenante i admin; generatori, CI matrice,
      redirect URL-ovi u `config.toml` i Supabase konzoli, Firebase app-e
- [ ] `store.privacyPolicyUrl` i `supportEmail` u `tenant.yaml` na pravu domenu (stranice postoje — 74)
- [ ] ID-evi se mijenjaju **prije** pravljenja app-a u Firebaseu, App Store Connectu i Play Consoleu
      (77–79) — tamo se ID poslije ne može promijeniti

## Zamke
- Lokalni buildovi na iPhoneu (lični tim) dobijaju nove ID-eve — stare app-e treba obrisati.

## Status
Nije počet.
