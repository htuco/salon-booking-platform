# Nalog osoblja nastaje iz koda poziva, ne iz emaila

## Status

prihvaćen

## Kontekst

Do taska 45 nije postojao nijedan način da nastane nalog osoblja — oba seed admina su upisana
ručno u SQL-u. Faza 2 (radnik sa vlastitom prijavom, ADR-0013) nema ulaza bez toga.

Dvije činjenice su odlučile oblik:

- Hostovani projekat nema vlastiti SMTP. Ugrađeni Supabase mailer odbija slanje poslije dva
  emaila na sat, što je već viđeno na `signup`-u. Tok koji zavisi od emaila puca na prvom salonu
  sa tri radnika.
- Vlasnik salona ne treba da se „pegla": najmanje koraka, bez kucanja tuđeg emaila i bez
  poznavanja tuđe lozinke. Poruke radnicima već šalje Viberom ili WhatsAppom.

`app_metadata.role` i `app_metadata.salon_id` može postaviti samo server sa service role ključem,
a `private.is_admin()` traži i taj claim i red u `public.users`. Oboje mora nastati zajedno.

## Odluka

Vlasnik u Postavkama → „Pristup" napravi poziv: ime i uloga (`employee` ili `salon_admin`).
`create_staff_invite` vrati kod od 10 znakova i sačuva **samo njegov sha256**. Vlasnik kopira
gotovu poruku (kod, a na webu i link `/pozivnica?kod=…`) i pošalje je kako hoće.

Radnik na `/pozivnica` unese kod, svoj email i lozinku. Edge Function `accept-staff-invite`, pod
service role ključem:

1. `peek_staff_invite` — je li poziv živ, koju ulogu i salon nosi;
2. `auth.admin.createUser` sa potvrđenim emailom i `app_metadata` **iz poziva**;
3. `accept_staff_invite` — `public.users` red i zatvaranje poziva u jednoj transakciji, uz
   `for update`; ako padne, `auth.users` red iz koraka 2 se briše.

Poziv važi 7 dana i vlasnik ga može povući. Uloga iz poziva je zatvorena lista, `super_admin`
isključuju i RPC i `check` na tabeli. Uklanjanje člana (`remove_staff_user`) briše samo red u
`public.users`: pristup prestaje od sljedećeg zahtjeva, termini i istorija ostaju.

## Razmatrane opcije

- **Supabase `inviteUserByEmail`** — odbačeno za sada: traži pravi SMTP na hostovanom projektu, a
  bez njega puca poslije dva emaila na sat. Vraća se na sto kad projekat dobije SMTP; kod i tada
  ostaje kao rezerva.
- **Vlasnik postavi privremenu lozinku** — odbačeno: vlasnik zna radnikovu lozinku, a istek i
  povlačenje poziva nemaju šta da znače.
- **Politika „admin vidi osoblje" nad `public.users`** — odbačeno: `StaffRepository.membership()`
  čita tu tabelu bez filtera i očekuje tačno jedan red. Lista osoblja zato ide kroz
  `list_staff_users`.

## Posljedice

- Kod se prikazuje **jednom**. Izgubljen kod se ne može ponovo pročitati — poziv se povlači i
  pravi novi. To izgleda kao nedostatak, a zapravo je posljedica čuvanja hasha.
- Email koji već ima nalog (npr. klijentski) ne može postati nalog osoblja; radnik dobija 409 i
  upisuje drugi email. Spajanje uloga nad istom prijavom bi klijentu tiho dalo prava osoblja.
- Radnik (`employee`) nakon poziva ima nalog, ali ga router ne pušta dalje od prijave dok ga
  taskovi 46 i 47 ne otvore. Ekran poziva to kaže umjesto da ćuti.
- REST test (`rest_pozivi_osoblja.ts`) traži aktivan edge runtime, pa ide lokalno kroz
  `tool/test_supabase.sh`; CI Edge Functions ne pokreće.
