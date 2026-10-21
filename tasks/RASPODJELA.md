# Raspodjela — ko može uzeti koji task

Za taskove iz [`polishing/`](polishing/) i [`zero-crisis/`](zero-crisis/). Pravila su u
[`docs/TEAM_HANDBOOK.md` §6](../docs/TEAM_HANDBOOK.md#6-ko-šta-smije--tim-i-hamza).

**Dvije kategorije, bez miješanja:**

- **Tim** — sve što je proizvod: funkcije, polishing, nove stvari, istraživanja, prijedlozi ADR-ova.
  Od grane do PR-a, dokazano lokalno. Hamza pregleda, mergea i deploya.
- **Hamza** — deploy i sve što priprema produkciju: nalozi, plaćanja, domena, ključevi, produkcijski
  projekti, potpis aplikacija, store. **Tim ovdje ne radi ni pripremni dio.**

Gdje funkcija treba produkcijsku stvar (pravi SMTP, Firebase konfiguraciju, Apple ključ), tim piše
kod i dokazuje ga lokalno; produkcijski dio je već u Hamzinom tasku (73–80) i ne dijeli se.

## Tim

| Folder | Taskovi |
|---|---|
| `polishing/` | 52, 53, 54, 55, 59, 60, 61, 62, 63 |
| `zero-crisis/` faza A | 64, 65, 56, 66, 58, 67, 68, 69, 70, 71, 72, 91 |
| `zero-crisis/` faza C | 81, 57, 82, 83, 84 — kod; produkcijski dio je u 74, 76, 77, 78, 79 |
| `zero-crisis/` faza D | 87 — sigurnosni pregled koda i RLS-a; provjera produkcije je dio 89 |

Za novog kolegu dobri prvi taskovi: **59, 58, 70, 65** — mali, i svaki dira drugi sloj (seed, admin,
klijent, SQL).

Taskovi kojima treba odluka (54 lista, 63 i 69 dizajn, 68 i 72 ADR): kolega piše prijedlog, Hamza
odobrava u PR-u — isto kao svaki drugi pregled.

## Hamza

| Taskovi | Šta |
|---|---|
| 73–80 | Nalozi i vlasništvo, domena i DNS, ID-evi aplikacija, Supabase produkcija i staging, Apple Developer, Google Play i Cloud, Firebase, tajne i CI okruženja |
| 85 | Kapacitet, planovi i test opterećenja |
| 86 | Backup, oporavak, nadzor i alarmi |
| 88 | Pravni dokumenti, podrška i incidenti |
| 89 | Prelazak pravih salona na produkciju |
| 90 | Release i prva objava |

Plus, za svaki merge: deploy na hostovani projekat (migracije, cron, Edge Functions, tajne).
