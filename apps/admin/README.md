# Salon OS admin

Generička Flutter admin aplikacija za sve salone. Admin ne bira `SALON_ID`: nakon
email+password prijave salon i ovlasti dolaze iz server-side membershipa i Supabase RLS-a.

## Vizuelni handoff

Puni admin dizajn je u [`prototype/admin`](../../prototype/admin/README.md): 10 desktop i 11
mobilnih prikaza, uz [mapu prema rutama i modulima](../../prototype/admin/SPEC.md). HTML canvas je
samo referenca; implementacija ostaje u ovom Flutter paketu.

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
