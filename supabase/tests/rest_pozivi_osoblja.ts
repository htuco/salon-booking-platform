// Poziv za nalog osoblja kroz Edge Function, sa pravim prijavama. Task 45.
// deno run --allow-env --allow-net supabase/tests/rest_pozivi_osoblja.ts
//
// pgTAP (`020_pozivi_za_osoblje.test.sql`) dokazuje RPC-eve. Ovaj test dokazuje ono sto pgTAP
// ne moze: da Edge Function stvarno pravi `auth.users` sa `app_metadata` **iz poziva**, da se
// novi nalog prijavi kroz GoTrue i dobije tacno prava svog salona, i da uloga iz tijela
// zahtjeva ne znaci nista. Trazi aktivan edge runtime (`supabase functions serve`).
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("REST fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");

const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const sufiks = crypto.randomUUID().slice(0, 8);
const noviVlasnik = `vlasnik-${sufiks}@poziv45.invalid`;
const noviRadnik = `radnik-${sufiks}@poziv45.invalid`;
const lozinka = "lozinka-" + sufiks;
const napravljeni: string[] = [];
const pozivi: string[] = [];
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

async function call(path: string, token: string | null, options: RequestInit = {}) {
  const response = await fetch(url + path, {
    ...options,
    headers: {
      apikey: token === service ? service! : anon!,
      ...(token ? { Authorization: "Bearer " + token } : {}),
      "Content-Type": "application/json",
      ...options.headers,
    },
  });
  const raw = await response.text();
  let body: unknown = null;
  try {
    body = raw ? JSON.parse(raw) : null;
  } catch {
    body = raw;
  }
  return { status: response.status, body: body as any };
}

async function prijava(email: string, password: string) {
  const r = await call("/auth/v1/token?grant_type=password", null, {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  if (r.status !== 200) throw new Error(`Prijava ${email}: HTTP ${r.status} ${JSON.stringify(r.body)}`);
  return r.body as { access_token: string; user: { id: string; app_metadata: Record<string, unknown> } };
}

async function poziv(token: string, role: string, name: string, employeeId?: string) {
  const r = await call("/rest/v1/rpc/create_staff_invite", token, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_role: role, p_name: name, p_employee_id: employeeId ?? null }),
  });
  if (r.status !== 200) throw new Error(`create_staff_invite: HTTP ${r.status} ${JSON.stringify(r.body)}`);
  const p = (Array.isArray(r.body) ? r.body[0] : r.body) as { invite_id: string; code: string };
  pozivi.push(p.invite_id);
  return p;
}

function prihvati(body: Record<string, unknown>) {
  return call("/functions/v1/accept-staff-invite", anon!, { method: "POST", body: JSON.stringify(body) });
}

try {
  const vlasnikA = await prijava("admin@barberstudiovitez.test", "admin123456");

  // --- Vlasnik ------------------------------------------------------------
  const p1 = await poziv(vlasnikA.access_token, "salon_admin", "Novi Vlasnik");
  assert(/^[A-Z2-9]{10}$/.test(p1.code), "Kod je 10 znakova iz sigurne abecede");

  const los = await prihvati({ code: "NEPOSTOJI1", email: noviVlasnik, password: lozinka });
  assert(los.status === 404, `Nepostojeci kod daje 404, dobijeno ${los.status}`);

  const kratka = await prihvati({ code: p1.code, email: noviVlasnik, password: "kratka" });
  assert(kratka.status === 400, "Kratka lozinka daje 400");

  const ok1 = await prihvati({ code: p1.code.toLowerCase(), email: noviVlasnik, password: lozinka });
  assert(ok1.status === 200, `Prihvatanje daje 200, dobijeno ${ok1.status} ${JSON.stringify(ok1.body)}`);

  const opet = await prihvati({ code: p1.code, email: "drugi-" + noviVlasnik, password: lozinka });
  assert(opet.status === 404, "Isti kod drugi put daje 404");

  const nv = await prijava(noviVlasnik, lozinka);
  napravljeni.push(nv.user.id);
  assert(nv.user.app_metadata.role === "salon_admin", "JWT novog vlasnika nosi ulogu iz poziva");
  assert(nv.user.app_metadata.salon_id === salonA, "JWT novog vlasnika nosi salon iz poziva");

  // `staff_invites` cita samo admin salona (`staff_read`); `salon_settings` aktivnog salona je
  // javno (`public_active`), pa ne bi dokazivao nista.
  const svoje = await call(`/rest/v1/staff_invites?select=id&salon_id=eq.${salonA}`, nv.access_token);
  assert(svoje.status === 200 && svoje.body.length >= 1, "Novi vlasnik cita pozive svog salona");
  const tudje = await call(`/rest/v1/staff_invites?select=id&salon_id=eq.${salonB}`, nv.access_token);
  assert(tudje.status === 200 && tudje.body.length === 0, "Novi vlasnik ne vidi pozive drugog salona");

  // --- Uloga iz tijela zahtjeva se ignorise --------------------------------
  const p2 = await poziv(vlasnikA.access_token, "employee", "Novi Radnik", "20000000-0000-4000-8000-000000000001");
  const ok2 = await prihvati({
    code: p2.code,
    email: noviRadnik,
    password: lozinka,
    role: "super_admin",
    salon_id: salonB,
  });
  assert(ok2.status === 200, "Radnikov poziv prolazi");
  const nr = await prijava(noviRadnik, lozinka);
  napravljeni.push(nr.user.id);
  assert(nr.user.app_metadata.role === "employee", "Uloga dolazi iz poziva, ne iz zahtjeva");
  assert(nr.user.app_metadata.salon_id === salonA, "Salon dolazi iz poziva, ne iz zahtjeva");

  // --- Email koji vec ima nalog --------------------------------------------
  const p3 = await poziv(vlasnikA.access_token, "employee", "Treci", "20000000-0000-4000-8000-000000000002");
  const zauzet = await prihvati({ code: p3.code, email: "admin@barberstudiovitez.test", password: lozinka });
  assert(zauzet.status === 409, `Postojeci email daje 409, dobijeno ${zauzet.status}`);
  // Poziv ostaje ziv: neuspjelo prihvatanje ga ne trosi.
  const svjez = await call("/rest/v1/rpc/peek_staff_invite", service, {
    method: "POST",
    body: JSON.stringify({ p_code: p3.code }),
  });
  assert(svjez.status === 200 && svjez.body.length === 1, "Neuspjelo prihvatanje ne trosi poziv");

  // --- Pozivalac bez prava -------------------------------------------------
  const peekKaoAnon = await call("/rest/v1/rpc/peek_staff_invite", null, {
    method: "POST",
    body: JSON.stringify({ p_code: p3.code }),
  });
  assert(peekKaoAnon.status === 401 || peekKaoAnon.status === 403 || peekKaoAnon.status === 404,
    `anon ne zove peek_staff_invite (HTTP ${peekKaoAnon.status})`);

  // --- Uklanjanje ---------------------------------------------------------
  const ukloni = await call("/rest/v1/rpc/remove_staff_user", vlasnikA.access_token, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_user_id: nv.user.id }),
  });
  assert(ukloni.status === 204 || ukloni.status === 200, `Uklanjanje prolazi (HTTP ${ukloni.status})`);
  // Isti, jos vazeci token: JWT i dalje kaze `salon_admin`, ali red u `public.users` je otisao.
  const poslije = await call(`/rest/v1/staff_invites?select=id&salon_id=eq.${salonA}`, nv.access_token);
  assert(poslije.status === 200 && poslije.body.length === 0, "Uklonjen vlasnik sa starim tokenom ne vidi nista");

  console.log(`rest_pozivi_osoblja: ${assertions} provjera PASS`);
} finally {
  // Pozivi se brisu: zaostao ziv poziv je mijenjao brojanje u pgTAP-u (nalaz `rls-auditor`).
  for (const id of pozivi) {
    await call(`/rest/v1/staff_invites?id=eq.${id}`, service, { method: "DELETE" });
  }
  for (const id of napravljeni) {
    await call(`/auth/v1/admin/users/${id}`, service, { method: "DELETE" });
  }
}
