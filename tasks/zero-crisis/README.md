# Zero crisis — kraj featurea i produkcija do lansiranja

Sve što mora postojati prije nego Authentic, Amko i sljedeći saloni dobiju aplikaciju iz storea.
Opseg je odluka vlasnika proizvoda od 2026-10-12, zapisana u
[ADR-0029](../../docs/adr/0029-opseg-do-lansiranja-zero-crisis.md). **Kad je ovaj folder prazan,
nema novih featurea do lansiranja.**

Auth dio (66, 81, 82, 84) se oslanja na istraživanje
[`docs/research/auth-krajnji-korisnik.md`](../../docs/research/auth-krajnji-korisnik.md).
Van opsega (ADR-0029): javni web link i QR, 2FA, SMS, datum rođenja, plaćanje u aplikaciji.

**Brojevi prate redoslijed.** Task zavisi samo od taskova sa manjim brojem. Izuzeci su 56–58, koji su
došli iz Sprinta 5 sa svojim brojevima, i dva taska iz [`polishing/`](../polishing/): 54 (prije 71) i
60 (regresija, prije 89).

**Produkcija polazi od nule** (73–80): u kodu i okruženju nema nijednog produkcijskog ključa ni
naloga. Sve razvojno (`.env.live`, današnji hostovani projekat, lični Apple tim) se rotira i ne ide dalje.

**Ko šta uzima:** [`RASPODJELA.md`](../RASPODJELA.md) — faze A i C i 87 su tima; 73–80, 85, 86 i 88–90 su Hamzini.

## Faza A — funkcije, bez ijednog naloga

| # | Task | Zavisi od | Procjena |
|---|---|---|---|
| [64](64-istek-neodgovorenih-zahtjeva.md) | Istek neodgovorenih zahtjeva 🟡 | — | 1 dan |
| [65](65-limit-otvorenih-zahtjeva.md) | Limit otvorenih zahtjeva po klijentu (spam) | — | 0,5 dana |
| [56](56-podsjetnici-d1-h3.md) | Push podsjetnici D-1 i H-3 | — | 2 dana |
| [66](66-registracija-ime-telefon-tos.md) | Registracija: ime, telefon i uslovi (checkbox) | — | 2 dana |
| [58](58-kontakt-jednim-tapom.md) | Kontakt klijenta jednim tapom | 66 | 0,5–1 dan |
| [67](67-pisanje-recenzija.md) | Pisanje recenzija | 66 | 2–3 dana |
| [68](68-lista-cekanja.md) | Lista čekanja | 64 | 3–4 dana |
| [69](69-sedmicni-kalendar.md) | Sedmični kalendar u Meluri 🟡 | — | 2–3 dana |
| [70](70-istorija-obavijesti.md) | Istorija obavijesti u klijentskoj app-i | — | 1 dan |
| [71](71-melura-za-svakoga.md) | Melura za svakoga: sve radi i jasno je | 54 | 3–4 dana |
| [72](72-super-admin-lokalno.md) | Super admin konzola, lokalna i minimalna | — | 4–5 dana |

## Faza B — produkcija od nule

| # | Task | Zavisi od | Procjena |
|---|---|---|---|
| [73](73-nalozi-i-vlasnistvo.md) | Produkcijski nalozi i vlasništvo | registrovana firma | 1–2 dana + verifikacije |
| [74](74-domena-dns-email-hosting.md) | Domena, DNS, email podrške i javne stranice | 73 | 1 dan |
| [75](75-id-evi-aplikacija.md) | ID-evi aplikacija na pravoj domeni | 74 | 1–2 dana |
| [76](76-supabase-produkcija-i-staging.md) | Supabase: produkcija i staging od nule | 73, 74 | 2 dana |
| [77](77-apple-developer-produkcija.md) | Apple Developer i App Store Connect od nule | 73, 74, 75 | 2 dana |
| [78](78-google-play-i-cloud.md) | Google Play i Google Cloud od nule | 73, 74, 75 | 1–2 dana |
| [79](79-firebase-produkcija.md) | Firebase: push i Crashlytics od nule | 73, 75, 77 | 1–2 dana |
| [80](80-tajne-i-ci-okruzenja.md) | Tajne, rotacija i CI okruženja | 76–79 | 1–2 dana |

## Faza C — funkcije na produkcijskoj infrastrukturi

| # | Task | Zavisi od | Procjena |
|---|---|---|---|
| [81](81-potvrda-emaila-kodom.md) | Potvrda emaila kodom (Resend) | 66, 74, 76 | 2–3 dana |
| [57](57-reset-lozinke.md) | Povratak zaboravljene lozinke | 81 | 1–2 dana |
| [82](82-izmjena-profila-klijenta.md) | Izmjena profila klijenta | 66, 81 | 1–2 dana |
| [83](83-crashlytics.md) | Firebase Crashlytics | 79 | 0,5–1 dan |
| [84](84-apple-google-prijava.md) | Apple i Google prijava do kraja | 66, 75, 77, 78 | 2 dana |

## Faza D — pred lansiranje

| # | Task | Zavisi od | Procjena |
|---|---|---|---|
| [85](85-kapacitet-i-opterecenje.md) | Kapacitet i test opterećenja | 76, 81 | 2 dana |
| [86](86-backup-nadzor-alarmi.md) | Backup, oporavak, nadzor i alarmi | 76, 79 | 1–2 dana |
| [87](87-sigurnosni-pregled.md) | Sigurnosni pregled prije lansiranja | 64–72, 76, 81–84 | 2 dana |
| [88](88-pravno-i-podrska.md) | Pravni dokumenti, podrška i incidenti | tekstovi | 1–2 dana |
| [60](../polishing/60-regresija-i-testiranje.md) | Regresija i testiranje (iz `polishing/`) | 71, 87 | 2–3 dana |
| [89](89-prelazak-na-produkciju.md) | Prelazak pravih salona na produkciju | 75–88, 60 | 1–2 dana |
| [90](90-release-i-store.md) | Release i prva objava | 77, 78, 80, 83, 88, 89 | 3–4 dana |

Ukupno ~50–65 dana rada, bez čekanja verifikacija naloga i store reviewa.

## Kako se faze preklapaju

Faze A i B idu **paralelno od prvog dana**. B je većinom čekanje: verifikacija organizacijskog
Apple i Google naloga i D-U-N-S broja traje sedmicama, pa 73 počinje odmah, a kod iz faze A se piše
dok se čeka. C počinje čim postoje 74 i 76. D je zadnja i ide redom.

## Status

Folder otvoren 2026-10-12.

### 64 — Istek neodgovorenih zahtjeva 🟡 (2026-10-13)

Grana `feat/istek-zahtjeva`. `private.expire_pending()` + cron `expire-pending` (5 min), push
`expired` klijentu, Melura piše „Isteklo". pgTAP 818 i REST suite zeleni lokalno, admin 577 testova.
**Ostaje:** deploy na hostovanom (Hamza: `supabase db push`, `functions deploy send-push`) i
istekli zahtjev viđen uživo u Meluri i na uređaju.

### 69 — Sedmični kalendar u Meluri 🟡 (2026-10-14)

Grana `feat/sedmicni-kalendar`. Skica u `prototype/adminv2/sedmica/` odobrena (2026-10-16), sloj
podataka i ekran gotovi: „Sedmica" u prekidaču radi, na ≥ 840 px mreža od 7 kolona (`7a`/`7c`),
na telefonu lista po danima (`7b`), tap na termin otvara detalj, tap na prazno nudi ručni termin
(zaokruženo na 30 min), tap na zaglavlje otvara dan. Admin 651 testova; viđeno uživo na demo buildu
na 1440, 1024 i 402. Drugi pregled (2026-10-19) zatvoren u istoj grani (prošli dan, rezanje teksta
na tabletu, semantika dugmadi, prekidač 44 px, demo preko granice mjeseca). **Ostaje:** odobrenje i
merge PR-a #137.
