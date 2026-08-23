# expire-pending

`pg_cron` okidač, svakih 15 min — termini u `pending` duže od
`pendingExpiryHours` prelaze u `cancelled`. V. docs/01 §8.

Implementacija dolazi u Sprint 1 (docs/01 §17).
