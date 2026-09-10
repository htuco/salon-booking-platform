---
name: research
description: Istraživanje koje proizvodi dokument, nikad kod.
argument-hint: <tema ili putanja do prompta>
---

# Research

Tema: **$ARGUMENTS**. Ako je prazno — traži temu.

Ako `$ARGUMENTS` pokazuje na fajl (npr. `docs/research/<ime>.md`), pročitaj ga kao zadatak:
očekuje se **Izlaz** (gdje se piše), **Istraži** (šta), **Uključi** (koje detalje), **Izvori**.
Ako je slobodan tekst, prvo predloži tu strukturu u jednoj poruci pa kreni.

## Kako se istražuje ovdje

1. **Prvo repo, pa svijet.** `docs/01`–`docs/07` nose odluke koje su već donesene i obrazložene;
   `docs/README.md` ima tabelu odluka koje se ne otvaraju bez novog podatka. Istraživanje koje
   predlaže već odbačenu opciju bez novog argumenta je izgubljen rad.
2. **Provjeri stanje koda**, ne samo dokumentaciju — dokument može zaostati.
3. Za eksterne izvore (verzije paketa, store politike, Supabase/Flutter ponašanje) navedi izvor i
   datum. Store politike i verzije paketa zastarijevaju brzo.
4. Koristi subagente za široko pretraživanje kad tema dira više foldera.

## Izlaz

- Dokument u `docs/` (nova numerisana tema) ili `docs/research/<ime>.md` za istraživanje koje nije
  dio proizvodne specifikacije.
- Na bosanskom, u stilu postojećih `docs/` fajlova: tabele odluka sa kolonom "zašto ovo, ne
  alternativa", i eksplicitne zamke.
- Zatvori sa **preporukom**, ne pregledom opcija. Ako preporuka mijenja donesenu odluku, to je ADR
  (`docs/adr/`), i reci to.

## Pravila

- Ovaj skill **ne mijenja izvorni kod**, ne pravi grane i ne commituje.
- Ne izmišljaj brojeve. Ako podatka nema, napiši da ga nema i šta bi ga dalo.
