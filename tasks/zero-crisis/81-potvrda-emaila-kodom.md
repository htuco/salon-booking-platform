# Task 81 — Potvrda emaila kodom (Resend)

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md), [74](74-domena-dns-email-hosting.md), [76](76-supabase-produkcija-i-staging.md) |
| **Blokira** | [57](57-reset-lozinke.md), [82](82-izmjena-profila-klijenta.md), [85](85-kapacitet-i-opterecenje.md), [87](87-sigurnosni-pregled.md), [89](89-prelazak-na-produkciju.md) |
| **Reference** | `docs/research/auth-krajnji-korisnik.md` §4–§5 · ADR-0010 · task 27 faza B |

## Cilj
Potvrda emaila je glavna zaštita od lažnih računa (2FA ne postoji, ADR-0029). Korisnik dobija
6-cifreni kod, ne link; ako izađe iz app-e prije unosa koda, vraća se na isti ekran.

## Definicija gotovog
- [ ] Resend: domena (poddomena za slanje), DNS zapisi kod registrara, Supabase custom SMTP,
      podignut limit emailova; koraci zapisani u `workflows.md`
- [ ] Šablon *Confirm sign up* sa `{{ .Token }}`, na bosanskom, sa imenom salona
- [ ] Ekran „Unesite kod": 6 polja, „Pošalji ponovo" sa odbrojavanjem 60 s, izlaz „Već imate račun?"
- [ ] `verifyOTP` → sesija → povratak na korak 4 sa sačuvanim izborom
- [ ] **Nastavak poslije izlaska:** email koji čeka potvrdu i booking draft se čuvaju lokalno; na
      startu i na `email_not_confirmed` app šalje novi kod i otvara ekran za kod
- [ ] `enable_confirmations = true` na hostovanom; lokalno ostaje isključeno za testove (zapisano)
- [ ] Domena pošiljaoca registrovana kod Applea (Private Email Relay)
- [ ] Testovi: kontroler (kod, resend, istekao kod), nastavak poslije restarta

## Status
Nije počet.
