# Task 50 — Galerija salona, logo i cover

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | 52, 53 |
| **Reference** | ADR-0008 · ADR-0015 · `docs/01` §6.1 (logo, cover) |

## Cilj
Salon sam uređuje galeriju radova, logo i naslovnu sliku; „Promjena fotografije" u postavkama
prestaje biti „uskoro".

## Definicija gotovog
- [ ] Galerija: dodaj, obriši i promijeni redoslijed; vrijednost ostaje u `salons.gallery_urls` (ADR-0008)
- [ ] Logo i cover iz postavki salona
- [ ] Klijent vidi novu galeriju i cover na početnoj i u lightboxu
- [ ] Prazna galerija u klijentu ostaje prazno stanje, ne tri sive kutije
- [ ] Widget testovi za editor galerije; uživo na oba tenanta, 1440 i 402

## Zamke
- App ikona i splash su **build** artefakti iz `tenant.yaml`, ne runtime slika — logo iz admina ih ne
  mijenja i to ekran mora reći.
- Redoslijed galerije je redoslijed niza; dva taba koja istovremeno mijenjaju niz ne smiju tiho
  pregaziti jedan drugog.

## Status
Nije počet.
