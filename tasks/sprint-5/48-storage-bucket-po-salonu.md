# Task 48 — Storage bucket po salonu

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | 49, 50, 51 |
| **Reference** | [ADR-0015](../../docs/adr/0015-slike-idu-u-supabase-storage-javni-bucket.md) · `.claude/docs/security.md` |

## Cilj
Salon ima gdje spremiti sliku, a nijedan drugi salon mu je ne može ni upisati ni obrisati.

## Definicija gotovog
- [ ] Migracija pravi bucket sa **javnim čitanjem**; `storage.buckets` danas je prazan
- [ ] Putanja počinje sa `salon_id` (`<salon_id>/<vrsta>/<fajl>`), da politika odluči bez pretrage
- [ ] Upis, izmjena i brisanje su dozvoljeni samo vlasniku tog salona (`private.*` helper, isti obrazac kao ostale tabele)
- [ ] Radnik (`employee`) ne upisuje — ADR-0013 mu daje samo njegove termine
- [ ] Ograničenje tipa (slika) i veličine fajla na bucketu, ne samo u aplikaciji
- [ ] pgTAP: vlasnik A upisuje u A; vlasnik A **ne** upisuje u B; radnik ne upisuje; anon čita, ne upisuje
- [ ] `supabase test db` zelen lokalno i `Supabase tests` job zelen na PR-u

## Zamke
- **`x-salon-id` bira kontekst, ne daje prava.** Politika gleda članstvo, a prvi segment putanje
  se poredi sa njim — nikad sa headerom.
- Javno čitanje znači da URL nije tajna. Ništa što identifikuje klijenta ne ide u ovaj bucket.
- Poslije merge-a `supabase db push` na hostovani projekat — bez toga 49 i 50 rade samo lokalno.

## Status
Nije počet.
