# Task 74 — Domena, DNS, email podrške i javne stranice

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [73](73-nalozi-i-vlasnistvo.md) |
| **Blokira** | [75](75-id-evi-aplikacija.md), [76](76-supabase-produkcija-i-staging.md), [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md), [81](81-potvrda-emaila-kodom.md) |
| **Reference** | `docs/research/auth-krajnji-korisnik.md` §5 · task 75 |

## Cilj
Jedna domena projekta nosi sve: ID-eve aplikacija, email pošiljaoca, email podrške i javne stranice.
Salon ne kupuje ništa.

## Definicija gotovog
- [ ] Domena kupljena na firmu, auto-obnova uključena
- [ ] DNS kod registrara (ili Cloudflare DNS, besplatno) — zapisano ko ima pristup
- [ ] Poddomena za slanje mailova (npr. `mail.<domena>`) spremna za Resend: SPF, DKIM, DMARC, MX `send`
- [ ] Sanduče ili prosljeđivanje za `podrska@` i `privatnost@` (Apple i Google traže kontakt)
- [ ] Hosting statičnih stranica (Cloudflare Pages ili GitHub Pages, besplatno) sa HTTPS-om
- [ ] Stranice (sadržaj iz 88): uslovi, politika privatnosti po salonu, **zahtjev za brisanje računa**
      (Google Play), podrška
- [ ] `melura-page/` odluka: ide li na istu domenu kao marketing stranica

## Status
Nije počet.
