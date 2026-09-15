# send-push

FCM HTTP v1 worker za redove iz `notification_logs`. Postgres trigger pravi red za novi
zahtjev vlasniku, potvrdu/odbijanje klijentu i otkazivanje. `pg_cron` svake minute poziva
`private.dispatch_push()`; Vault bez konfiguracije znači da redovi ostaju `queued`.

## Konfiguracija

Svi flavori i admin app pripadaju jednom Firebase projektu, sa zasebnim Android/iOS app ID-evima.
Firebase služi samo za FCM. Koraci za aplikacije i fizički dokaz:
`tasks/sprint-2/25-push-konfiguracija.md`.

Edge secrets (nikad u git): `FCM_SERVICE_ACCOUNT_JSON` i `PUSH_WORKER_SECRET`.
Vault secrets: `push_worker_url` (puni `/functions/v1/send-push` URL) i `push_worker_secret`
(ista nasumična tajna kao Edge secret). `SUPABASE_URL` i `SUPABASE_SERVICE_ROLE_KEY` daje runtime.

`verify_jwt = false` je namjerno: korisnički/anon JWT ne daje pravo slanja. Worker provjerava
`Authorization: Bearer <unix-sekunde>.<HMAC-SHA256>` nad `send-push:<unix-sekunde>`, sa odstupanjem
do 60 sekundi. Trajna tajna ne ulazi u `pg_net` transportne tabele. Replay unutar prozora može
samo ponovo pokrenuti obradu reda; primalac i sadržaj nikad ne dolaze iz HTTP payload-a.

## Ishodi

- `queued`: čeka worker; OAuth konfiguracija se provjerava prije preuzimanja.
- `sending`: preuzeto atomskim `FOR UPDATE SKIP LOCKED`; drugi worker preskače taj red.
- `sent`: FCM je prihvatio zahtjev. To **nije potvrda prikaza na telefonu**.
- `failed`: FCM HTTP greška ili `delivery_unknown` nakon timeouta.
- `logged`: primalac više nije dostupan, promijenio je nalog ili se odjavio.

Slanje ima najviše jedan pokušaj po logu. **Nema automatskog ponavljanja `failed`/`sending`**:
timeout ili pad procesa poslije FCM prihvata ne dokazuje da poruka nije poslata. Ručni reset na
`queued` može proizvesti duplikat. Pad procesa poslije claim-a može ostaviti neposlatu poruku u
`sending`; takav red traži operativnu provjeru. Ne obećava se exactly-once isporuka.

Poruka sadrži generički tekst i identifikatore, bez imena, telefona ili razloga otkazivanja.
Tap vodi na `/appointments`, gdje trenutni JWT i RLS ponovo određuju dostupne podatke. Već
predat push ne može se povući odjavom; redovi koji čekaju se gase pri odjavi/promjeni naloga.
`/notifications` ostaje postojeće prazno stanje; klijentska politika za historiju nije uvedena.

## Lokalne Provjere

```sh
supabase test db
deno test supabase/functions/send-push/handler_test.ts
deno check --config supabase/functions/send-push/deno.json supabase/functions/send-push/index.ts
# Uz lokalne SUPABASE_* varijable, bez ispisa ključeva:
deno run --allow-env --allow-net supabase/tests/rest_push_devices.ts
```

SQL test provjerava i stvarni transportni red u rollback transakciji, pa HTTP poziv ne izlazi
iz testa. Mock FCM testovi dokazuju ponašanje workera, ne Google/APNs isporuku.
