# Task 76 — Supabase: produkcijski i staging projekat od nule

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [73](73-nalozi-i-vlasnistvo.md), [74](74-domena-dns-email-hosting.md) |
| **Blokira** | [80](80-tajne-i-ci-okruzenja.md), [81](81-potvrda-emaila-kodom.md), [85](85-kapacitet-i-opterecenje.md), [86](86-backup-nadzor-alarmi.md), [87](87-sigurnosni-pregled.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | `.claude/docs/workflows.md` · `.claude/docs/security.md` · `supabase/config.toml` |

## Cilj
Dva nova projekta: **produkcija** (samo pravi saloni) i **staging** (demo, testovi, test opterećenja).
Današnji hostovani projekat miješa demo salone i prave (Amko, Authentic) i ne ide u produkciju.

## Definicija gotovog
- [ ] Produkcija na **Pro planu** (bez pauziranja, dnevni backup); region u EU (Frankfurt)
- [ ] Staging: zaseban projekat (odluka: Pro org + mali compute, ili Free uz pauziranje — zapisati)
- [ ] Sve migracije kroz `supabase db push`; seed na produkciji **samo referentni podaci**
      (vertikale, platformska pravila) — bez demo salona i test naloga
- [ ] Auth: Site URL i redirect URL-ovi po flavoru, *Confirm email* + OTP kod (81), politika lozinke,
      rate limiti podignuti po 85, custom SMTP (Resend)
- [ ] Storage bucket `salon-media`, cron jobovi (`cleanup-media`, 56, 64), Vault tajne
- [ ] Edge Functions deployane sa tajnama u Supabase secrets, nikad u repou
- [ ] Jaka lozinka baze u trezoru; pristup bazi samo kroz pooler; 2FA na Supabase nalogu
- [ ] Supabase advisors (security + performance) bez upozorenja
- [ ] `workflows.md`: kako se deploya na staging, a kako na produkciju (sa odobrenjem, 80)

## Status
Nije počet.
