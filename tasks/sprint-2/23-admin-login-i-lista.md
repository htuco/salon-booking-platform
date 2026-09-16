# Task 23 — Admin: login, dashboard i lista termina

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [12](12-auth-provideri.md), [14](14-identitet-i-klijent-upsert.md) |
| **Blokira** | 24, 25 |
| **Reference** | [01 §12](../../docs/01-mvp-spec.md#12-screens) · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
`apps/admin` prestaje biti skelet. Vlasnik salona vidi šta mu je zakazano — to je druga polovina
proizvoda i do sada ne postoji.

## Definicija gotovog
- [x] Login za osoblje (email + lozinka), odvojen od klijentskog flowa
- [x] `app_metadata.role = salon_admin` **i** red u `public.users` sa istim `salon_id` — oba uslova,
      kako `security.md` traži
- [x] Dashboard: današnji termini, broj `pending` zahtjeva
- [x] Lista termina sa filterom po danu i statusu
- [x] Admin **ne bira salon iz UI-ja** — dobija ga iz svog `users` reda
- [x] Deno test: admin salona A ne čita termine salona B

## Koraci
1. Auth i `users` provjera prije ijednog ekrana
2. Lista pa dashboard — dashboard je sažetak liste, ne obrnuto
3. Commit: `feat(admin): login i lista termina`

## Zamke
- **`x-salon-id` u adminu nije izvor istine.** Header bira kontekst; članstvo dolazi iz `users`
  reda. Admin koji pošalje tuđi header mora dobiti prazan rezultat.
- `apps/admin` je **generička** app, bez flavora — jedan build za sve salone.

## Status (2026-09-14) — ✅ zatvoren

`apps/admin` je prestao biti skelet. Vlasnik se prijavi email-om i lozinkom i vidi šta mu je
zakazano — do sada je sav rad išao u klijentsku app.

### Šta je isporučeno

- **`StaffRepository` + `StaffMember`**, zasebno od klijentskog `AuthRepository`. U trenutku
  isporuke klijentski ugovor je bio pisan za Apple, Google, OTP, gosta i brisanje naloga.
  [ADR-0010](../../docs/adr/0010-email-lozinka-umjesto-otp-a.md) kasnije dodaje password i klijentu,
  ali repozitoriji ostaju odvojeni: admin login mora vratiti i validirati `StaffMember`/salon
  članstvo, dok klijentski login vraća globalni `AuthIdentity` i per-salon `Customer`.
- **`StaffAppointmentRepository`** — dan, raspon, filter po statusu, i `pendingCount` koji **broji u
  bazi**: PostgREST reže na `max_rows`, pa bi povlačenje liste pa brojanje u Dartu dalo tih i
  pogrešan broj kod salona sa mnogo termina.
- **Ekrani:** `/login`, `/appointments` (lista sa filterom po danu i statusu), `/dashboard`
  (današnji termini + brojač zahtjeva). Lista je pisana **prije** dashboarda, kako korak 2 traži.
- **Zaštita ruta** u `admin_router.dart`, sa `refreshListenable` na sesiju.
- **Seed dobija admine i termine** — v. zamke.

### Dokazano

- **Cijela Dart suita: 479 testova PASS** (bilo 462) — `core_api` 91, `core_domain` 74, `core_ui`
  67, **`admin` 16 (novo)**, `client` 231.
- **177 pgTAP** (bilo 176) i **svih šest Deno testova**, 173 asercije.
- **Novi `rest_admin_login.ts`, 14 asercija** — jedini test u repou koji pada ako se u admin app-i
  ne može prijaviti. Provjereno da **stvarno pada**: vraćanjem `confirmation_token` na `NULL`
  prijava puca i poruka uputi na uzrok.
- **Uživo u browseru, protiv živog stacka, oba tenanta.** Prijava → `/dashboard` → lista → filter →
  navigacija po danima. **Izolacija kroz samu aplikaciju:** isti build, prijava drugim vlasnikom
  pokazuje samo Beauty Studio Travnik i nijedan barberov termin.

| provjera (stvarni tokeni, PostgREST) | rezultat |
|---|---|
| admin A vidi termina | **3** |
| admin B vidi termina | **2** |
| admin A filtrira po salonu B | **0** |
| admin A + `x-salon-id` salona B | **3** (ostaje svoj) |
| admin A upisuje u salon B | **403** |
| `anon` bez tokena | **401** (nema ni grant) |

Brojevi su namjerno različiti — da su isti, zamijenjen token bi prošao kroz brojač neprimijećeno.

### Zamke koje su koštale vremena

- **Seed nije imao nijednog admina**, pa se u admin app nije imalo čime prijaviti. Testovi to nisu
  otkrivali: svaki pgTAP fajl pravi svoje korisnike i rollbackuje ih, a claimove glumi kroz
  `set_config` — **fixture nije seed**, i taj put nikad ne prolazi kroz GoTrue.
- **Nullable text kolone u `auth.users` moraju biti prazan string, ne `NULL`.** GoTrue ih skenira u
  Go `string`; `NULL` obara prijavu sa `500 Database error querying schema`, porukom koja ne kaže
  koja je kolona kriva. Red izgleda ispravno u `psql` i cijela SQL suita prolazi. Prva ispravka je
  pogodila šest `*_token` kolona i **i dalje padala** — na `email_change` i `phone_change`, koje ne
  nose „token" u imenu. Riješeno petljom, a ne nabrajanjem u `insert`. Detalji u `security.md`.
- **Izolacija se na praznim tabelama ne može dokazati.** `customers=0, appointments=0` znači da upit
  „admin A ne vidi termine salona B" vraća nula redova i kad RLS radi i kad je isključen. Zato seed
  dobija podatke, i to **različit broj po salonu**.
- **`order()` u postgrest paketu podrazumijeva `descending`**, suprotno od SQL-a. Raspored dana se
  crtao unatraške (11:30 pa 10:00). Widget testovi to nisu mogli uhvatiti — lažne liste su im već
  bile sortirane. **Vidjelo se tek na ekranu.** Isti propust je već bio zabilježen u
  `policy_repository.dart`, pa uz ispravku ide i test koji gađa stvarni URL kroz `MockClient`.
- **`AdminScaffold` je čitao `GoRouterState.of(context)`** da zna aktivnu ćeliju. To veže svaki
  admin ekran za router stablo, pa se lista ne može podići u widget testu bez pravog `GoRouter`-a —
  test koji mora graditi router da bi provjerio listu testira navigaciju, ne listu.
- **`ListTile.leading` nameće djetetu visinu reda**, pa je kolona sa dva reda vremena prelijevala 24
  piksela. Uhvatio widget test.

### Ostalo za sljedećeg

- **`apps/admin` nije pokrenut na mobilnom uređaju** — dokaz je iz Chromea. Layout je responzivan
  (forma ograničena na 400px), ali to nije isto što i provjereno.
- **Lozinka `admin123456` je lokalni demo seed** i ne ide na produkciju; `seed.sql` se izvršava samo
  kroz `supabase db reset` / `supabase start`. Pravi salon dobija nalog kroz poziv iz super admin
  konzole u Sprintu 3.
- **Rute `/calendar`, `/services`, `/employees`, `/working-hours`, `/settings` su i dalje
  placeholderi** i donja navigacija ih namjerno ne nudi. Ćelija koja vodi na placeholder obeća
  funkciju koja ne postoji.
- **Potvrda, odbijanje i ručni termin su [task 24](24-admin-akcije-nad-terminima.md)** — i moraju
  ići kroz `book_appointment`: direktan admin `insert` zaobilazi provjeru preklapanja slotova, što
  `security.md` već vodi kao otvorenu stavku.
