# iOS dobija nativni prelaz ekrana

## Status

prihvaćen (2026-10-12) — za iOS i macOS zamjenjuje FE-201; Android, web i desktop ostaju na FE-201.

## Kontekst

FE-201 je uveo jedan prelaz za sve platforme (`AppPageTransitionsBuilder`): novi ekran se
pretapa preko starog uz pomak od 10 px, 220 ms. Razlog je bio da isti push ne izgleda drugačije
na dva telefona. Na iOS-u je swipe nazad nadoknađen vlastitim detektorom ivice, koji vraća
ekran, ali tokom povlačenja ekran samo blijedi na mjestu. Provjera FE-201 na uređaju
(FE-504) nikad nije urađena.

Prvi prolaz vlasnika proizvoda kroz Authentic na iPhoneu (2026-10-12), poslije popravke
navigacije u booking flowu (#130): swipe nazad sada radi, ali „ima isti efekat kao… neka se
bukvalno swipeaju screenovi kao na Meluri". Melura (admin) je na iOS-u ostala na
`CupertinoPage` i `CupertinoPageTransitionsBuilder` (ADR-0020), pa je razlika vidljiva na
istom telefonu, između dvije naše aplikacije.

## Odluka

Na iOS-u i macOS-u klijent koristi **nativni Cupertino prelaz**
(`AppCupertinoPageTransitionsBuilder` u `core_ui`): novi ekran klizi sa desne strane, stari se
pomjera ispod njega, a povlačenje sa lijeve ivice vuče ekran za prstom. Trajanje je Cupertinovo
(500 ms), ne 300 ms iz `docs/02 §14`; na iOS-u je pravilo sistema jače od našeg.

Kad je uključen **Reduce Motion**, iOS ostaje na fade prelazu iz FE-201 (sa njegovim
povlačenjem sa ivice): Cupertino prelaz ne čita `disableAnimations`.

Android, web i desktop se ne mijenjaju.

## Razmatrane opcije

- **Zadržati fade i dodati pomak koji prati prst u `_PovlacenjeNazad`** — odbačeno: dobili bismo
  vlastitu kopiju Cupertino prelaza (paralaksa starog ekrana, sjena, krive puštanja) koja se
  nikad ne bi osjećala kao sistemska, a korisnik je upravo poredio sa sistemskom.
- **Nativni prelaz na obje platforme** (Android `FadeForwards`) — odbačeno: nalaz je samo sa
  iOS-a; Android nema swipe nazad sa ivice ekrana koji bi vukao stranicu, a FE-201 tamo nije
  dobio prigovor.
- **Isključiti Reduce Motion izuzetak** — odbačeno: klizanje preko cijelog ekrana je upravo ono
  što korisnik sa uključenim Reduce Motion ne želi.

## Posljedice

- Isti push sada izgleda drugačije na Androidu i iOS-u — to je ono što je FE-201 htio izbjeći,
  i sada je namjerno.
- Prelaz na iOS-u traje 500 ms. Test koji čeka kraj animacije sa `pump(220 ms)` na iOS-u neće
  vidjeti kraj; koristi `pumpAndSettle` ili platformu različitu od iOS-a.
- Swipe nazad radi samo kad ispod postoji ekran — flow mora ići kroz `push` (v. #130 i
  `NazadIli`). Ekran otvoren sa `go` i dalje nema šta povući.
- `test/page_transition_test.dart` dokazuje da ekran tokom povlačenja prati prst; test pada
  ako se iOS vrati na fade.
