# Task 85 — Kapacitet i test opterećenja

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [76](76-supabase-produkcija-i-staging.md), [81](81-potvrda-emaila-kodom.md) |
| **Blokira** | [89](89-prelazak-na-produkciju.md) |
| **Reference** | supabase.com/pricing (provjereno 2026-10-12) · Resend pricing |

## Cilj
Lansiranje salona je nalet: stotine registracija i zakazivanja u nekoliko sati. Limiti planova i
servisa moraju to izdržati, a to se dokazuje mjerenjem na stagingu, ne procjenom.

## Definicija gotovog
- [ ] Procjena po salonu (registracije, mailovi, zakazivanja, istovremeno otvorene app-e) zapisana
- [ ] Supabase Auth: limit emailova sa vlastitim SMTP-om (počinje na **30/h**) podignut; limit
      registracija po IP-u provjeren (salon sa jednim Wi-Fi-jem!)
- [ ] Resend plan prema procjeni (Free je 100 mailova dnevno — ne izdrži prvi dan salona)
- [ ] **Realtime konekcije**: svaka otvorena klijentska app drži jednu; Free 200, Pro 500 — procjena
      i odluka (limit, ili osvježavanje bez realtimea)
- [ ] Test opterećenja na stagingu (k6 ili sličan): npr. 300 registracija i 100 zakazivanja u sat,
      realan broj otvorenih app-a; bez grešaka, bez izgubljenih kodova
- [ ] Spend cap / budžetni alarmi na Supabaseu i Resendu

## Status
Nije počet.
