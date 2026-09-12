// Upsert klijenta i prva stvarna rezervacija — kroz PostgREST, sa pravim JWT-om. Task 14.
// deno run --allow-env --allow-net supabase/tests/rest_customer_upsert.ts
//
// Ovo je jedini test u repou koji prolazi **cijeli** put kojim ide app: prijava → identitet →
// `ensure_customer` → `book_appointment`. pgTAP dokazuje logiku unutar baze, ali ne dokazuje da
// PostgREST prosljedjuje `x-salon-id`, da grantovi vrijede za stvarnu rolu iz tokena, niti da
// konflikt izlazi kao HTTP 409. To se vidi samo odavde.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("REST fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");

const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const uslugaA = "10000000-0000-4000-8000-000000000001"; // Musko sisanje, 30 min

const users: string[] = [];
const appointments: string[] = [];
const customers: string[] = [];
const identities: string[] = [];
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

/** Vraca `{ status, body }` umjesto da baca — pola ovog testa mjeri bas statuse gresaka. */
async function call(path: string, token: string | null, options: RequestInit = {}, salon?: string) {
  const response = await fetch(url + path, {
    ...options,
    headers: {
      apikey: token === service ? service! : anon!,
      ...(token ? { Authorization: "Bearer " + token } : {}),
      "Content-Type": "application/json",
      ...(salon ? { "x-salon-id": salon } : {}),
      ...options.headers,
    },
  });
  const raw = await response.text();
  return { status: response.status, body: raw ? JSON.parse(raw) : null };
}

async function ok(path: string, token: string | null, options: RequestInit = {}, salon?: string) {
  const result = await call(path, token, options, salon);
  if (result.status >= 400) {
    throw new Error("HTTP " + result.status + " at " + path + ": " + JSON.stringify(result.body));
  }
  return result.body;
}

/** PostgREST RPC poziv: uvijek POST sa argumentima u tijelu. */
const rpc = (args: Record<string, unknown>): RequestInit => ({
  method: "POST",
  body: JSON.stringify(args),
});

try {
  // ---------------------------------------------------------------------------
  // Pravi korisnik, pravi token
  // ---------------------------------------------------------------------------
  const email = "upsert-" + crypto.randomUUID() + "@example.test";
  const password = crypto.randomUUID() + "Aa1!";
  const user = await ok("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { full_name: "Rest Klijent" } }),
  });
  users.push(user.id);

  const session = await ok("/auth/v1/token?grant_type=password", anon, {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  const token: string = session.access_token;

  const identity = await ok(
    "/rest/v1/auth_identities?select=*&supabase_user_id=eq." + user.id,
    service,
  );
  assert(identity.length === 1, "Trigger iz taska 02 mora napraviti tacno jedan identitet.");
  identities.push(identity[0].id);

  // ---------------------------------------------------------------------------
  // ensure_customer kroz PostgREST
  // ---------------------------------------------------------------------------
  const prvi = await ok("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), salonA);
  assert(prvi?.id, "ensure_customer mora vratiti klijenta.");
  assert(prvi.salon_id === salonA, "Klijent nastaje u salonu iz x-salon-id headera.");
  assert(prvi.auth_identity_id === identity[0].id, "Klijent je vezan za identitet iz tokena.");
  assert(prvi.name === "Rest Klijent", "Ime dolazi iz display_name-a koji je trigger prenio.");
  customers.push(prvi.id);

  const drugi = await ok("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), salonA);
  assert(drugi.id === prvi.id, "Drugi poziv vraca isti red — upsert je idempotentan.");

  // Isti covjek, drugi salon: dva odvojena reda (`docs/06 §4`).
  const uSalonuB = await ok("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonB }), salonB);
  assert(uSalonuB.id !== prvi.id, "Isti nalog u drugom salonu dobija drugi customers red.");
  assert(uSalonuB.salon_id === salonB, "Drugi red pripada salonu B.");
  customers.push(uSalonuB.id);

  // ---------------------------------------------------------------------------
  // Odbijanja — ono zbog cega ova funkcija postoji
  // ---------------------------------------------------------------------------
  // Header kaze B, argument kaze A. Argument sam po sebi ne smije nista dokazivati.
  const neslaganje = await call("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), salonB);
  assert(neslaganje.status === 403, "Neslaganje headera i argumenta mora biti 403, bilo je " + neslaganje.status);

  // Bez headera nema konteksta. Ovo je slucaj koji je u prvoj verziji funkcije **prolazio**,
  // jer `true and NULL` nije `false` — v. komentar u migraciji.
  const bezHeadera = await call("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }));
  assert(bezHeadera.status === 403, "Bez x-salon-id headera mora biti 403, bilo je " + bezHeadera.status);

  const pokvaren = await call("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), "nije-uuid");
  assert(pokvaren.status === 403, "Pokvaren header mora biti 403, bilo je " + pokvaren.status);

  // Bez tokena: `anon` nema execute grant. Prije `revoke ... from anon` ovo je prolazilo.
  const bezTokena = await call("/rest/v1/rpc/ensure_customer", null, rpc({ p_salon_id: salonA }), salonA);
  assert(bezTokena.status === 401 || bezTokena.status === 403,
    "Neprijavljen poziv mora biti odbijen, bio je " + bezTokena.status);

  // ---------------------------------------------------------------------------
  // Prva stvarna rezervacija iz aplikacijskog toka
  // ---------------------------------------------------------------------------
  // Do ovog taska `book_appointment` nije nijednom pozvan sa pravim tokenom i pravim
  // klijentom — task 11 je ostao 🟡 upravo zbog toga.
  const danas = new Date();
  const dani = await ok(
    "/rest/v1/rpc/get_available_dates",
    token,
    rpc({
      p_salon_id: salonA,
      p_service_id: uslugaA,
      p_from: danas.toISOString().slice(0, 10),
      p_to: new Date(danas.getTime() + 20 * 864e5).toISOString().slice(0, 10),
    }),
    salonA,
  );
  assert(Array.isArray(dani) && dani.length > 0, "Mora postojati bar jedan slobodan dan u seedu.");
  const dan: string = dani[0].available_date ?? dani[0];

  const slotovi = await ok(
    "/rest/v1/rpc/get_available_slots",
    token,
    rpc({ p_salon_id: salonA, p_service_id: uslugaA, p_date: dan }),
    salonA,
  );
  assert(Array.isArray(slotovi) && slotovi.length > 0, "Mora postojati bar jedan slobodan slot.");
  const slot = slotovi[0];

  const termin = await ok(
    "/rest/v1/rpc/book_appointment",
    token,
    rpc({
      p_salon_id: salonA,
      p_customer_id: prvi.id,
      p_service_id: uslugaA,
      p_date: dan,
      p_start_time: slot.start_time,
      p_employee_id: slot.employee_id,
    }),
    salonA,
  );
  assert(termin?.id, "book_appointment mora vratiti termin.");
  assert(termin.status === "pending", "Termin nastaje kao pending, ne confirmed (`docs/01 §18`).");
  assert(termin.customer_id === prvi.id, "Termin je vezan za klijenta iz ensure_customer.");
  appointments.push(termin.id);

  // 409 uzivo: isti slot, isti radnik. Ostatak DoD-a iz taska 11.
  const konflikt = await call(
    "/rest/v1/rpc/book_appointment",
    token,
    rpc({
      p_salon_id: salonA,
      p_customer_id: prvi.id,
      p_service_id: uslugaA,
      p_date: dan,
      p_start_time: slot.start_time,
      p_employee_id: slot.employee_id,
    }),
    salonA,
  );
  assert(konflikt.status === 409, "Drugi zahtjev na isti slot mora biti HTTP 409, bio je " + konflikt.status);
  assert(konflikt.body?.code === "PT409",
    "Tijelo nosi PT409, ne 409 — `mapError` mapira bas taj kod (v. error_mapper.dart). Bilo: " + konflikt.body?.code);

  // Tudji klijent: isti korisnik, ali klijent iz salona B u salonu A.
  const tudji = await call(
    "/rest/v1/rpc/book_appointment",
    token,
    rpc({
      p_salon_id: salonA,
      p_customer_id: uSalonuB.id,
      p_service_id: uslugaA,
      p_date: dan,
      p_start_time: slot.start_time,
    }),
    salonA,
  );
  assert(tudji.status === 403, "Klijent iz drugog salona ne moze rezervisati u ovom, bilo je " + tudji.status);

  console.log("REST upsert + rezervacija prolazi: " + assertions + " asercija, stvaran JWT, stvaran 409.");
} finally {
  // Brise se samo ono sto je ovaj test napravio; nikad reset baze.
  for (const id of appointments) await call("/rest/v1/appointments?id=eq." + id, service, { method: "DELETE" });
  for (const id of customers) await call("/rest/v1/customers?id=eq." + id, service, { method: "DELETE" });
  for (const id of identities) await call("/rest/v1/auth_identities?id=eq." + id, service, { method: "DELETE" });
  for (const id of users) await call("/auth/v1/admin/users/" + id, service, { method: "DELETE" });
}
