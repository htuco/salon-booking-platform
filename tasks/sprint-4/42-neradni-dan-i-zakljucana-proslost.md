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
- [ ] RPC `set_day_closed(p_salon_id, p_date, p_reason)` — jedini put, `security definer`, `is_admin`
- [ ] Odbija datum u prošlosti i datum-danas **poslije** početka radnog vremena, sa razumljivom greškom
- [ ] Otkazuje sve `pending` i `confirmed` termine tog dana kroz postojeću putanju statusa, uz
      `cancel_reason` i `cancelled_by = 'salon'`
- [ ] Za svaki otkazan termin nastaje red u `notification_logs`
- [ ] `completed` i već `cancelled` termini se ne diraju
- [ ] pgTAP: prošlost odbijena, danas-prije-otvaranja prihvaćen, danas-poslije-otvaranja odbijen,
      broj otkazanih tačan, tuđi salon nedirnut
- [ ] Admin ekran pokazuje **koliko termina će biti otkazano** prije potvrde — nema tihe kaskade

## Zamke
- **Granica je „prije otvaranja", ne „prije 9".** Radno vrijeme je po danu i može biti po radniku;
  uzmi najraniji početak tog dana, i računaj u vremenskoj zoni salona (`salon_settings.timezone`),
  ne u zoni servera.
- Otkazivanje ide kroz `set_appointment_status`, ne direktnim `update` — inače nastaje drugo mjesto
  koje piše status.
- Ako push ne radi (task 39), obavijest se svejedno mora **zapisati**; slanje je zaseban korak.

## Status

Nije počet.
