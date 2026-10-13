# Task 70 — Istorija obavijesti u klijentskoj app-i

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | task 21 · FE-306 · `notification_logs` |

## Cilj
Ekran „Obavijesti" danas je uvijek prazan. Klijent vidi push poruke koje je dobio (potvrda, odbijanje,
podsjetnik, lista čekanja) i otvara termin iz njih.

## Definicija gotovog
- [x] RLS: klijent čita samo svoje redove iz `notification_logs` (ili pogled), negativan test
- [x] Lista po datumu, tap otvara termin; oznaka nepročitanog
- [x] Prazno stanje ostaje za korisnika bez obavijesti

## Status (2026-10-13) — 🟡 dokazano lokalno, čeka deploy

Grana `feat/istorija-obavijesti`. Migracija `20261013140000_istorija_obavijesti.sql`:
`notification_logs.read_at`, RPC `my_notifications(p_limit)` i `mark_notifications_read()`. Klijent
i dalje nema politiku nad tabelom. Vlasništvo ide preko termina (`owns_identity`), redovi poslani
osoblju se ne vide, a stavka je jedna po (termin, tip) bez obzira na broj uređaja.
`ClientNotification` (`core_domain`), `NotificationRepository` (`core_api`), ekran po `5j`: „Danas ·
09:12" / „Jučer" / „12.04.", nepročitano je jača ivica i „Novo" za čitač ekrana. Otvaranje liste
označava pročitano, a tap vodi na „Moji termini", isto kao push. Demo ima dvije obavijesti.

**Dokazano:** pgTAP `029` (17 asercija). Mutacije: bez `owns_identity`, bez filtera osoblja i bez
filtera salona obaraju po jednu aserciju. Cijela suite je PASS. `core_domain` 91, `core_api` 141 i
klijent 639 testova PASS (nov `notifications_screen_test`, 8), `flutter analyze` čist. Demo web
build na 402 px pokazuje listu kao handoff `10-obavijesti.png`.

**Ostalo za sljedećeg:**
- Hamza poslije merge-a: `supabase db push`. Provjera: `select proname from pg_proc where proname in
  ('my_notifications','mark_notifications_read')` vraća oba.
- Prava obavijest viđena na uređaju poslije pusha. Za podsjetnike (56) i listu čekanja (68) stavke
  same dobijaju naslov kad tipovi stignu: `reminder_*` ima tekst, a nepoznat tip dobija „Obavijest".
