# Task 80 — Tajne, rotacija i CI okruženja

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [76](76-supabase-produkcija-i-staging.md), [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md), [79](79-firebase-produkcija.md) |
| **Blokira** | [89](89-prelazak-na-produkciju.md), [90](90-release-i-store.md) |
| **Reference** | `.claude/docs/workflows.md` · `tool/build_tenant.sh` · `.env.example` |

## Cilj
Nijedna tajna iz razvoja ne stiže do produkcije, i svaka produkcijska tajna ima jedno mjesto, vlasnika
i postupak rotacije.

## Definicija gotovog
- [ ] Popis svih tajni i konfiguracije: Supabase URL/anon/service role/DB lozinka, Firebase fajlovi i
      service account, APNs i Apple ključevi, upload keystore, Google client ID-evi, Resend API ključ,
      App Store Connect API ključ — za svaku: gdje živi, ko je čita, kako se rotira
- [ ] GitHub **environments** `staging` i `production`; produkcijski deploy i release traže odobrenje
- [ ] Sve današnje vrijednosti (`.env.live`, stari hostovani projekat, lični Apple tim) proglašene
      razvojnim; produkcija ih nikad ne koristi
- [ ] Secret scanning na repou; provjera da u istoriji gita nema tajni
- [ ] `build_tenant.sh` i CI čitaju samo iz okruženja; `workflows.md` opisuje oba okruženja
- [ ] Postupak rotacije isproban jednom na stagingu (npr. novi Resend ključ bez prekida slanja)

## Status
Nije počet.
