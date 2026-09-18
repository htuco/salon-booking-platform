# `prototype/admin/` — admin vizuelni izvor istine

Ovdje je izdvojen puni dizajnerski handoff za **Salon OS admin aplikaciju**: 10 desktop prikaza
na 1440×900 i 11 mobilnih prikaza na 402×874. Handoff je referenca za postojeći Flutter target
[`apps/admin`](../../apps/admin/README.md); HTML i JavaScript iz `canvas/` nisu production kod.

## Brzi pregled

Iz roota repozitorija pokreni:

```bash
python3 -m http.server 4173 --directory prototype/admin
```

Zatim otvori `http://localhost:4173/`. Lokalni server je potreban jer canvas učitava pomoćne
fajlove i stanje slika preko relativnih URL-ova. Fontovi dolaze sa Google Fonts; bez mreže će
browser koristiti sistemski fallback, dok ostatak prototipa i dalje radi.

## Šta je gdje

| Putanja | Sadržaj |
|---|---|
| [`index.html`](index.html) | Navigacija prema sva 21 prikaza. |
| [`SPEC.md`](SPEC.md) | Mapa ekrana, vizuelni tokeni i granice implementacije. |
| `canvas/Salon OS Admin.dc.html` | Glavni design canvas sa desktop i mobilnim prikazima. |
| `canvas/Smjer C - Space Grotesk.dc.html` | Izabrani vizuelni smjer na kojem je handoff zasnovan. |
| `canvas/assets/` | Placeholder fotografije koje canvas koristi. |
| `canvas/support.js`, `image-slot.js`, `ios-frame.jsx` | Isključivo renderer za design canvas; ne portuje se u Flutter. |

## Odnos prema postojećem admin kodu

- `apps/admin` ostaje jedna generička Flutter aplikacija za sve salone, bez tenantskih flavora i
  bez `SALON_ID` izbora u UI-ju.
- Salon i ovlasti dolaze iz server-side membershipa i RLS-a. Handoff ne mijenja sigurnosna pravila
  niti daje pravo da se multi-location ekran `3a` implementira prije odgovarajućeg RBAC-a.
- Login, dashboard, lista termina i akcije nad terminima već postoje. Novi handoff postaje
  vizuelna referenca za njih i za naredne module: kalendar, klijente, usluge, osoblje, radno
  vrijeme i postavke.
- Boje admina su platformski identitet Salon OS-a, a ne boje pojedinačnog salona. Nemoj koristiti
  `core_ui` temu klijentske aplikacije niti tenant branding u adminu.

Prije implementacije pojedinog prikaza provjeri njegov red u [`SPEC.md`](SPEC.md), jer prototip
sadrži i budući mrežni pregled koji nije dio trenutnog Vitez demo scopea.
