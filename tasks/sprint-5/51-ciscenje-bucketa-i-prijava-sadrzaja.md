# Task 51 — Čišćenje bucketa i prijava neprikladnog sadržaja

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | — |
| **Reference** | ADR-0015 §Posljedice |

## Cilj
Bucket ne raste zauvijek, a aplikacija ispunjava zahtjev store reviewa za sadržaj koji objavljuje salon.

## Definicija gotovog
- [ ] Zamijenjena ili obrisana slika nestaje iz bucketa (u istoj operaciji ili periodičnim čišćenjem siročadi)
- [ ] Brisanje usluge, radnika ili slike iz galerije briše i fajl
- [ ] Klijent može prijaviti neprikladnu sliku iz galerije; prijava stiže platformi, ne salonu
- [ ] Test: fajl bez reference nestaje; fajl sa referencom ostaje
- [ ] Uživo: zamjena slike ostavlja jedan fajl u bucketu, ne dva

## Zamke
- Čišćenje koje briše po putanji mora ostati unutar `salon_id` prefiksa — greška ovdje briše tuđe slike.
- Prijava sadržaja je zahtjev za store, ne feature za salon. Kome stiže i ko odlučuje treba zapisati.

## Status
Nije počet.
