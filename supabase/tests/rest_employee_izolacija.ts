// Izolacija radnika kroz PostgREST, sa stvarnim JWT-om iz GoTrue-a. Task 46.
// deno run --allow-env --allow-net supabase/tests/rest_employee_izolacija.ts
//
// pgTAP (`021_uloga_employee.test.sql`) glumi claimove kroz `set_config`. Ovaj test pravi dva
// stvarna naloga radnika, prijavi ih kroz GoTrue i provjerava sta PostgREST vrati: politika
// koja radi u transakciji, a ne kroz HTTP, je politika koja ne radi.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("REST fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");

const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const e1 = "20000000-0000-4000-8000-000000000001";
const e2 = "20000000-0000-4000-8000-000000000002";
const uslugaA = "10000000-0000-4000-8000-000000000001";
const sufiks = crypto.randomUUID().slice(0, 8);
const lozinka = "lozinka-" + sufiks;
const korisnici: string[] = [];
const termini: string[] = [];
let kupac: string | null = null;
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
      Prefer: "return=representation",
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

async function ok(path: string, token: string | null, options: RequestInit = {}) {
  const r = await call(path, token, options);
  if (r.status >= 400) throw new Error(`HTTP ${r.status} at ${path}: ${JSON.stringify(r.body)}`);
  return r.body;
}

async function radnik(employeeId: string, oznaka: string) {
  const email = `${oznaka}-${sufiks}@e46.invalid`;
  const u = await ok("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({
      email,
      password: lozinka,
      email_confirm: true,
      app_metadata: { role: "employee", salon_id: salonA, providers: ["email"] },
    }),
  });
  korisnici.push(u.id);
  await ok("/rest/v1/users", service, {
    method: "POST",
    body: JSON.stringify({ id: u.id, salon_id: salonA, name: oznaka, email, role: "employee", employee_id: employeeId }),
  });
  const s = await ok("/auth/v1/token?grant_type=password", null, {
    method: "POST",
    body: JSON.stringify({ email, password: lozinka }),
  });
  return s.access_token as string;
}

async function termin(employeeId: string | null, sat: string, ime: string) {
  const dan = new Date(Date.now() + 9 * 86400000).toISOString().slice(0, 10);
  const [t] = await ok("/rest/v1/appointments", service, {
    method: "POST",
    body: JSON.stringify({
      salon_id: salonA, service_id: uslugaA, employee_id: employeeId, customer_id: kupac,
      customer_name: ime, date: dan, start_time: sat, end_time: sat.replace(":00", ":30"), status: "pending",
    }),
  });
  termini.push(t.id);
  return t.id as string;
}

try {
  const [c] = await ok("/rest/v1/customers", service, {
    method: "POST",
    body: JSON.stringify({ salon_id: salonA, name: "Klijent 46 " + sufiks }),
  });
  kupac = c.id;
  const t1 = await termin(e1, "06:00", "Za A1");
  const t2 = await termin(e2, "07:00", "Za A2");
  const t0 = await termin(null, "08:00", "Bez radnika");

  const a1 = await radnik(e1, "a1");
  const a2 = await radnik(e2, "a2");

  // --- Citanje ------------------------------------------------------------
  const vidi = await ok(`/rest/v1/appointments?select=id&id=in.(${t1},${t2},${t0})`, a1);
  assert(vidi.length === 1 && vidi[0].id === t1, `A1 vidi samo svoj termin, dobijeno ${JSON.stringify(vidi)}`);
  const vidi2 = await ok(`/rest/v1/appointments?select=id&id=in.(${t1},${t2},${t0})`, a2);
  assert(vidi2.length === 1 && vidi2[0].id === t2, "A2 vidi samo svoj termin");
  const salonBTermini = await ok(`/rest/v1/appointments?select=id&salon_id=eq.${salonB}`, a1);
  assert(salonBTermini.length === 0, "A1 ne vidi termine salona B");
  const klijenti = await ok(`/rest/v1/customers?select=id&salon_id=eq.${salonA}`, a1);
  assert(klijenti.length === 0, "A1 ne cita adresar klijenata");
  const pozivi = await ok(`/rest/v1/staff_invites?select=id`, a1);
  assert(pozivi.length === 0, "A1 ne cita pozive");

  // --- Pisanje ------------------------------------------------------------
  const potvrda = await call("/rest/v1/rpc/set_appointment_status", a1, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_appointment_id: t1, p_status: "confirmed" }),
  });
  assert(potvrda.status === 200 && potvrda.body.status === "confirmed", `A1 potvrdjuje svoj termin (HTTP ${potvrda.status})`);

  const tudja = await call("/rest/v1/rpc/set_appointment_status", a1, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_appointment_id: t2, p_status: "confirmed" }),
  });
  assert(tudja.status === 403, `A1 ne potvrdjuje termin A2 (HTTP ${tudja.status})`);

  const bezRadnika = await call("/rest/v1/rpc/cancel_appointment", a1, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_appointment_id: t0, p_reason: "x" }),
  });
  assert(bezRadnika.status === 403, `A1 ne otkazuje termin bez radnika (HTTP ${bezRadnika.status})`);

  const direktno = await call(`/rest/v1/appointments?id=eq.${t2}`, a1, {
    method: "PATCH",
    body: JSON.stringify({ status: "cancelled" }),
  });
  assert(direktno.status === 401 || direktno.status === 403, `Direktan PATCH termina je odbijen (HTTP ${direktno.status})`);

  const usluga = await call(`/rest/v1/services?id=eq.${uslugaA}`, a1, {
    method: "PATCH",
    body: JSON.stringify({ price: 1 }),
  });
  assert(usluga.status === 401 || usluga.status === 403 || (Array.isArray(usluga.body) && usluga.body.length === 0),
    `A1 ne mijenja cjenovnik (HTTP ${usluga.status})`);
  const cijena = await ok(`/rest/v1/services?select=price&id=eq.${uslugaA}`, null);
  assert(Number(cijena[0].price) !== 1, "Cijena je netaknuta");

  const poziv = await call("/rest/v1/rpc/create_staff_invite", a1, {
    method: "POST",
    body: JSON.stringify({ p_salon_id: salonA, p_role: "salon_admin", p_name: "Uljez" }),
  });
  assert(poziv.status === 403, `A1 ne pravi poziv za vlasnika (HTTP ${poziv.status})`);

  // Stanje u bazi, citano servisnim kljucem: tudji termin nije promijenjen.
  const [stanjeT2] = await ok(`/rest/v1/appointments?select=status&id=eq.${t2}`, service);
  assert(stanjeT2.status === "pending", "Termin A2 je ostao pending");

  console.log(`rest_employee_izolacija: ${assertions} provjera PASS`);
} finally {
  for (const id of termini) await call(`/rest/v1/appointments?id=eq.${id}`, service, { method: "DELETE" });
  if (kupac) await call(`/rest/v1/customers?id=eq.${kupac}`, service, { method: "DELETE" });
  for (const id of korisnici) await call(`/auth/v1/admin/users/${id}`, service, { method: "DELETE" });
}
