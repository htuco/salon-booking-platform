# Task 17 — Client: "Moj račun", postavke i **brisanje računa**

| | |
|---|---|
| **Procjena** | ~~1–2 dana~~ → **2–3 dana** (v. „Doseg", 5k je ušao) |
| **Zavisi od** | [13](13-client-login-ekran.md) |
| **Blokira** | **store submission** |
| **Reference** | `prototype/ui/SPEC.md` 5k · [06 §8](../../docs/06-auth-login-flow.md) · [01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 16 |

## Cilj
Ekran računa sa odjavom i **brisanjem naloga**. Bez brisanja iOS submission pada — to nije feature
nego uslov izlaska u store.

## Definicija gotovog
- [x] `/settings` po handoffu 5k: profil, obavijesti, jezik, o aplikaciji, odjava, i red
      „Moj račun ›" — **ovo je jedini ulaz do `/account`**
- [x] `/account`: podaci identiteta i brisanje naloga
- [x] **Brisanje računa** briše `auth_identity` i anonimizira `customers` red, ne briše termine
      koje salon treba za evidenciju
- [x] Brisanje traži potvrdu i **objašnjava šta ostaje**, ne samo "jeste li sigurni"
- [x] Nakon brisanja app se vraća u javno stanje, bez zaostalog tokena
- [x] Deno test: obrisan identitet više ne može čitati svoje termine

## Doseg — odluka od 2026-09-13

**`/settings` (5k) je ušao u ovaj task.** Kako je task prvobitno napisan, 5k je bio siroče: ovdje
je stajao kao referenca za `/account`, ali 5k i `/account` su dva ekrana — router iz
[taska 18](18-pocetna-i-tab-bar.md) ih razdvaja. Komentar u `app_router.dart` ga je pripisao
[tasku 21](21-obavijesti-i-pravni-ekrani.md), čiji DoD nabraja samo `/notifications`, `/about-app`
i `/terms`.

Bez 5k `/account` se ne može otvoriti iz aplikacije. Ekran za brisanje naloga do kojeg se ne može
doći pada na Apple reviewu — a to je jedini razlog zašto ovaj task postoji. 5k uz to već nosi
„odjavu" koju DoD ionako traži.

## Koraci
1. RPC za brisanje (soft-delete klijenta + hard-delete identiteta)
2. Edge Function koja zove RPC pa `auth.admin.deleteUser` — tim redom, obrnuto ostavlja siroče
3. `/settings` (5k), pa `/account` ispod njega
4. Commit: `feat(client): postavke, moj racun i brisanje naloga`

## Zamke
- **Brisanje naloga ≠ brisanje podataka salona.** Termin je i salonov zapis; anonimizuje se ime i
  kontakt, ne briše se red.
- Apple traži da brisanje bude **u aplikaciji**, ne link na mail podrške.

## Status (2026-09-14) — ✅ zatvoren, uz jednu 🟡 stavku

Brisanje je **dvokoračno**: `public.delete_my_account()` pod korisnikovim tokenom, pa Edge
Function `delete-account` sa `auth.admin.deleteUser` pod service role ključem. Tim redom — obrnuto
bi pad drugog koraka ostavio `customers` red sa punim imenom, a korisnikov token više ne bi
postojao, pa ne bi imao čime ponoviti brisanje.

**Nalaz koji task fajl nije imao, i bez kojeg je ovo bilo pozorište:** `appointments` nosi
`customer_name`, `customer_phone` i `customer_note` kao **vlastite kolone**, ne samo `customer_id`.
Anonimizacija samo nad `customers` ostavlja puno ime u svakom terminu tog čovjeka. `docs/06` §8.2
to i traži doslovno („čuvanje `Appointment` zapisa **bez ličnih podataka**") — bio je propust u
prenosu u task fajl, ne nova odluka.

**Druga odluka koja se ne vidi iz koda:** ovo je jedini upis u repou koji namjerno prelazi granicu
salona. Isti čovjek može biti klijent u više salona (task 15), a brisanje naloga je odluka o
**osobi** — salon-scoped verzija bi obrisala ime u jednom salonu i ostavila ga u drugom, bez
ijednog ekrana s kojeg bi korisnik to mogao ponoviti. `x-salon-id` se zato namjerno **ne traži**.

**5k je ušao u ovaj task** jer `/account` bez njega nema ulaz iz aplikacije. Komentar u
`app_router.dart` ga je pripisivao tasku 21, čiji DoD nabraja samo `/notifications`, `/about-app` i
`/terms`. Ispravljeno; `/about-app` i `/terms` su usput dodani i u tabelu `docs/01 §12`, koja ih
nije imala.

### Dokazano

| Šta | Kako |
|---|---|
| Logika u bazi | **124 pgTAP testa** (bilo 97) |
| Cijeli put kroz HTTP | **33 asercije** u `rest_delete_account.ts`, pravi JWT, prava Edge Function, oba salona |
| Ekrani | **372 Dart testa** (bilo 363), od toga 11 novih |
| Stvarna app | Chromium protiv žive baze: prijava OTP-om → Postavke → dijalog → brisanje |

Nakon brisanja, provjereno u bazi servisnim ključem: `deleted_at` upisan, `email` i `display_name`
`NULL`, `supabase_user_id` pao na `NULL` (FK `on delete set null` — dakle `auth.users` red je
stvarno obrisan), nula preostalih `auth.users` redova, app u javnom stanju.

**Oba testa su provjerena da mogu pasti** — uklanjanje anonimizacije termina obori tri pgTAP
asercije, preskakanje drugog koraka obori Deno test.

### Tri zatečena testa koja su bila zelena samo u dijelu dana

Nađena pokretanjem, ne čitanjem. Nijedan se nije vidio jer je CI blokiran, pa suitu niko nije
pokrenuo van jednog doba dana.

| Test | Padao | Uzrok |
|---|---|---|
| `004_cancel_appointment` | poslije 09:30 | pomjerao `start_time`, ostavljao `end_time` → `check(end_time > start_time)` obori **cijeli fajl** |
| `002_availability` | svakog ponedjeljka | `mon - 7` je početak *tekuće* sedmice, dakle ponedjeljkom danas |
| `rest_public_catalog` | od `e431229` | tražio uslugu bez fotografije u barberu, a taj commit je barberu dao sve fotografije |

Sva tri popravljena tako da ne zavise od trenutka pokretanja. Obrazac zapisan u `security.md`.

### Ostalo za sljedećeg

- 🟡 **Apple token revoke** (`docs/06` §8.2) — nije napisan ni dokazan, jer Apple prijava ne
  postoji. Mjesto u kodu je označeno u `supabase/functions/delete-account/index.ts`. Otključava ga
  [task 12](12-konzole-checklist.md).
- **Sesija ne preživi reload na webu.** Primijećeno pri dokazivanju; web nije ciljna platforma
  (`docs/01`: iOS i Android), pa nije istraživano. Ako web ikad postane cilj, ovo je prvo mjesto.
- **Odjava nakon brisanja vraća 403** jer je `auth.users` red već obrisan. Greška se namjerno guta
  u `SupabaseAuthRepository.deleteAccount()` — v. komentar tamo.
- **Push vlasniku salona o otkazanim terminima** je [task 25](25-push-notifikacije.md), ne ovaj.
