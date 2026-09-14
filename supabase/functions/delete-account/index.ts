// Brisanje naloga, drugi korak. Task 17.
//
// Prva stvarna Edge Function u repou — `expire-pending`, `send-push`, `send-reminders` i
// `dental-recall` su za sada samo READMEs.
//
// Postoji iz jednog razloga: `auth.admin.deleteUser` je admin API i radi **samo** sa service
// role kljucem, koji zaobilazi RLS u potpunosti i nikad ne smije u klijentsku app
// (`.claude/docs/security.md`, "Tajne"). Klijent zato zove ovu funkciju, a ne Supabase Auth
// direktno.
//
// Brisanje je dvokoracno i **redoslijed nije kozmeticki**:
//
//   1. `public.delete_my_account()` — pod **korisnikovim** tokenom. Soft-delete identiteta i
//      anonimizacija u svim salonima. Autorizaciju radi sama funkcija, iz tokena.
//   2. `auth.admin.deleteUser` — pod service role kljucem. Brise `auth.users` red.
//
// Obrnuto bi pad drugog koraka ostavio `customers` red sa punim imenom i telefonom, a
// korisnikov token vise ne bi postojao — ne bi imao cime ponoviti brisanje. Ovako je najgori
// ishod siroce u `auth.users`, uz nalog koji je **vec neupotrebljiv**: `deleted_at` gasi
// `owns_identity`, sve klijentske politike i `ensure_customer`.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  // `Authorization` je korisnikov token, ne service role. `verify_jwt` je ukljucen u
  // `config.toml`, pa neispravan token ne stigne ni dovde — ali funkcija se ne oslanja na
  // to: token se i ovdje provjerava, jer odbrana koja stoji samo na konfiguraciji pukne
  // prvi put kad neko tu konfiguraciju promijeni.
  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) return json({ error: 'Nedostaje token' }, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    // Ovo je pogresna konfiguracija servera, ne korisnikova greska. Poruka namjerno ne
    // kaze **koja** varijabla fali — to je podatak o postavci servera.
    console.error('Nedostaje SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'Konfiguracija servera' }, 500);
  }

  // Klijent koji radi **kao korisnik**: njegov token ide u svaki zahtjev, pa RLS i
  // `auth.uid()` unutar RPC-a vide pravu osobu.
  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await asUser.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return json({ error: 'Nevazeci token' }, 401);
  }
  const userId = userData.user.id;

  // -------------------------------------------------------------------------
  // Korak 1 — anonimizacija, pod korisnikovim tokenom
  // -------------------------------------------------------------------------
  // Namjerno **ne** pod service role kljucem: funkcija izvodi identitet iz `auth.uid()`,
  // pa bi pod servisnim kljucem `auth.uid()` bio NULL i brisanje bi palo na 42501. Uz to,
  // pokretanje pod korisnikom znaci da ova funkcija ne moze obrisati tudji nalog ni kad bi
  // htjela — granicu drzi baza, ne ovaj fajl.
  const { data: rpcData, error: rpcError } = await asUser.rpc('delete_my_account');

  if (rpcError) {
    // `42501` je "nisi klijent ili nemas identitet" — ukljucujuci vec obrisan nalog.
    // Vraca se kao 403, ne 500: nije kvar servera nego odbijen zahtjev.
    const status = rpcError.code === '42501' ? 403 : 500;
    console.error('delete_my_account je pao', { code: rpcError.code, message: rpcError.message });
    return json({ error: 'Brisanje nije uspjelo', code: rpcError.code ?? null }, status);
  }

  // -------------------------------------------------------------------------
  // Korak 2 — `auth.users`, pod service role kljucem
  // -------------------------------------------------------------------------
  const asAdmin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: adminError } = await asAdmin.auth.admin.deleteUser(userId);

  if (adminError) {
    // **Ovo namjerno nije greska prema korisniku.** Korak 1 je prosao, znaci nalog je vec
    // neupotrebljiv i licni podaci su otisli. Vracanje greske bi korisniku reklo da
    // brisanje nije uspjelo — a jeste, u svemu sto njega ticе. Ostaje siroce u
    // `auth.users`, koje se cisti servisno.
    //
    // Posljedica koju treba znati: dok taj red postoji, `auth_identities.supabase_user_id`
    // ostaje popunjen, pa prijava istim mailom **ne** pravi nov nalog — trigger ga ne
    // uskrsava (`where deleted_at is null`), ali ni novi red ne nastaje, jer `unique`
    // stoji. Korisnik bi tada bio prijavljen bez identiteta: `ensure_customer` vraca
    // 42501, app ga tretira kao neprijavljenog. Neugodno, ali ne curi.
    console.error('auth.admin.deleteUser je pao — siroce u auth.users', {
      userId,
      message: adminError.message,
    });
    return json({ ok: true, authUserDeleted: false, details: rpcData ?? null }, 200);
  }

  // Apple token revoke (`docs/06` §8.2) ovdje **ne postoji**. Apple prijava nije
  // implementirana (task 12 je 🟡 i ceka konzole), pa se revoke ne moze ni napisati ni
  // dokazati. Kad Apple prijava udje, ovdje ide poziv na
  // `https://appleid.apple.com/auth/revoke` sa `refresh_token`-om iz Apple sesije.
  // V. `tasks/sprint-2/12-konzole-checklist.md`.

  return json({ ok: true, authUserDeleted: true, details: rpcData ?? null }, 200);
});
