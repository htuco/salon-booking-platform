# Task 47 — Admin ljuska za radnika

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [46](46-uloga-employee-i-izolacija.md) |
| **Blokira** | — |
| **Reference** | task [29](../sprint-3/29-responsive-shell.md) · `prototype/admin/SPEC.md` |

## Cilj
Prijavljen radnik dobija istu aplikaciju, ali suženu na ono što smije.

## Definicija gotovog
- [ ] Router guard prima `employee`, ne samo `salon_admin` — danas ga izbacuje na `/login`
- [ ] Navigacija ne nudi module koje radnik nema; ćelija koja vodi u zabranu je gora od ćelije koje nema
- [ ] „Danas", kalendar i lista termina pokazuju **njegove** termine, bez filtera koji se može isključiti
- [ ] Promet i metrike salona se radniku ne prikazuju
- [ ] Widget testovi za obje uloge nad **istim** ekranom — dva stabla bi prolazila i kad ljuska ne radi
- [ ] Viđeno uživo, obje prijave, na 1440 i 402

## Zamke
- **Sužavanje na ekranu nije izolacija.** Ako politika iz taska 46 ne stoji, sakriven modul je i
  dalje dostupan kroz URL i kroz REST. Ekran prati politiku, ne zamjenjuje je.
- `kAdminDestinations` je **jedna** lista za obje širine (task 29) — filter ide u nju, ne u dvije ljuske.

## Status

Nije počet.
