# Task 22 — Šema: fotografije usluga i staž radnika

| | |
|---|---|
| **Procjena** | 0.5 dana |
| **Zavisi od** | — |
| **Blokira** | [18](18-pocetna-i-tab-bar.md), [20](20-galerija-recenzije.md), i 1:1 na koraku 1 |
| **Reference** | `prototype/ui/README.md` §Fotografije · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Dvije kolone koje handoff traži, a šema nema. Bez njih red usluge ima prazan okvir i nikad neće
biti 1:1 sa mockupom.

## Definicija gotovog
- [ ] `services.image_url` (nullable) — thumb 1:1, 76 px u redu usluge
- [ ] `employees.experience_years` (nullable int) — handoff piše "Barber · 9 godina"
- [ ] Modeli u `core_domain` prošireni, `fromJson` testovi dopunjeni
- [ ] `seed.sql` puni obje kolone za oba demo salona
- [ ] `anon` politika propušta nove kolone (javni katalog) — provjereno REST testom
- [ ] Ekran koraka 1 i 2 prikazuju thumb i staž kad postoje, prazan okvir kad ne

## Koraci
1. Migracija, seed, pa model, pa ekran
2. `./tool/test_supabase.sh`
3. Commit: `feat(supabase): slike usluga i staz radnika`

## Zamke
- **Nullable namjerno.** Salon koji nema fotografije mora raditi; prazan okvir je predviđeno
  stanje, ne greška.
- Ne dodavati `image_url` kao obavezan u modelu — app iz storea je starija od baze i mora
  podnijeti red bez kolone.
