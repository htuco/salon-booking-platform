# Task 20 — Client: Galerija, lightbox i Recenzije

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [18](18-pocetna-i-tab-bar.md), [22](22-sema-slike-i-staz.md) |
| **Blokira** | — |
| **Reference** | `prototype/ui/screenshots/12-galerija.png`, `17-lightbox-galerije.png`, `13-recenzije.png` |

## Cilj
Salon pokazuje rad i ocjene. Ovo je jedini dio app-e koji prodaje prije nego što korisnik zakaže.

## Definicija gotovog
- [ ] `/gallery` — mreža 3 kolone, kvadrat, `gap 8`, bez naslova i opisa na slikama
- [ ] Lightbox 5q: preko cijelog ekrana, brojač "4 / 18", zatvaranje, traka sličica
- [ ] `/reviews` — prosjek u serifu, histogram 5→1, lista recenzija
- [ ] Tabele `gallery_photos` i `reviews` (migracija + seed + RLS `anon` za čitanje)
- [ ] Oba ekrana su **pod-ekrani**: back header, **bez tab bara**
- [ ] Prazno stanje: salon bez galerije ne pokazuje praznu mrežu nego sakrije sekciju na Početnoj

## Koraci
1. Migracija + seed za obje tabele, pa repozitoriji, pa ekrani
2. Lightbox prije galerije — on diktira kako se slike učitavaju
3. Commit: `feat(client): galerija, lightbox i recenzije`

## Zamke
- **Recenzije se ne pišu u app-i** u ovom obimu; dolaze iz admina ili importa. Ekran je read-only.
- Slike su velike: bez `cached_network_image` i `maxWidth` galerija pojede podatke na mobilnoj.
