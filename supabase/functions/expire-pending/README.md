# expire-pending

**Nije Edge Function.** Istek neodgovorenih zahtjeva (task 64) je cijeli u bazi:
`pg_cron` posao `expire-pending` svakih 5 minuta zove `private.expire_pending()`
(migracija `20261013100000_istek_zahtjeva.sql`). Nema HTTP poziva, tajne ni workera — samo
`update` nad `appointments`, pa bi Edge Function bila mreža bez razloga.

Istekao `pending` (rok `pending_expires_at` ili početak termina prošao) postaje `cancelled`,
`cancelled_by = 'system'`, `cancel_reason = 'isteklo'`. Klijent dobija push tipa `expired` kroz
postojeći `queue_appointment_push` → `dispatch_push` → `send-push`. V. docs/01 §8 i
`.claude/docs/security.md`, „Istek zahtjeva".

Folder ostaje da stare reference (`docs/07`, task 64) ne vode u prazno.
