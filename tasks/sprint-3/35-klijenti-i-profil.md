# Task 35 — Klijenti i profil

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3e` `3o` · [15](../sprint-2/15-izolacija-klijent-u-dva-salona.md) |

## Cilj
Salon vidi svoje klijente i istoriju dolazaka. Modul još ne postoji ni kao ruta.

## Definicija gotovog
- [ ] `/clients` po `3e`, mobilno `3o`; ruta, repozitorij i ugovor su novi
- [ ] Profil: dolasci, otkazivanja, `no_show_count`, `visit_count`
- [ ] Pretraga po imenu, bez ijednog upita koji prelazi granicu salona
- [ ] **Isti čovjek u dva salona ostaje dva `Customer` reda.** Admin salona A ne smije doći do reda
      salona B ni po `id`, ni po `auth_identity_id`, ni kroz embed
- [ ] REST/pgTAP test koji to dokazuje, uz postojeći `rest_cross_salon_isolation.ts`
- [ ] `no_show` prag se i dalje **ne provodi** — to je pravilo vertikale, ne admin ekran

## Koraci
1. Repozitorij + izolacioni test prije ekrana
2. Lista, pa profil
3. Commit: `feat(admin): klijenti i profil klijenta`

## Zamke
- **Ovo je modul sa najvećim rizikom curenja u sprintu.** Klijent je jedini entitet koji stvarno
  postoji u dva salona. Task 15 je pokazao da embed na `appointments` zna postati dvosmislen
  (`PGRST201`, HTTP **300**) — test koji `300` ne tretira kao grešku prolazi lažno.
- Brisanje naloga (task 17) anonimizira i `appointments.customer_name`. Profil mora podnijeti
  klijenta bez imena.
- Telefonski klijent iz ručnog unosa nema `auth_identity_id`. To je ispravno stanje, ne greška.

## Status

Nije počet.
