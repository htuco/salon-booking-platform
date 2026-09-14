# Taskovi

Raspisani taskovi, po sprintovima. Svaki sprint je folder sa vlastitim `README.md` — tamo su
**tabela taskova** (`#`, task, blokira, procjena, ✅/🟡) i **status blokovi** sa dokazom i onim što
je ostalo za sljedećeg. Pojedinačni task fajl nosi cilj, definiciju gotovog i `## Status`.

**Prvo pročitaj [`CURRENT.md`](CURRENT.md)** — jedan aktivni task, uvijek tačno jedan, i šta je na
njemu urađeno. `CURRENT.md` je **derivat**: kad se raziđe sa task fajlom ili repoom, u pravu su oni.

| Sprint | Taskovi | Šta dokazuje | Stanje |
|---|---|---|---|
| [Sprint 0](sprint-0/) | 01–06 | Native multi-tenant model radi: flavori, RLS izolacija, CI, availability, vertikale | 5 ✅, 1 🟡 |
| [Sprint 1](sprint-1/) | 07–11 | Prvi ekrani — plumbing, `core_api`, `core_ui` theme factory, home, booking flow | 4 ✅, 1 🟡 |
| [Sprint 2](sprint-2/) | 12–26 | Auth, identitet, ostatak handoffa, admin i push | 9 ✅, 2 🟡, 4 otvorena |

🟡 znači **djelimično, sa imenovanim ostatkom** — ne „skoro gotovo". Gdje ostatak čeka nešto izvan
repoa (Apple/Google konzole, keystore, hosting), to je zapisano u status bloku tog taska.

## Redoslijed

Sprintovi idu redom, ali unutar sprinta redoslijed prati **šta blokira šta**, ne prioritet
feature-a. Obrazloženje reda je u [01 §17](../docs/01-mvp-spec.md#17-build-order) i na vrhu svakog
sprint `README.md`-a.

Sprint 0 je namjerno prvi i cijeli je infrastruktura: dok se ne dokaže da dvije brandirane app-e
stoje na istom kodu i da salon ne vidi tuđe podatke, svaki napisan ekran je pretpostavka.

## Kako se task vodi

Životni ciklus je skill `/task` (`load`, `start`, `review`, `verify`, `complete`). Status taska
mijenja se na **tri mjesta u istoj promjeni** — `CURRENT.md`, task fajl (`## Status`) i blok u
`sprint-N/README.md`. Dokazivanje da promjena stvarno radi: skill `/verify`.
