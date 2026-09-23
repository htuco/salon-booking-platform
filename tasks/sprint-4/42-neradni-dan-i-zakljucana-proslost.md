# Task 42 — Neradni dan: zaključana prošlost i kaskadno otkazivanje

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [38](38-crash-radno-vrijeme.md), [39](39-push-na-androidu.md) |
| **Blokira** | — |
| **Reference** | task [34](../sprint-3/34-radno-vrijeme-i-blokade.md) · `.claude/docs/security.md` |

## Cilj
Vlasnik prijavi neradni dan (bajram, sahrana, kvar) i svi termini tog dana se otkažu, a klijenti
dobiju obavijest. Prošlost se pri tome ne smije prepisivati.

## Pravilo koje se uvodi
- **Prošli dani su zaključani.** Nema izmjene zauzetosti ni radnog vremena unazad — što je bilo,
  bilo je, i izvještaj o prometu mora ostati tačan.
- **Danas je otvoren dok salon ne otvori.** Ako bajram namaz počinje u 6, a lokal radi od 9, vlasnik
  ima tri sata da prijavi neradni dan. Poslije otvaranja se dan više ne proglašava neradnim —
  termini su već u toku.
- **Prijava neradnog dana otkazuje sve termine tog dana** i šalje obavijest svakom klijentu.

## Definicija gotovog
- [x] RPC `set_day_closed(p_salon_id, p_date, p_reason)` — jedini put, `security definer`, `is_admin`
- [x] Odbija datum u prošlosti i datum-danas **poslije** početka radnog vremena, sa razumljivom greškom
- [x] Otkazuje sve `pending` i `confirmed` termine tog dana kroz postojeću putanju statusa, uz
      `cancel_reason` i `cancelled_by = 'salon'`
- [x] Za svaki otkazan termin nastaje red u `notification_logs`
- [x] `completed` i već `cancelled` termini se ne diraju
- [x] pgTAP: prošlost odbijena, danas-prije-otvaranja prihvaćen, danas-poslije-otvaranja odbijen,
      broj otkazanih tačan, tuđi salon nedirnut
- [ ] Admin ekran pokazuje **koliko termina će biti otkazano** prije potvrde — nema tihe kaskade

## Zamke
- **Granica je „prije otvaranja", ne „prije 9".** Radno vrijeme je po danu i može biti po radniku;
  uzmi najraniji početak tog dana, i računaj u vremenskoj zoni salona (`salon_settings.timezone`),
  ne u zoni servera.
- Otkazivanje ide kroz `cancel_appointment` (ispravka 2026-09-23: `set_appointment_status` otkazivanje
  odbija sa `PT400`), ne direktnim `update` — inače nastaje drugo mjesto
  koje piše status.
- Ako push ne radi (task 39), obavijest se svejedno mora **zapisati**; slanje je zaseban korak.

## Status (2026-09-23)

U toku — baza gotova i dokazana, admin ekran napisan, **nije viđen na ekranu**.

- Migracija `20260924100000_neradni_dan.sql`: `set_day_closed`, `day_closure_preview`,
  `private.assert_day_closable`. Otkazuje kroz `cancel_appointment` — zamka u ovom fajlu je
  pokazivala na `set_appointment_status`, koji otkazivanje odbija; ispravljeno gore.
- Greške su `PT400`, ne `PT409`: klijentski mapper svaki `PT409` prikazuje kao „Termin je u
  međuvremenu zauzet".
- **Obavijest je red po uređaju** (odluka 2026-09-23, varijanta b): klijent bez registrovanog
  uređaja ne dobija red. Otkazan `pending` nosi tip `rejected` — postojeće pravilo triggera.
- Dokaz: `supabase test db` **497 asercija PASS** (novi `018` nosi 19); sabotaža provjere otvaranja
  obara 3. `melos run test` PASS (1134), `flutter analyze` čist za `admin` i `core_api`.
- Admin: prekidač „Neradni dan — otkaži sve termine" u uređivaču blokade (samo za cijeli salon),
  pregled termina sa brojem prije potvrde.

**Ostalo za sljedećeg:** vidjeti tok na ekranu (`/verify`, admin web lokalno) — prošli dan,
danas poslije otvaranja, dan sa terminima; zatim čekirati zadnju stavku DoD-a.

