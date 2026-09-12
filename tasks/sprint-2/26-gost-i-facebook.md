# Task 26 — Guest flow i Facebook login iza flaga

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [13](13-client-login-ekran.md), [25](25-push-notifikacije.md) |
| **Blokira** | — |
| **Reference** | [06 §5](../../docs/06-auth-login-flow.md) · [06 §7.4](../../docs/06-auth-login-flow.md) |

## Cilj
Dvije opcije koje se uključuju po salonu, ne po buildu: zakazivanje bez naloga i Facebook kao
dodatni provider.

## Definicija gotovog
- [ ] `vertical.rules.allowGuestBooking` uključuje "Nastavi kao gost" — **samo ime**, bez telefona
- [ ] Gost dobija anonimni `AuthIdentity` (`isAnonymous`) i push preko `device_id`
- [ ] `appointments.source = 'guest'` za takve termine
- [ ] Facebook **iza flaga**, isključen po defaultu; testiran scenario iz
      [06 §7.4](../../docs/06-auth-login-flow.md) na oba flavora
- [ ] Salon koji ne dozvoljava gosta nema to dugme — provjereno testom, ne pogledom

## Koraci
1. Guest putanja kroz isti `AuthConfig`, ne kao grana u ekranu
2. Facebook zadnji, iza flaga
3. Commit: `feat(auth): guest flow i facebook iza flaga`

## Zamke
- **Gost je svjesna odluka salona.** `docs/06` izričito kaže: ne uključivati "za svaki slučaj" —
  gost bez naloga ne može vidjeti svoje termine na drugom uređaju.
- Anonimni identitet koji se kasnije prijavi mora **zadržati termine**, inače gost gubi rezervaciju
  čim napravi nalog.
