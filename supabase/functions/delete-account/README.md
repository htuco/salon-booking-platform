# delete-account

Drugi korak brisanja naloga (task 17, `docs/06` §8.2). Prva stvarna Edge Function u repou.

Postoji zato što je `auth.admin.deleteUser` admin API: radi samo sa service role ključem, koji
zaobilazi RLS u potpunosti i **nikad ne smije u klijentsku app**.

## Ugovor

```
POST /functions/v1/delete-account
Authorization: Bearer <korisnikov access token>
```

| Odgovor | Kad |
|---|---|
| `200 {ok:true, authUserDeleted:true, details:{...}}` | oba koraka prošla |
| `200 {ok:true, authUserDeleted:false}` | korak 1 prošao, `auth.users` ostao — v. dolje |
| `401 {error:"Nevazeci token"}` | nema tokena ili je neispravan |
| `403 {error:"Brisanje nije uspjelo", code:"42501"}` | pozivalac nije klijent, ili nalog je već obrisan |
| `500` | pogrešna konfiguracija servera, ili neočekivana greška RPC-a |

`details` je izlaz `public.delete_my_account()`: koliko je termina otkazano, koliko termina i
klijentskih redova anonimizirano.

## Zašto tim redom

1. `public.delete_my_account()` — pod **korisnikovim** tokenom;
2. `auth.admin.deleteUser` — pod service role ključem.

Obrnuto bi pad drugog koraka ostavio `customers` red sa punim imenom i telefonom, a korisnikov
token više ne bi postojao — ne bi imao čime ponoviti brisanje.

Korak 1 se namjerno **ne** pokreće pod service role ključem: funkcija izvodi identitet iz
`auth.uid()`, pa bi pod servisnim ključem `auth.uid()` bio `NULL` i poziv bi pao na `42501`.
Sporedna, ali važna posljedica — ova funkcija ne može obrisati tuđi nalog ni kad bi htjela.

## `authUserDeleted: false` nije greška

Ako prvi korak prođe a drugi padne, korisnik dobija `200`. Lični podaci su otišli i nalog je već
neupotrebljiv (`deleted_at` gasi `owns_identity`, sve klijentske politike i `ensure_customer`).
Reći korisniku „brisanje nije uspjelo" bi bilo netačno u svemu što se njega tiče.

Ostaje siroče u `auth.users`, koje se čisti servisno. Dok stoji, prijava istim mailom **ne** pravi
nov nalog: trigger ne uskrsava obrisani red, ali ni novi ne nastaje jer `unique(supabase_user_id)`
stoji. Korisnik bi tada bio prijavljen bez identiteta — `ensure_customer` vraća `42501`, app ga
tretira kao neprijavljenog.

## Šta ovdje 🟡 fali

**Apple token revoke** (`docs/06` §8.2) nije implementiran. Apple prijava ne postoji — task 12 je
🟡 i čeka konzole — pa se revoke ne može ni napisati ni dokazati. Kad Apple prijava uđe, ovdje ide
poziv na `https://appleid.apple.com/auth/revoke`. V.
[`12-konzole-checklist.md`](../../../tasks/sprint-2/12-konzole-checklist.md).

## Lokalno

```bash
supabase functions serve delete-account
deno run --allow-env --allow-net ../tests/rest_delete_account.ts
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` i `SUPABASE_SERVICE_ROLE_KEY` Edge runtime dobija sam na
lokalnom stacku. Ništa od toga ne ide u repo.
