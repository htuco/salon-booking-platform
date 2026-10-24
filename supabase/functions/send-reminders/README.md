# send-reminders — nije Edge Function

Podsjetnici (D-1 i satni, task 56, [ADR-0033](../../../docs/adr/0033-podsjetnici-dnevni-24h-i-satni-n-sati.md))
**nisu worker** nego SQL u bazi, po obrascu taska 64 (`expire-pending`). Folder ostaje samo da
upućuje ovamo; `index.ts` ne postoji i ne deploya se.

- `pg_cron` posao `queue-reminders` svakih 5 minuta zove `private.queue_reminders()`
  (migracija `supabase/migrations/20261021172634_podsjetnici.sql`).
- Funkcija pravi redove u `notification_logs` (`reminder_d1`, `reminder_h3`) za `confirmed`
  termine, svakom klijentskom uređaju vlasnika termina u salonu termina, sa
  `on conflict (appointment_id, device_id, type) do nothing` — restart crona ili drugi prolaz ne
  duplira.
- Šalje ih postojeći put: `send-push-queued` → `private.dispatch_push()` → `send-push`
  (task 39). `claim_push_notifications` red podsjetnika gasi (`logged`) ako termin više nije
  `confirmed`, ako je počeo, ako je salon ugasio taj podsjetnik ili ako je dnevni zakasnio preko
  ponoći pred dan termina.

Pravila (zona salona iz `salon_settings.timezone`; cron radi u UTC-u):

| Tip | Postavka | Šalje se | Najkasnije |
|---|---|---|---|
| `reminder_d1` | `reminders_enabled` | tačno 24 h prije početka | do ponoći pred dan termina |
| `reminder_h3` | `hourly_reminder_enabled`, `hourly_reminder_hours` (1–12, podrazumijevano 3) | N h prije početka | do početka |

Termin zakazan ili potvrđen **kasnije** od trenutka podsjetnika ga ne dobija
(`appointments.confirmed_at`, ADR-0033). Ime `reminder_h3` ostaje i kad N nije 3.

Dokaz: `supabase/tests/035_podsjetnici.test.sql`. Komande i provjera poslije deploya:
`.claude/docs/workflows.md`, „Podsjetnici (task 56)".
