# Task 89 — Prelazak pravih salona na produkciju

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [75](75-id-evi-aplikacija.md), [76](76-supabase-produkcija-i-staging.md), [77](77-apple-developer-produkcija.md), [78](78-google-play-i-cloud.md), [79](79-firebase-produkcija.md), [80](80-tajne-i-ci-okruzenja.md), [81](81-potvrda-emaila-kodom.md), [82](82-izmjena-profila-klijenta.md), [83](83-crashlytics.md), [84](84-apple-google-prijava.md), [85](85-kapacitet-i-opterecenje.md), [86](86-backup-nadzor-alarmi.md), [87](87-sigurnosni-pregled.md), [88](88-pravno-i-podrska.md), [60](../polishing/60-regresija-i-testiranje.md) (regresija) |
| **Blokira** | [90](90-release-i-store.md) |
| **Reference** | PR #129 (Authentic), task 61 (Amko) |

## Cilj
Amko i Authentic danas žive na razvojnom hostovanom projektu, sa razvojnim ključevima i starim
ID-evima. Prelaze na produkciju bez gubitka podataka, a stari projekat se gasi.

## Definicija gotovog
- [ ] Plan prelaska po salonu: salon, postavke, usluge, radnici, radno vrijeme, slike iz Storagea,
      nalozi osoblja (kroz poziv, novi), budući termini (ako ih ima)
- [ ] Prelazak isproban prvo na stagingu
- [ ] Buildovi sa produkcijskim okruženjem i konačnim ID-evima; stare app-e uklonjene sa uređaja
- [ ] Salon obaviješten unaprijed; vlasnik i radnici se prijave na produkciji
- [ ] Stari hostovani projekat: podaci izvezeni, ključevi opozvani, projekat ugašen
- [ ] `tasks/CURRENT.md` i `workflows.md` više ne spominju razvojni projekat kao „hostovani"

## Status
Nije počet.
