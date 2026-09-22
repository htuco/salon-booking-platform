# Sprint 4 — popravke, pravila i pristup zaposlenih

Sprint 3 je isporučio admin aplikaciju po handoffu. Ovaj sprint plaća račun: ono što je ostalo
pokvareno ili pola-spojeno, pa tek onda Faza 2 — radnik sa vlastitom prijavom.

**Redoslijed je namjeran.** Bugovi idu prvi jer svaki od njih danas laže vlasniku: postavka koja se
ne primjenjuje, ekran koji se ruši, obavijest koja ne stiže. Nema smisla graditi pristup zaposlenih
nad aplikacijom u koju vlasnik nema povjerenja.

| # | Task | Vrsta | Blokira | Procjena |
|---|---|---|---|---|
| [37](37-automatsko-potvrdjivanje.md) 🟡 | Automatsko potvrđivanje termina | bug | — | 0,5–1 dan |
| [38](38-crash-radno-vrijeme.md) | Crash pri izmjeni radnog vremena | bug | 42 | 1 dan |
| [39](39-push-na-androidu.md) | Push obavijesti na Androidu | bug | 42 | 1–2 dana |
| [40](40-naziv-lokala-se-ne-mijenja.md) | Naziv lokala se ne mijenja iz admina | popravka | — | 0,5 dan |
| [41](41-bez-zakazivanja-bez-prijave.md) | Zakazivanje bez prijave se uklanja | popravka | — | 1 dan |
| [42](42-neradni-dan-i-zakljucana-proslost.md) | Neradni dan i zaključana prošlost | feature | — | 2–3 dana |
| [43](43-korak-po-usluzi.md) | Korak rezervacije po usluzi | feature | — | 1–2 dana |
| [44](44-postavke-jasnije.md) | Postavke i pravila salona jasnija | feature | — | 1–2 dana |
| [45](45-nalozi-za-osoblje.md) | Kreiranje naloga za osoblje | feature | 46, 47 | 2–3 dana |
| [46](46-uloga-employee-i-izolacija.md) | Uloga `employee` i sužena izolacija | feature | 47 | 2–3 dana |
| [47](47-admin-ljuska-za-radnika.md) | Admin ljuska za radnika | feature | — | 1–2 dana |

Ukupno 13–19 dana. **To je više nego jedan sprint** i tako je i planirano: 37–41 su obavezni,
42–44 idu ako ostane vremena, a 45–47 su cjelina koja se ne cijepa — nalog bez uloge i uloga bez
ljuske ne daju ništa upotrebljivo.

## Šta ovaj sprint **ne** zatvara

**Slike i galerija.** `storage.buckets` je prazan — Storage nije postavljen, pa „slike se ne mogu
uploadovati" nije kvar nego podsistem koji fali: bucket, politike po salonu, upload iz admina,
brisanje zamijenjenih fajlova i galerija radova. Odluka o obliku je donesena unaprijed
([ADR-0015](../../docs/adr/0015-slike-idu-u-supabase-storage-javni-bucket.md)) da Sprint 5 ne počne
od rasprave, ali sam posao je Sprint 5.

**iOS push.** Traži Apple developer nalog. Task 39 zatvara Android; iOS ostaje imenovan dug.

## Odluke donesene prije koda

| Odluka | ADR |
|---|---|
| Radnik dobija **sužen** pristup svojim terminima, ne umanjenu admin ulogu | [ADR-0013](../../docs/adr/0013-radnik-dobija-suzen-pristup-svojim-terminima.md) |
| Korak rezervacije je po usluzi, uz salonski kao podrazumijevani | [ADR-0014](../../docs/adr/0014-korak-rezervacije-je-po-usluzi.md) |
| Slike idu u Supabase Storage, javni bucket sa upisom po salonu | [ADR-0015](../../docs/adr/0015-slike-idu-u-supabase-storage-javni-bucket.md) |

## Status

Sprint otvoren 2026-09-22.

### 37 — Automatsko potvrđivanje termina 🟡

U toku od 2026-09-22, grana `fix/automatsko-potvrdjivanje`.
