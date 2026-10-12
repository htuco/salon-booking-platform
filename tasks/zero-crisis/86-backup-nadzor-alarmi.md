# Task 86 — Backup, oporavak, nadzor i alarmi

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [76](76-supabase-produkcija-i-staging.md), [79](79-firebase-produkcija.md) |
| **Blokira** | [89](89-prelazak-na-produkciju.md) |
| **Reference** | task 83 (Crashlytics) · `supabase/functions/` |

## Cilj
Kad nešto padne, saznajemo mi prije salona, i podaci se mogu vratiti.

## Definicija gotovog
- [ ] Dnevni backup produkcije (Pro); odluka o PITR-u zapisana (skup, za početak vjerovatno ne)
- [ ] **Vraćanje iz backupa isprobano** na stagingu, sa zapisanim trajanjem
- [ ] Backup Storage slika (backup baze ne pokriva bucket)
- [ ] Alarmi: greške Edge Functions, cron koji ne radi (56, 64, `cleanup-media`), mailovi koji
      ne odlaze (Resend webhook za bounce/fail), API nedostupan (uptime provjera)
- [ ] Crashlytics alarmi za novi tip rušenja
- [ ] Jedan kanal gdje alarmi stižu i ko ih gleda

## Status
Nije počet.
