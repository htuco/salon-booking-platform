# Task 39 — Push obavijesti na Androidu

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | 42 |
| **Reference** | `supabase/functions/send-push/` · task [25](../sprint-2/25-push-notifikacije.md) |

## Cilj
Push je prestao stizati na Androidu.

## Definicija gotovog
- [ ] Imenovano **gdje** lanac puca: `register_device`, `notification_logs`, `pg_cron`, Edge
      Function `send-push`, ili odgovor FCM-a
- [ ] Dokaz iz `notification_logs` — red sa `status`, `attempts` i `error`, ne tvrdnja da radi
- [ ] Obavijest stigla na Android emulator ili uređaj, sa snimkom
- [ ] Ako je uzrok istekao ključ ili promjena konfiguracije, to je zapisano u `workflows.md`

## Koraci
1. Ima li uređaj red u `devices` i je li `fcm_token` svjež
2. `notification_logs` za zadnje pokušaje
3. Pozvati `send-push` ručno i pročitati odgovor FCM-a
4. Tek onda tražiti grešku u aplikaciji

## Zamke
- **`devices.device_id` nije `appointments.device_id`** — prvo je instalacioni identifikator, drugo
  FK na `devices.id`. Zamjena prolazi tipove i tiho slomi push.
- Izlaz `supabase status -o env` nosi service role ključ — ne ide ni u commit ni u sažetak.

## Ostalo izvan repoa
**iOS ostaje nedokazan** dok ne postoji Apple developer nalog. To nije dio DoD-a nego imenovani dug.

## Status

Nije počet.
