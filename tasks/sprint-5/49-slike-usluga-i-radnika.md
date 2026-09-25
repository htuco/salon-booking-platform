# Task 49 — Vlasnik postavlja sliku usluge i radnika

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | 52, 53 |
| **Reference** | ADR-0015 · `docs/01` §6.3 (Employees: slika) |

## Cilj
Vlasnik iz admina doda ili zamijeni sliku usluge i radnika, a klijent je vidi u aplikaciji.

## Definicija gotovog
- [ ] Izbor slike u obrascu usluge i obrascu radnika (web i mobilni admin)
- [ ] Upload u bucket iz taska 48, pa `image_url` dobija javni URL — kolona ostaje gdje jest
- [ ] Prikaz napretka i greške; neuspio upload ne mijenja postojeću sliku
- [ ] Uklanjanje slike vraća placeholder (inicijal / prazna površina), ne slomljenu sliku
- [ ] Klijentska aplikacija prikazuje novu sliku na početnoj, u cjenovniku i u „Naš tim"
- [ ] Widget testovi za obrazac; uživo: upload u adminu → slika u klijentu, oba tenanta

## Zamke
- Zamijenjena slika ostaje u bucketu dok task 51 ne uvede čišćenje — ovdje se to svjesno ne rješava,
  ali putanja mora biti takva da 51 zna šta je siroče.
- Veličina: telefon šalje 4–12 MB. Smanjenje prije uploada ili limit na bucketu — ne oboje napola.

## Status
Nije počet.
