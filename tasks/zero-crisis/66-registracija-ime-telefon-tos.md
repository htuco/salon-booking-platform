# Task 66 — Registracija: ime, telefon i uslovi u jednoj formi

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | — |
| **Blokira** | [58](58-kontakt-jednim-tapom.md), [67](67-pisanje-recenzija.md), [81](81-potvrda-emaila-kodom.md), [82](82-izmjena-profila-klijenta.md), [84](84-apple-google-prijava.md), [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · `docs/research/auth-krajnji-korisnik.md` §1, §7 · `docs/06` §3.1 (više ne važi) |

## Cilj
Salon zna ko mu dolazi. Danas je svaki email klijent u Meluri „Klijent / Bez broja", jer forma ima
samo email i lozinku, a `ensure_customer` pada na `'Klijent'`.

## Definicija gotovog
- [x] Forma registracije: **ime i prezime, telefon, email, lozinka** (jednom, sa „prikaži lozinku").
      Otvara se na **registraciji**; „Već imate račun? Prijavite se" je sekundarno
- [x] Telefon bez SMS verifikacije; kratko objašnjenje ispod polja zašto ga salon treba
- [x] **Checkbox** „Prihvatam Uslove korištenja i Politiku privatnosti" sa linkovima na oba dokumenta;
      prazan po defaultu, bez njega dugme za registraciju nije aktivno. Isti checkbox na „Dopuni profil"
      poslije prve Apple/Google prijave
- [x] Prihvatanje se bilježi: verzija oba dokumenta + vrijeme, na identitetu (migracija); nova verzija
      uslova traži ponovno prihvatanje pri sljedećoj prijavi
- [x] Ime i telefon idu u auth metapodatke → `auth_identities` → `customers` **svakog** salona tog
      korisnika; postojeći „Klijent" redovi se osvježe
- [x] Melura prikazuje ime i telefon (lista klijenata, detalj termina)
- [x] Mapirani `user_already_exists` i `weak_password`; forma prijave ne provjerava pravila registracije;
      uklonjen demo tekst „ne šaljemo email potvrdu"
- [x] `docs/06` §3.1 prepisan; `security.md` za novu kolonu; Data safety bilješka
- [x] Widget testovi forme; pgTAP za osvježavanje imena po salonima (bez curenja u tuđi salon)

## Zamke
- `on conflict do nothing` u `ensure_customer` — bez izmjene postojeći klijenti zauvijek ostaju „Klijent".
- Ime i telefon su **po identitetu**, a `customers` je **po salonu**: salon A ne smije vidjeti da
  isti čovjek ide i u salon B (`docs/06` §4.3).

## Status

### U toku — kod gotov, čeka CI, merge i deploy (2026-10-13)

Grana `feat/registracija-profil`, [PR #136](https://github.com/htuco/salon-booking-platform/pull/136).
Odluke: [ADR-0030](../../docs/adr/0030-verzija-uslova-i-profil-popunjava-adresar.md) —
eksplicitna verzija uslova (`public.legal_versions()`, podiže se migracijom), a profil adresar
salona samo popunjava („Klijent"/prazno ime, prazan telefon).

**Dokaz:**

```
./tool/test_supabase.sh
.../030_registracija_profil.test.sql ... ok
Files=30, Tests=880   Result: PASS      (+ svi REST i Deno testovi)
dart run melos run test
core_domain +97 · core_api +144 · core_ui +145 · client +661 ~1 · admin +577  All tests passed!
melos run analyze: No issues found (5/5) · dart format --set-exit-if-changed: OK
tenant_theme_test (Vitez, Travnik): +20 · gen_flavors --check: ažurni
```

Pet mutacija SQL-a obara `030`: prepisivanje uvijek (15–16), prihvatanje na prijavi (5–6), bez
provjere sudara telefona (17), bez filtera identiteta (10–11), brisanje ostavlja telefon (30).
U Dartu: login bez provjere profila obara sva tri testa „Dopuni profil".

**Uživo** (web 402 px protiv lokalnog Supabasea, Vitez):
- registracija „Lejla Testić / 061 555 777" → `auth_identities`: ime, telefon onako kako je
  napisan, verzija 1/1; `ensure_customer` sa njenim tokenom → red u Vitezu sa imenom i telefonom;
  **Melura (1440) u Klijentima prikazuje „Lejla Testić · 061 555 777"**. Detalj termina nije
  otvaran uživo: termin zakazan kao „Klijent" dobija ime i telefon u `appointments` (pgTAP `030`),
  a detalj čita baš te kolone (`customerName`, `customerPhone`);
- nalog bez metapodataka (kao Apple/Google) → prijava vodi na „Dopuni profil" (ime, telefon,
  checkbox) → identitet dobija sve tri stvari, app se vraća na `from`;
- linkovi uz checkbox otvaraju Pravila korištenja; „Prihvatam" i „i" su isključeni iz semantike
  (prvi prolaz ih je pokazao kao dva lažna dugmeta).

**Dorada poslije pregleda uživo (Hamza, 2026-10-14):**
- telefon dobija izbor pozivnog broja (podrazumijevano +387, region i dijaspora); broj se kuca
  lokalno, polje ne pušta slova, vodeća nula otpada → „+387 61 123 456";
- stroži regex za email (`isValidEmail`: „ana@gmail", „ana@@x.ba", „ana@gmail..com" padaju prije
  mreže);
- ekran potvrde rezervacije: fotografija usluge (pa cover salona) umjesto gradijenta, a vrijednosti,
  badge i datum poravnati uz desni rub. Uzrok „stepenastog" teksta je bio `SpecCard` u `core_ui`
  (`Flexible` vrijednost stajala je na početku desne polovine); novi `spec_card_test` pada na starom
  kodu (257 px umjesto 339).

Dokaz: core_domain +105, core_ui +146, client +662, admin +577; analyze i format čisti. Viđeno
uživo u Chromeu (Vitez, lokalni Supabase): slika Fade/Brada na potvrdi, poravnata kartica.

**Ostalo za sljedećeg:**
- **Deploy (Hamza):** `supabase db push` (migracija `20261013160000_registracija_profil`).
  Provjera: `select * from public.legal_versions()` → `1, 1`. Migracija na kraju popuni postojeće
  „Klijent" redove imenom iz identiteta (Google/Apple korisnici).
- „Dopuni profil" poslije **prave** Apple i Google prijave na uređaju — lokalno je odigran nalogom
  bez metapodataka, isti put kroz `client_profile_status`.
- Potvrda emaila je isključena na hostovanom; sa uključenom potvrdom registracija pokazuje „račun
  čeka potvrdu" dok ne dođe ekran za kod (task 81).
- Data safety i App Privacy formulari se popunjavaju po bilješci u `docs/06` §8.3 kod submissiona
  (task 90).
