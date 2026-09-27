# Siročad u bucketu čisti periodični sweep, prijava slike ide platformi

## Status

prihvaćen

## Kontekst

[ADR-0015](0015-slike-idu-u-supabase-storage-javni-bucket.md) je ostavio dvije posljedice
otvorene: fajl koji se zamijeni ili obriše mora nestati iz bucketa, a store review traži način
prijave neprikladnog sadržaja.

Činjenice iz koda na početku taska 51:

- `MediaRepository.upload` svakom uploadu daje **novo ime** (CDN keš), pa svaka zamjena slike
  ostavlja stari objekat bez reference. U kodu nema nijednog brisanja objekta.
- Upload i upis reference su dva odvojena poziva. Prekinut tok (fajl gore, RPC pao, tab
  zatvoren) ostavlja siroče koje nijedan kasniji korak ne vidi.
- „Brisanje" usluge i radnika je `is_active = false` (`service_crud`, `employee_crud`).
  Deaktivirana usluga se može vratiti.
- Supabase ne dozvoljava direktan `delete from storage.objects`; fajl se briše samo kroz
  Storage API.
- Hostovani projekat nema SMTP ([ADR-0023](0023-nalog-osoblja-nastaje-iz-koda-poziva.md)), a
  super admin konzole nema (`docs/01` §6.1).

## Odluka

### Čišćenje

Siročad briše **periodični sweep**: Edge Function `cleanup-media`, koju `pg_cron` okida svakog
sata kroz `pg_net`, potpisano HMAC-om (isti obrazac kao `send-push`).

- **Siroče** je objekat u `salon-media/<salon>/<vrsta>/<fajl>` čiju putanju ne referencira
  nijedna slikovna kolona: `services.image_url`, `employees.image_url` (i neaktivni redovi),
  `salons.logo_url`, `salons.cover_image_url`, `salons.gallery_urls`. Referenca se traži u
  svim kolonama **svih salona**, ne samo u koloni vrste ni samo u salonu iz putanje: pogrešno
  zadržan fajl košta prostor, a pogrešno obrisan kvari ekran.
- Listu siročadi daje SQL (`public.media_orphans`, samo `service_role`), a briše Storage API.
  Funkcija briše **po salonu**: svaki `remove` poziv nosi samo putanje sa prefiksom tog salona.
  Putanja koja ne počinje sa `<salon_id>/` se odbija prije poziva, ne šalje se.
- Objekat mlađi od **sat vremena** se ne dira, jer upload još čeka RPC koji upisuje referencu.
- **Deaktivirana usluga i radnik zadržavaju sliku.** Referenca iz neaktivnog reda čuva fajl, pa
  vraćena usluga ima sliku. Fajl nestaje kad se `image_url` zamijeni ili očisti. Tako se čita
  DoD stavka „brisanje usluge/radnika briše i fajl".
- Admin ne briše stari fajl sam u trenutku zamjene. Sweep i tako mora postojati zbog prekinutih
  tokova, pa bi druga putanja brisanja bila još jedno mjesto na kojem greška u prefiksu briše
  tuđe slike.

### Prijava sadržaja

- Prijavljeni klijent prijavljuje sliku iz galerije salona. Prijava ide u
  `public.content_reports`, koju **salon ne čita**: čita je samo `super_admin`. Neprijavljen
  korisnik se šalje na prijavu, isto kao kod zakazivanja. Anonimna prijava bi otvorila spam
  bez traga.
- Prijava se upisuje samo za sliku koja je stvarno u galeriji tog salona, i samo jednom po
  klijentu i slici dok je otvorena.
- Platforma saznaje kroz **webhook**: Edge Function `notify-content-reports` (pg_cron svake
  minute, HMAC) šalje neobaviještene prijave na `REPORT_WEBHOOK_URL` (Slack/Discord). URL
  webhooka je tajna Edge Functiona, ne ide u `pg_net`: njegove transportne tabele čita
  `supabase_admin`.
- **Prijavljena slika ostaje vidljiva** dok platforma ne odluči. Jedan klijent lažnom prijavom
  ne smije sakriti tuđu galeriju. Platforma uklanja sliku kroz service role (uputstvo u
  `.claude/docs/workflows.md`), a sweep zatim briše fajl.

## Razmatrane opcije

- **Brisanje u istoj operaciji, iz admina** — odbačeno kao jedini mehanizam: ne vidi prekinut
  upload. Kao dodatak ne donosi ništa što sweep ne radi, a duplira putanju brisanja.
- **Brisanje iz SQL triggera** — odbačeno: Supabase blokira direktan `delete` nad
  `storage.objects`. Red bi nestao, a fajl ostao.
- **Brisanje fajla pri deaktivaciji usluge/radnika** — odbačeno: vraćena usluga bi imala mrtav
  URL.
- **Prijava samo u tabelu, bez obavještenja** — odbačeno: Apple očekuje reakciju na prijavu u
  razumnom roku, a tabelu koju niko ne gleda niko ne gleda.
- **Push super adminu** — odbačeno za sada: admin aplikacija ne zna za ulogu `super_admin`, a
  super admin nema registrovan uređaj.
- **Webhook URL u Vaultu, `pg_net` direktno na Slack** — odbačeno: tajna bi završila u
  `net.http_request_queue`.
- **Automatsko skrivanje prijavljene slike** — odgođeno, ne odbačeno: vraća se kad lažne
  prijave postanu stvaran problem ili kad store review izričito traži skrivanje za prijavitelja.

## Posljedice

- Zamijenjena slika nestaje iz bucketa do sat i po kasnije, ne odmah. Dvije slike u folderu
  odmah nakon zamjene su očekivane, nisu bug.
- Hostovani projekat treba tajne `MEDIA_CLEANUP_SECRET`, `CONTENT_REPORT_WORKER_SECRET` i
  `REPORT_WEBHOOK_URL`, plus Vault redove sa URL-om i tajnom za oba workera. Bez njih cron ne
  šalje ništa: fajlovi ostaju, a prijave čekaju u tabeli, ne gube se.
- Nova slikovna kolona (npr. „prije i poslije") mora ući u `public.media_orphans`. Inače sweep
  njene fajlove vidi kao siročad i briše ih sat nakon uploada.
- Reakcija na prijavu je ručni posao platforme dok ne postoji super admin konzola.
