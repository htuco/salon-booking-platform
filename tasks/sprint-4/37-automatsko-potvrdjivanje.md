# Task 37 — Automatsko potvrđivanje termina

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | [01 §11](../../docs/01-mvp-spec.md) · `supabase/migrations/20260921180000_postavke_lokacije.sql` |

## Cilj
Kad salon uključi automatsko potvrđivanje, klijentska rezervacija nastaje kao `confirmed`. Danas
ostaje `pending` bez obzira na postavku.

## Šta je stvarno pokvareno
Postavka postoji kroz cijeli stek i **nigdje se ne čita**. `salon_settings.booking_mode` je u
`init_schema` (`check in ('manual','auto')`), task 36 ga piše kroz RPC, admin ekran ga prebacuje —
a `book_appointment` status bira isključivo po pozivaocu:

```sql
(case when v_admin then 'confirmed' else 'pending' end)::public.appointment_status,
```

Nije rubni slučaj ni utrka: žica nikad nije spojena. Isti `case when v_admin` odlučuje i o `source`
i o `pending_expires_at` u redovima ispod, pa se sve troje mijenja zajedno.

## Definicija gotovog
- [ ] `book_appointment` čita `v_settings.booking_mode`; `auto` daje `confirmed` i `pending_expires_at = null`
- [ ] Admin unos ostaje `confirmed` bez obzira na postavku — salon ne čeka odgovor od sebe (task 24)
- [ ] pgTAP pokriva **oba** načina: `manual` → `pending` sa rokom, `auto` → `confirmed` bez roka
- [ ] Negativan test: prebacivanje postavke ne dira **postojeće** termine
- [ ] Klijent vidi tačan ishod odmah — ekran poslije rezervacije ne tvrdi „čeka potvrdu" kad je potvrđen
- [ ] `supabase/IMPLEMENTATION.md` opisuje ugovor oba načina

## Koraci
1. Nova migracija koja zamjenjuje `book_appointment` — deployana se ne mijenja
2. pgTAP prije Dart promjene
3. Provjera klijentskog ekrana potvrde i teksta koji se na njemu pojavi

## Zamke
- **`create or replace` sa istim potpisom je zamjena; sa drugačijim je preopterećenje.** Obje verzije
  ostanu u bazi sa grantom i stari poziv tiho ode na staru. Provjeri `pg_proc` upitom.
- Push „termin potvrđen" ne smije stići dvaput kad je `auto` — v. task 39.

## Status

Nije počet.
