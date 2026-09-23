# accept-staff-invite

Radnik pravi nalog osoblja iz koda poziva (task 45, [ADR-0023](../../../docs/adr/0023-nalog-osoblja-nastaje-iz-koda-poziva.md)).
Postoji jer `auth.admin.createUser` i postavljanje `app_metadata` rade samo sa service role ključem.

## Ugovor

```
POST /functions/v1/accept-staff-invite
apikey: <anon ključ>            (radnik još nema nalog ni token)
{ "code": "ABCDEFGH23", "email": "radnik@…", "password": "…" }
```

| Odgovor | Kad |
|---|---|
| `200 {ok:true, role}` | nalog napravljen, poziv zatvoren |
| `400 {error}` | nedostaje polje, email neispravan, lozinka kraća od 8 |
| `404 {error}` | kod ne postoji, istekao je, povučen ili već iskorišten — **ista poruka** za sve |
| `409 {error}` | email već ima nalog |
| `500` | konfiguracija servera ili neočekivana greška |

Uloga i salon **ne čitaju se iz zahtjeva** — `role` i `salon_id` u tijelu se ignorišu.

## Deploy

```sh
supabase functions deploy accept-staff-invite
```

`verify_jwt` ostaje uključen: aplikacija šalje anon ključ, koji je važeći JWT.
