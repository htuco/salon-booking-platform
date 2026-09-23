// Prihvatanje poziva za nalog osoblja. Task 45, ADR-0023.
//
// Radnik jos nema nalog, pa nema ni token: poziva se sa anon kljucem i donosi samo
// `{ code, email, password }`. **Uloga i salon nikad ne dolaze iz zahtjeva** — citaju se iz
// poziva koji je napisao admin salona (`peek_staff_invite`).
//
// Redoslijed:
//   1. `peek_staff_invite(code)` — je li poziv ziv, koju ulogu i salon nosi;
//   2. `auth.admin.createUser` sa `app_metadata` iz poziva i potvrdjenim emailom — bez SMTP-a;
//   3. `accept_staff_invite(code, user_id, email)` — `public.users` + zatvaranje poziva, u
//      jednoj transakciji, uz ponovnu provjeru (`for update`).
//
// Ako 3. padne (npr. drugi uredjaj je u medjuvremenu iskoristio isti kod), `auth.users` red iz
// 2. se brise. Bez toga bi ostao nalog sa `role = salon_admin` u JWT-u a bez `public.users`
// reda — ne bi imao prava (`is_admin` trazi oboje), ali bi zauzeo email.

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

  let body: { code?: unknown; email?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Neispravan zahtjev' }, 400);
  }
  const code = typeof body.code === 'string' ? body.code.trim().toUpperCase() : '';
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';

  if (!code || !email || !password) {
    return json({ error: 'Kod, email i lozinka su obavezni.' }, 400);
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ error: 'Email nije ispravan.' }, 400);
  }
  if (password.length < 8) {
    return json({ error: 'Lozinka mora imati najmanje 8 znakova.' }, 400);
  }

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    console.error('Nedostaje SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY');
    return json({ error: 'Konfiguracija servera' }, 500);
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Poziv. Nepostojeci, istekao, povucen i iskoristen kod daju **istu** poruku: razlika bi
  //    bila nacin da se pogadjanjem sazna koji kodovi postoje.
  const { data: pozivi, error: peekError } = await admin.rpc('peek_staff_invite', { p_code: code });
  if (peekError) {
    console.error('peek_staff_invite je pao', { code: peekError.code, message: peekError.message });
    return json({ error: 'Poziv se ne može provjeriti.' }, 500);
  }
  const poziv = Array.isArray(pozivi) ? pozivi[0] : null;
  if (!poziv) {
    return json({ error: 'Poziv ne postoji, istekao je ili je već iskorišten.' }, 404);
  }

  // 2. Nalog. `app_metadata` postavlja samo server — korisnik ga ne moze mijenjati.
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { role: poziv.role, salon_id: poziv.salon_id, providers: ['email'] },
    user_metadata: { name: poziv.name },
  });
  if (createError || !created?.user) {
    // Email koji vec ima nalog (npr. klijentski) se ne pretvara u nalog osoblja: to bi
    // klijentu tiho dalo drugu ulogu nad istom prijavom.
    const postoji = /already|registered|exists/i.test(createError?.message ?? '');
    if (postoji) {
      return json({ error: 'Ovaj email već ima nalog. Upišite drugi email.' }, 409);
    }
    console.error('createUser je pao', { message: createError?.message });
    return json({ error: 'Nalog se ne može napraviti.' }, 500);
  }
  const userId = created.user.id;

  // 3. `public.users` i zatvaranje poziva.
  const { error: acceptError } = await admin.rpc('accept_staff_invite', {
    p_code: code,
    p_user_id: userId,
    p_email: email,
  });
  if (acceptError) {
    const { error: cleanupError } = await admin.auth.admin.deleteUser(userId);
    if (cleanupError) {
      console.error('Siroce u auth.users poslije neuspjelog prihvatanja', {
        userId,
        message: cleanupError.message,
      });
    }
    if (acceptError.code === 'PT404') {
      return json({ error: 'Poziv ne postoji, istekao je ili je već iskorišten.' }, 404);
    }
    console.error('accept_staff_invite je pao', { code: acceptError.code, message: acceptError.message });
    return json({ error: 'Nalog se ne može napraviti.' }, 500);
  }

  return json({ ok: true, role: poziv.role }, 200);
});
