# Task 51 — Čišćenje bucketa i prijava neprikladnog sadržaja

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [48](48-storage-bucket-po-salonu.md) |
| **Blokira** | — |
| **Reference** | ADR-0015 §Posljedice |

## Cilj
Bucket ne raste zauvijek, a aplikacija ispunjava zahtjev store reviewa za sadržaj koji objavljuje salon.

## Definicija gotovog
- [x] Zamijenjena ili obrisana slika nestaje iz bucketa (u istoj operaciji ili periodičnim čišćenjem siročadi)
- [x] Brisanje usluge, radnika ili slike iz galerije briše i fajl — deaktivirana usluga/radnik namjerno čuva sliku (ADR-0024); fajl nestaje kad se slika zamijeni ili ukloni
- [x] Klijent može prijaviti neprikladnu sliku iz galerije; prijava stiže platformi, ne salonu
- [x] Test: fajl bez reference nestaje; fajl sa referencom ostaje
- [x] Uživo: zamjena slike ostavlja jedan fajl u bucketu, ne dva

## Zamke
- Čišćenje koje briše po putanji mora ostati unutar `salon_id` prefiksa — greška ovdje briše tuđe slike.
- Prijava sadržaja je zahtjev za store, ne feature za salon. Kome stiže i ko odlučuje treba zapisati.

## Status (2026-09-29)

✅ DoD ispunjen. Mergan kao [PR #116](https://github.com/htuco/salon-booking-platform/pull/116).

**Na hostovanom projektu:**
- Migracija `20260927100000` je tu (`supabase migration list`: local = remote).
- `cron.job` ima `cleanup-media` (`17 * * * *`) i `notify-content-reports` (`* * * * *`), oba aktivna.
- `cleanup-media` i `notify-content-reports` su deployane, `ACTIVE`, v1, `verify_jwt=false`.

- Tajne `MEDIA_CLEANUP_SECRET` i `CONTENT_REPORT_WORKER_SECRET` su postavljene, a u Vaultu su
  sva četiri reda (`media_cleanup_*`, `content_report_worker_*`).
- **Sweep radi na produkciji:** `select private.call_worker('cleanup-media')`, pa
  `net._http_response` → `200 {"removed":0,"rejected":0,"failed_salons":0}`. Siročadi starije od
  24h trenutno nema.

**Čeka vlasnika projekta:** `REPORT_WEBHOOK_URL` (Slack webhook, ili Discord sa `/slack`).
Bez njega `notify-content-reports` ne uzima nijednu prijavu, pa prijave čekaju u
`content_reports` i ništa se ne gubi. Kad se postavi, probna prijava mora stići u kanal, pa
`status = 'dismissed'` (korak 4 niže). Tek tada se task zatvara.

### Status (2026-09-28)

✅ DoD ispunjen: backend dokazan lokalno i na CI-ju, oba ekrana viđena uživo. Grana
`feat/ciscenje-bucketa-i-prijava`, [PR #116](https://github.com/htuco/salon-booking-platform/pull/116).

**Dokazano uživo (2026-09-28, mašina sa Dockerom i Flutterom 3.47.0):**
- `./tool/test_supabase.sh` (sa `db reset`): `Files=24, Tests=716, Result: PASS`, svi REST
  testovi zeleni (`rest_ciscenje: 28 provjera prolazi`), `deno test` oba handlera `9 passed`.
- Klijent, Vitez, web build protiv lokalnog stacka, 402×874: Galerija → slika → zastavica.
  - Gost dobija dijalog „Prijavite se da prijavite sliku"; nakon prijave emailom vraća se na `/gallery`.
  - Prijavljen klijent dobija sheet „Šta nije u redu sa slikom?" sa četiri razloga; izbor daje
    snackbar „Hvala. Prijava je poslana i pregledaćemo je."
  - Red u bazi: `content_reports` → salon Vitez, URL prve slike, `Uvredljivo ili nasilno`, `open`.
- Admin, Vitez, 1440×900: Postavke → Naslovna → „Zamijeni sliku" dva puta.
  - U bucketu su dva `cover/*.png`, a `salons.cover_image_url` pokazuje na drugi.
  - `media_orphans('0 seconds')` vraća samo prvi.
  - Stvaran `cleanup-media` handler kroz Storage API: `200 {"removed":1,"rejected":0,"failed_salons":0}`.
  - U bucketu ostaje **jedan** fajl: novi cover javno vraća 200, stari 400.

**Nije viđeno:** poruka `PT400` („Slika više ne postoji…") u admin formi, jer traži objekat
obrisan dok je forma otvorena; pokrivena je widget testom i pgTAP-om. U headless Chromeu CanvasKit
poslije navigacije crta slike crno (`texImage2D: no image`). Isto se dešava i sa slikama usluga i
tima koje ovaj task ne dira, pa to nije regresija.

### Status (2026-09-27)

🟡 Backend i klijent napisani, backend dokazan lokalno i na CI-ju, klijent dokazan widget
testovima na CI-ju. **Čeka živu provjeru u browseru i deploy na hostovani projekat.** Grana
`feat/ciscenje-bucketa-i-prijava`, draft [PR #116](https://github.com/htuco/salon-booking-platform/pull/116).

**Odluke** ([ADR-0024](../../docs/adr/0024-siroce-u-bucketu-cisti-periodicni-sweep-prijava-ide-platformi.md)):
periodični sweep (`cleanup-media`, pg_cron svaki sat, prag 24h) umjesto brisanja iz admina;
deaktivirana usluga/radnik čuva sliku; prijavu šalje samo prijavljen klijent, ide u
`content_reports` koju čita samo `super_admin`, platforma saznaje kroz webhook
(`notify-content-reports`); prijavljena slika ostaje vidljiva dok platforma ne odluči.
Kome stiže i ko odlučuje (zamka iz ovog taska) je zapisano u ADR-u i u
`.claude/docs/workflows.md` → „Prijava slike — šta platforma radi“.

**Dokazano:**
- `supabase test db` (CLI 2.117.0, poslije `db reset`): `Files=24, Tests=716, PASS`; `024` ima
  45 asercija. Mutacije obaraju: bez bucket filtera 2, bez filtera malih slova 3, bez filtera `.`
  segmenta 2, bez triggera postojanja 4, bez provjere `x-salon-id` 1, široka SELECT politika 3,
  politika samo nad JWT claimom 1, bez dnevnog limita 1, bez reference iz `employees` 1.
- `rest_ciscenje.ts`: 28 provjera. Stvaran `cleanup-media` handler kroz Storage API: zamijenjen
  cover i upload bez reference nestaju, cover sa referencom ostaje javno čitljiv, **u folderu
  ostaje jedan fajl, ne dva**. Prijava kroz PostgREST; vlasnik i klijent je ne vide.
- Svih 15 REST testova iz CI-ja lokalno zeleno; `deno test` oba nova handlera 9 passed
  (uključujući escapovanje razloga za Slack/Discord).
- CI na `82850d2`: `Supabase tests` success (run 36312984037); `Flutter` → `dart analyze` „No
  issues found!", client 397 passed (sva četiri nova testa `prijava slike`), admin 470, core_api
  140 (run 36312984031). Isto zeleno i na zadnjem commitu grane `e04e84b` (runovi 36313234971 i
  36313234973).
- `rls-auditor` nije našao curenje između salona; njegova četiri srednja nalaza (brisanje žive
  slike pri formi otvorenoj >1h, zastoj sweepa na UUID-u velikim slovima, neescapovan razlog u
  webhooku, spam prijava) ispravljena u `7ba773d`.

**Napisano, nije dokazano:**
- **Ekran nije viđen.** Na mašini koja je pisala task nema Flutter SDK-a: dugme „Prijavi sliku"
  u lightboxu, dijalog za neprijavljenog, sheet sa razlozima i snackbar postoje samo kroz widget
  testove. Isto važi za poruku `PT400` („Slika više ne postoji — izaberite je ponovo") u
  admin formi.
- **Webhook nije okinut uživo** — traži `REPORT_WEBHOOK_URL` koji ima samo vlasnik projekta.
- **Hostovani projekat nema ni migraciju ni funkcije.**

**Ostalo za sljedećeg:**

Koraci 1 i 2 traže **Docker i Flutter na istoj mašini**. Bez Dockera: spoji PR, uradi korak 3
(`db push` i deploy), pa korake 1–2 pokreni protiv hostovanog projekta (`tool/run_tenant.sh vitez
-d chrome` sa hostovanim defineovima, `.claude/docs/workflows.md` → „Hostovani Vitez demo").

1. Uživo, lokalno: `supabase start` pa klijent na Vitezu (`tool/run_tenant.sh vitez -d chrome`,
   `.claude/docs/workflows.md`) → Galerija → slika → zastavica: gost dobija dijalog i vraća se
   na galeriju nakon prijave; prijavljen klijent bira razlog i dobija „Hvala…". Red provjeriti:
   `select * from content_reports` (service role / Studio).
2. Uživo, admin: zamijeni cover ili sliku usluge, pa
   `select name from public.media_orphans(interval '0 seconds')` vraća staru, ne novu. Posljednji
   DoD checkbox se čekira tek kad se u bucketu vidi jedan fajl (sweep lokalno okidaš handlerom
   kao u `rest_ciscenje.ts` ili `supabase functions serve cleanup-media`).
3. Poslije merge-a: `supabase db push`, `supabase functions deploy cleanup-media` i
   `notify-content-reports`, tajne i Vault redovi po `.claude/docs/workflows.md` → „Workeri taska
   51". Provjera: `select private.call_worker('cleanup-media');` pa `net._http_response` → 200.
4. Probna prijava na hostovanom → poruka stiže u kanal → `status = 'dismissed'`.

**Zamke:**
- Sheet „Šta nije u redu sa slikom?" je napravljen **bez nacrta**. Beauty handoff (draft
  PR #117, `prototype/beauty/`, ekran `2a`) ga sada crta: četiri razloga, napomena i
  dugme „Odustani", kojeg klijentski sheet nema (zatvara se prevlačenjem ili dodirom van njega).
  Uskladiti pri živoj provjeri ili u tasku 52.
- Direktan `delete from storage.objects` blokira `storage.protect_delete`; brisanje samo kroz
  Storage API. pgTAP koji briše objekte treba `set local storage.allow_delete_query = 'true'`.
- Nova slikovna kolona mora ući u `media_orphans` **i** u trigger `guard_salon_media_reference`,
  inače sweep briše njene fajlove dan nakon uploada (zapisano i u `security.md`).
- Test koji snima `salon-media` URL mora imati i objekat iza njega (v. fixture u `023`).
- Supabase CLI i Deno nisu morali biti instalirani: `npx -y supabase@2.117.0 …` i
  `npx -y deno@2 …` rade isto što i CI.

**Otvoreno pitanje:** nijedno — odluke su u ADR-0024.
