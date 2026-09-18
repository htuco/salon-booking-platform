# Taskovi — Sprint 3: admin aplikacija po handoffu

Nastavak [Sprinta 2](../sprint-2/). Cijeli sprint je **jedna aplikacija**: `apps/admin` prestaje
biti četiri ekrana i placeholder rute i postaje alatka kojom salon vodi dan.

Izvor istine je [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) — 10 desktop prikaza na
1440×900 i 11 mobilnih na 402×874, sa mapom prikaza na rute. Redoslijed ispod prati njegov
odjeljak „Redoslijed implementacije", uz jedno namjerno odstupanje (v. ispod).

| # | Task | Prikazi | Blokira | Procjena |
|---|---|---|---|---|
| [28](28-admin-tema-i-tipografija.md) | Admin tema, tipografija i tokeni | svi | 29, 30 | 1 dan |
| [29](29-responsive-shell.md) | Responsive shell: desktop sidebar + mobilna navigacija | `3b`–`3i`, `3k`–`3t` | 30–36 | 1–2 dana |
| [30](30-postojeci-ekrani-na-handoff.md) | Postojeći ekrani na handoff: prijava, Danas, zahtjevi, termini | `3b` `3d` `3j` `3k` `3m` `3n` `3u` | — | 2–3 dana |
| [31](31-kalendar-dana.md) | Kalendar dana | `3c` `3l` | — | 2–3 dana |
| [32](32-usluge-i-cjenovnik.md) | Usluge i cjenovnik — CRUD | `3f` `3p` `3q` | — | 2–3 dana |
| [33](33-osoblje-i-smjene.md) | Osoblje i smjene — CRUD | `3g` `3r` | 34 | 2–3 dana |
| [34](34-radno-vrijeme-i-blokade.md) | Radno vrijeme, pauze i blokade | `3h` `3s` | — | 2–3 dana |
| [35](35-klijenti-i-profil.md) | Klijenti i profil | `3e` `3o` | — | 1–2 dana |
| [36](36-postavke-lokacije.md) | Postavke lokacije | `3i` `3t` | — | 1–2 dana |

**Ukupno: ~15–22 radna dana.**

## Redoslijed koji nije očigledan

- **29 ide prije 30, obrnuto od `SPEC.md`.** Handoff prvo traži prevod postojećih ekrana, pa onda
  shell. Redoslijed je zamijenjen jer `3b` i `3k` **nisu dva ekrana nego jedan ekran u dvije
  ljuske** — desktop ga crta u radnoj površini pored sidebara, telefon iznad donje navigacije. Ko
  prvo prevede ekran, prevodi ga u ljusku koja se sutra mijenja, pa ga prevodi dvaput.
- **28 je prvi i nije kozmetika.** Dok tokeni nisu na jednom mjestu, svaki naredni ekran ih
  prepisuje. `SPEC.md` to kaže izričito: „Vrijednosti prvo centralizovati u
  `apps/admin/lib/src/core/theme/`; ne ponavljati hex vrijednosti po ekranima." Taj folder danas
  ima samo `.gitkeep`, a `main.dart` gradi temu iz jednog `ColorScheme.fromSeed`.
- **33 prije 34.** Smjena je smjena **radnika**; radno vrijeme koje se piše prije nego osoblje ima
  svoj ekran nema na šta da se veže.
- **32, 33 i 34 nose backend, ne samo ekran.** Danas ne postoji nijedna RPC putanja kojom admin
  piše uslugu, radnika ili radno vrijeme — `docs/01 §17` korak 25 ih broji zajedno. Svaka od te
  tri ide istim redom kao task 24: **migracija i pgTAP prije ekrana**.
- **35 i 36 su zadnji jer ništa ne blokiraju.** Ako sprint pukne, pucaju oni, a admin i dalje vodi
  dan.

## Granice koje handoff izričito postavlja

- **`3a` (pregled mreže, svi saloni) nije u ovom sprintu.** Traži multi-location RBAC i serversku
  autorizaciju kojih nema. Prikaz u prototipu **nije dozvola** za client-side izbor salona; salon i
  ovlasti i dalje dolaze iz membershipa i RLS-a (`ADR-0003`).
- **Admin nije brandiran.** Plava je identitet Salon OS-a, ne boja salona. Ne uvozi se klijentska
  `core_ui` tema niti bilo šta iz `tenant.yaml` — to je obrnuto od pravila koje vrijedi za
  `apps/client`, i najlakše se prekrši navikom.
- **Prototip ne zamjenjuje postojeće RPC tokove.** Potvrda, odbijanje, otkazivanje, `no_show` i
  ručni termin rade od taska 24 i ostaju kakvi jesu; mijenja im se izgled, ne putanja.
- **Tablet nije nacrtan.** Raspored se mijenja na breakpointu, a ne skaliranjem desktopa.

## Šta ovaj sprint **ne** zatvara

`docs/01 §17` pod Sprint 3 broji još i ovo — ostaje otvoreno i ne gubi se:

- **Super admin web konzola** (Next.js, `docs/07`) — drugi proizvod, drugi toolchain.
- **Podsjetnici D-1 / H-3** — traže scheduler nad `notification_logs` iz taska 25.
- **Web build klijentske app-e + QR**, **javna URL politike privatnosti**, **prvi Play
  submission**, **demo pravom salonu**.

Iz Sprinta 2 ostaju 🟡 stavke koje **ne zavise od koda** nego od tuđih naloga: deploy šeme na
hostovani Supabase, FCM na fizičkom uređaju, Apple i Google konzole. One ne blokiraju nijedan task
ovdje — admin se razvija protiv lokalnog stacka.

## Status

> Sprint još nije počeo. Prvi task je [28](28-admin-tema-i-tipografija.md).
