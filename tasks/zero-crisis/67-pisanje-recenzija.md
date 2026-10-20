# Task 67 — Pisanje recenzija

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md) |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `20260914090000_reviews.sql` · `/reviews` (samo čitanje) |

## Cilj
Klijent ocjenjuje termin koji je stvarno imao. Tabela `reviews` danas nije vezana ni za termin ni za
klijenta (`author_name` je slobodan tekst), a admin u njoj može sve — i mijenjati tuđi tekst.

## Definicija gotovog
- [ ] Migracija: recenzija vezana za **završen termin** i identitet; najviše jedna po terminu
- [ ] Klijent: ocjena 1–5 i opcionalan tekst, iz „Moji termini" i iz pusha poslije termina
- [ ] Salon **sakriva**, ali **ne mijenja** recenziju (politika `staff_manage` suzena)
- [ ] Prijava neprikladne recenzije ide platformi (isti put kao slike, ADR-0024)
- [ ] Prosjek i broj na Početnoj iz `salon_rating_summary`
- [ ] pgTAP: bez završenog termina nema recenzije, druga za isti termin pada, salon ne mijenja tekst
- [ ] `security.md` dopuna

## Status
U toku (2026-10-20), grana `feat/pisanje-recenzija`.
