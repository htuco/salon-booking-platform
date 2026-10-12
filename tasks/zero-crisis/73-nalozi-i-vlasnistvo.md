# Task 73 — Produkcijski nalozi i vlasništvo

| | |
|---|---|
| **Procjena** | 1–2 dana rada + čekanje verifikacija (D-U-N-S i Apple/Google mogu trajati 1–3 sedmice) |
| **Zavisi od** | registrovana firma |
| **Blokira** | [74](74-domena-dns-email-hosting.md), [76](76-supabase-produkcija-i-staging.md), [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md), [79](79-firebase-produkcija.md) |
| **Reference** | `docs/01` §13 · `docs/04` §6 · `tasks/sprint-2/12-konzole-checklist.md` |

## Cilj
Svaki servis od kojeg aplikacija zavisi ima **nalog na firmu**, ne na lični email, sa najmanje dva
administratora i 2FA na samom nalogu. Polazi se od nule: nijedan postojeći ključ, projekat ni nalog
se ne prenosi u produkciju (rotacija, ADR-0029).

## Definicija gotovog
- [ ] Zajednički email firme za naloge (npr. `admin@<domena>`, ne lični) — zavisi od 74
- [ ] Menadžer lozinki za tim (jedan trezor, dva člana); sve lozinke i ključevi iz 74–80 su tamo
- [ ] **D-U-N-S broj** firme (besplatan; Apple i Google ga traže za organizacijski nalog)
- [ ] Apple Developer Program — **organizacija**, ne individual (ime firme u storeu)
- [ ] Google Play Console — organizacijski nalog, verifikacija identiteta i firme
- [ ] Google Cloud / Firebase organizacija na firmu
- [ ] Supabase organizacija na firmu; Resend nalog; registrar domene
- [ ] GitHub: repo u organizaciji ili jasno ko je vlasnik; dva admina
- [ ] Tabela „servis → vlasnik → ko ima pristup → gdje je oporavak" u `docs/` (bez tajni)
- [ ] 2FA uključen na **svakom** od ovih naloga (ovo nije 2FA za korisnike aplikacije)

## Zamke
- Apple/Google organizacijski nalog traži da ime firme na D-U-N-S-u tačno odgovara registraciji.
- Nalog na lični email developera je rizik: ko ode, odnese pristup storeu.

## Status
Nije počet.
