# Task 15 — Dokaz izolacije: isti klijent u dva salona

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | prvi pravi klijent |
| **Reference** | [01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 15 · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Dokazati da salon A **ne vidi** da je njegov klijent i klijent salona B. Ovo je poslovni rizik, ne
tehnička formalnost: salon koji otkrije da mu konkurencija vidi klijentelu otkazuje ugovor.

## Definicija gotovog
- [ ] Deno REST test: isti Apple identitet se prijavi u oba demo salona
- [ ] Admin salona A ne vidi `customers` red iz salona B — ni po `id`, ni po `auth_identity_id`,
      ni kroz `appointments`
- [ ] Klijent ne vidi svoje termine iz salona B dok je `x-salon-id` salon A
- [ ] Test pada kad se politika oslabi — **provjereno namjernim kvarenjem politike**, ne pretpostavkom
- [ ] Test ide u `Supabase tests` suite i vrti se na svaki push u `main`

## Koraci
1. Napiši test **prije** nego što pogledaš politike — ako prođe iz prve, politika je možda slaba
2. Pokvari politiku namjerno, potvrdi da test pada, vrati je
3. Commit: `test(supabase): izolacija klijenta izmedju salona`

## Zamke
- **`x-salon-id` bira kontekst, ne daje članstvo.** Test koji samo mijenja header, a ne provjerava
  šta baza vrati, ne dokazuje ništa.
- Curenje kroz **join** je češće od curenja kroz direktan upit: `appointments → customers` je
  mjesto gdje politika najčešće propusti.
