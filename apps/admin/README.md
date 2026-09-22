# Melura admin

Generička Flutter admin aplikacija za sve salone. Admin ne bira `SALON_ID`: nakon
email+password prijave salon i ovlasti dolaze iz server-side membershipa i Supabase RLS-a.

## Vizuelni handoff

**Sliku uzimaš iz `adminv2/`, tekst iz `admin/SPEC.md`** — v.
[ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md).

- [`prototype/adminv2/export/`](../../prototype/adminv2/export/) — kako ekran **izgleda**: 21
  prikaz (`3a`–`3u`), Melura redizajn. Vizuelni izvor istine.
- [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) — šta ekran **radi**: mapa istih
  prikaza na rute i module, funkcionalne granice, tokeni. Vizual u njemu je zastario.

HTML canvas je samo referenca; implementacija ostaje u ovom Flutter paketu.

## Pokretanje

Iz roota repozitorija:

```bash
cd apps/admin
flutter run -d chrome \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Bez Supabase konfiguracije aplikacija može podići UI shell, ali stvarni admin login, tenant
izolacija i akcije nad terminima zahtijevaju pravi Supabase JWT i lokalni ili hostovani backend.

## Trenutno stanje

- implementirani su login, dashboard, lista/filter termina i akcije nad terminima;
- kalendar, usluge, osoblje, radno vrijeme i postavke još imaju placeholder rute;
- admin ostaje nebrandiran po tenantu — ne uvoziti klijentsku `core_ui` temu.
