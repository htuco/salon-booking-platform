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
- [x] Migracija pravi bucket sa **javnim čitanjem**; `storage.buckets` danas je prazan
- [x] Putanja počinje sa `salon_id` (`<salon_id>/<vrsta>/<fajl>`), da politika odluči bez pretrage
- [x] Upis, izmjena i brisanje su dozvoljeni samo vlasniku tog salona (`private.*` helper, isti obrazac kao ostale tabele)
- [x] Radnik (`employee`) ne upisuje — ADR-0013 mu daje samo njegove termine
- [x] Ograničenje tipa (slika) i veličine fajla na bucketu, ne samo u aplikaciji
- [x] pgTAP: vlasnik A upisuje u A; vlasnik A **ne** upisuje u B; radnik ne upisuje; anon čita, ne upisuje
- [ ] `supabase test db` zelen lokalno (✅) i `Supabase tests` job zelen na PR-u (čeka CI kvotu)

## Zamke
- **`x-salon-id` bira kontekst, ne daje prava.** Politika gleda članstvo, a prvi segment putanje
  se poredi sa njim — nikad sa headerom.
- Javno čitanje znači da URL nije tajna. Ništa što identifikuje klijenta ne ide u ovaj bucket.
- Poslije merge-a `supabase db push` na hostovani projekat — bez toga 49 i 50 rade samo lokalno.

## Status (2026-09-26)

🟡 **Gotov lokalno, čeka CI i `supabase db push`.** Grana `feat/storage-bucket-po-salonu`.

- Migracija `20260926100000_storage_bucket_po_salonu.sql`: bucket `salon-media` (javan, 5 MiB,
  `image/jpeg|png|webp` — SVG namjerno ne), `private.storage_salon_id(name)` i četiri politike nad
  `storage.objects`, sve `private.is_admin(...)` nad prvim segmentom putanje.
- `022_storage_bucket.test.sql`: 27 asercija. Oslabljen `insert`/`select` obara 12, `update` 1,
  `delete` 1 — izmjereno u ovoj sesiji.
- `rest_storage.ts`: 19 provjera kroz stvaran Storage API (tip, veličina, javni URL, prepis tuđeg,
  `move`/`copy` u tuđi salon, brisanje). Uvezan u `tool/test_supabase.sh` i CI.
- `./tool/test_supabase.sh`: `Files=22, Tests=624 … Result: PASS`, `rest_storage: 19 provjera prolazi`,
  „Sve prolazi".
- `rls-auditor`: bez curenja; tri nalaza o slijepim testovima (UPDATE/DELETE iza SELECT-a, move/copy,
  pravi klijent sa `x-salon-id`) — sva tri popravljena prije commita.

**Ostalo za sljedećeg:**
- `Supabase tests` job — GitHub Actions blokiran do 29.09.2026.
- Poslije merge-a: `supabase db push` na hostovani projekat; bez toga 49 i 50 rade samo lokalno.
- Lokalna zamka: Storage kontejner mora biti verzije iz `supabase/.temp/storage-version`, inače
  upload daje `500 42P10` (v. `.claude/docs/workflows.md`).
