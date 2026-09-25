# Task 56 — Push podsjetnici D-1 i H-3

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `docs/01` §6.2 · `supabase/functions/send-reminders/README.md` · sprint-4 task 39 |

## Cilj
Klijent dan prije i tri sata prije termina dobije push, tačno jednom.

## Definicija gotovog
- [ ] `send-reminders` postoji kao kod — danas je samo README
- [ ] Podsjetnik ide samo za `confirmed` termin i samo ako salon ima `reminders_enabled`
- [ ] Tipovi `reminder_d1` i `reminder_h3` već postoje u `notification_type`; red u `notification_logs`
      se pravi jednom po terminu i tipu — restart schedulera ne duplira
- [ ] Slanje ide postojećim putem (`dispatch_push`, task 39), ne drugim kanalom
- [ ] Otkazan ili pomjeren termin ne dobija podsjetnik koji je ostao u redu
- [ ] pgTAP: pravi se tačno jedan red; drugi prolaz ne pravi novi; otkazan termin ne dobija red
- [ ] Uživo na Android uređaju: termin za sutra → D-1 stiže, tekst po vertikali

## Zamke
- **Vremenska zona.** „Sutra u 14:30" je lokalno vrijeme salona, a cron radi u UTC-u.
- Termin zakazan za manje od 3 sata ne smije dobiti H-3 poslije početka.
- Poslije merge-a migracija na hostovani projekat; cron bez migracije ne radi ništa.

## Status
Nije počet.
