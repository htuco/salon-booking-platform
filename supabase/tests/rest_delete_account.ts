// Brisanje naloga kroz Edge Function, sa pravim JWT-om. Task 17.
// deno run --allow-env --allow-net supabase/tests/rest_delete_account.ts
//
// pgTAP (`005_delete_my_account.test.sql`) dokazuje logiku unutar baze. Ovaj test dokazuje ono
// sto pgTAP ne moze: da Edge Function stvarno postoji i da radi oba koraka, da PostgREST
// odbija poziv bez tokena, i — najvaznije za DoD — da obrisan identitet **preko HTTP-a** vise
// ne cita svoje termine. Politika koja radi u transakciji, a ne radi kroz PostgREST, je
// politika koja ne radi.
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
const uslugaB = "10000000-0000-4000-8000-000000000005"; // Zensko sisanje, 45 min

const users: string[] = [];
const appointments: string[] = [];
const customers: string[] = [];
const identities: string[] = [];
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

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
  let body: unknown = null;
  try {
    body = raw ? JSON.parse(raw) : null;
  } catch {
    body = raw;
  }
  return { status: response.status, body: body as any };
}

async function ok(path: string, token: string | null, options: RequestInit = {}, salon?: string) {
  const result = await call(path, token, options, salon);
  if (result.status >= 400) {
    throw new Error("HTTP " + result.status + " at " + path + ": " + JSON.stringify(result.body));
  }
  return result.body;
}

const rpc = (args: Record<string, unknown>): RequestInit => ({
  method: "POST",
  body: JSON.stringify(args),
});

/** Prvi slobodan slot u sljedecih 14 dana, iz same baze — ne iz pretpostavke o radnom vremenu. */
async function prviSlot(salon: string, usluga: string, token: string) {
  const danas = new Date();
  for (let i = 1; i <= 14; i++) {
    const d = new Date(danas);
    d.setDate(d.getDate() + i);
    const dan = d.toISOString().slice(0, 10);
    const slots = await ok(
      "/rest/v1/rpc/get_available_slots",
      token,
      rpc({ p_salon_id: salon, p_service_id: usluga, p_date: dan }),
      salon,
    );
    if (Array.isArray(slots) && slots.length > 0) return { dan, slot: slots[0] };
  }
  throw new Error("Nema slobodnog slota u 14 dana — seed radnog vremena je promijenjen?");
}

try {
  // ---------------------------------------------------------------------------
  // Pravi korisnik, pravi token, klijent u **dva** salona
  // ---------------------------------------------------------------------------
  // Dva salona su poenta: brisanje naloga mora stici i u salon koji nije u `x-salon-id`
  // headeru kad je brisanje pokrenuto.
  const email = "brisanje-" + crypto.randomUUID() + "@example.test";
  const password = crypto.randomUUID() + "Aa1!";
  const user = await ok("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: "Za Brisanje" },
    }),
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
  assert(identity.length === 1, "Trigger mora napraviti tacno jedan identitet.");
  assert(identity[0].email === email, "Identitet nosi mail prije brisanja.");
  identities.push(identity[0].id);

  const klijentA = await ok("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), salonA);
  const klijentB = await ok("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonB }), salonB);
  customers.push(klijentA.id, klijentB.id);
  assert(klijentA.name === "Za Brisanje", "Klijent u salonu A nosi pravo ime prije brisanja.");
  assert(klijentB.name === "Za Brisanje", "Klijent u salonu B nosi pravo ime prije brisanja.");

  // Termin u svakom salonu, kroz `book_appointment` — pravi put, ne rucni insert.
  const a = await prviSlot(salonA, uslugaA, token);
  const terminA = await ok(
    "/rest/v1/rpc/book_appointment",
    token,
    rpc({
      p_salon_id: salonA,
      p_customer_id: klijentA.id,
      p_service_id: uslugaA,
      p_date: a.dan,
      p_start_time: a.slot.start_time,
      p_employee_id: a.slot.employee_id,
    }),
    salonA,
  );
  appointments.push(terminA.id);

  const b = await prviSlot(salonB, uslugaB, token);
  const terminB = await ok(
    "/rest/v1/rpc/book_appointment",
    token,
    rpc({
      p_salon_id: salonB,
      p_customer_id: klijentB.id,
      p_service_id: uslugaB,
      p_date: b.dan,
      p_start_time: b.slot.start_time,
      p_employee_id: b.slot.employee_id,
    }),
    salonB,
  );
  appointments.push(terminB.id);

  assert(terminA.customer_name === "Za Brisanje", "Termin nosi ime kao zasebnu kolonu — zato ga treba i anonimizirati.");
  assert(terminA.status === "pending", "Novi termin je pending.");

  // Korisnik svoje termine **vidi** prije brisanja. Bez ove asercije test poslije brisanja
  // ne dokazuje nista: nula termina bi mogla znaciti i da ih nikad nije ni bilo.
  const prijeA = await ok("/rest/v1/appointments?select=id", token, {}, salonA);
  assert(prijeA.length === 1, "Prije brisanja korisnik vidi svoj termin u salonu A, vidio je " + prijeA.length);

  // ---------------------------------------------------------------------------
  // Edge Function odbija sve sto nije prijavljen POST
  // ---------------------------------------------------------------------------
  const bezTokena = await call("/functions/v1/delete-account", null, { method: "POST" });
  assert(
    bezTokena.status === 401 || bezTokena.status === 403,
    "Poziv bez tokena mora biti odbijen, bio je " + bezTokena.status,
  );

  const getom = await call("/functions/v1/delete-account", token, { method: "GET" });
  assert(getom.status === 405, "GET mora biti 405, bio je " + getom.status);

  // ---------------------------------------------------------------------------
  // Brisanje
  // ---------------------------------------------------------------------------
  // Header se namjerno **ne** salje: brisanje nije salon-scoped, i to mora vrijediti i
  // preko HTTP-a, ne samo u pgTAP transakciji.
  const brisanje = await call("/functions/v1/delete-account", token, { method: "POST" });
  assert(brisanje.status === 200, "Brisanje mora vratiti 200, bilo je " + brisanje.status + ": " + JSON.stringify(brisanje.body));
  assert(brisanje.body?.ok === true, "Odgovor nosi ok:true.");
  assert(brisanje.body?.authUserDeleted === true, "auth.users red je stvarno obrisan — drugi korak je prosao.");
  assert(brisanje.body?.details?.cancelled_appointments === 2, "Oba buduca termina su otkazana, bilo je " + brisanje.body?.details?.cancelled_appointments);
  assert(brisanje.body?.details?.anonymized_customers === 2, "Oba klijentska reda su anonimizirana, bilo je " + brisanje.body?.details?.anonymized_customers);

  // ---------------------------------------------------------------------------
  // Sta je ostalo — gledano servisnim kljucem, jer korisnik vise nista ne vidi
  // ---------------------------------------------------------------------------
  const posliKlijenti = await ok(
    "/rest/v1/customers?select=name,phone,note&auth_identity_id=eq." + identity[0].id,
    service,
  );
  assert(posliKlijenti.length === 2, "Klijentski redovi su ostali — brisanje naloga nije brisanje salonove evidencije.");
  assert(
    posliKlijenti.every((c: any) => c.name === "Obrisan klijent" && c.phone === null && c.note === null),
    "Oba klijentska reda su anonimizirana u oba salona: " + JSON.stringify(posliKlijenti),
  );

  const posliTermini = await ok(
    "/rest/v1/appointments?select=id,status,customer_name,customer_phone,cancelled_by,cancel_reason&or=(id.eq." +
      terminA.id + ",id.eq." + terminB.id + ")",
    service,
  );
  assert(posliTermini.length === 2, "Termini su ostali — salon ih treba za evidenciju.");
  assert(
    posliTermini.every((t: any) => t.customer_name === "Obrisan klijent" && t.customer_phone === null),
    "Licni podaci su otisli i sa termina, ne samo sa customers reda: " + JSON.stringify(posliTermini),
  );
  assert(
    posliTermini.every((t: any) => t.status === "cancelled" && t.cancelled_by === "customer"),
    "Buduci termini su otkazani, i to kao customer: " + JSON.stringify(posliTermini),
  );

  const posliIdentitet = await ok(
    "/rest/v1/auth_identities?select=deleted_at,email,display_name,supabase_user_id&id=eq." + identity[0].id,
    service,
  );
  assert(posliIdentitet[0].deleted_at !== null, "Identitet ima deleted_at.");
  assert(posliIdentitet[0].email === null, "Mail je obrisan sa identiteta.");
  assert(posliIdentitet[0].display_name === null, "Ime je obrisano sa identiteta.");
  // FK `on delete set null` — drugi korak je obrisao `auth.users` red, pa je veza pukla sama.
  assert(
    posliIdentitet[0].supabase_user_id === null,
    "auth.users je obrisan pa je supabase_user_id pao na NULL — unique je oslobodjen za nov nalog.",
  );

  // ---------------------------------------------------------------------------
  // DoD: obrisan identitet vise ne cita svoje termine
  // ---------------------------------------------------------------------------
  // Token je i dalje **kriptografski validan** — jos nije istekao. To je i poenta: pristup
  // ne gasi istek tokena nego `deleted_at`. Da smo cekali istek, ovo ne bi dokazalo nista.
  // **Asercija trazi bas `200` sa praznom listom, ne „200 ili 401".** Ta razlika je cijeli
  // dokaz. `401` bi znacilo da je zahtjev odbijen na tokenu — sto bi prolazilo i da RLS ne
  // radi nista, i prestalo bi dokazivati bilo sta cim token istekne. `200 []` znaci da je
  // PostgREST token **prihvatio**, pa red nije vratio: pristup gasi `deleted_at`, ne istek
  // tokena. Provjereno sondom pri pisanju testa — stvarni odgovor je `200 []`.
  const staroSvjetlo = await call("/rest/v1/appointments?select=id", token, {}, salonA);
  assert(
    staroSvjetlo.status === 200,
    "Token mora i dalje biti prihvacen — inace test mjeri istek tokena, ne RLS. Bilo je " +
      staroSvjetlo.status + ": " + JSON.stringify(staroSvjetlo.body),
  );
  assert(
    Array.isArray(staroSvjetlo.body) && staroSvjetlo.body.length === 0,
    "Obrisan identitet ne smije procitati nijedan termin, dobio je " + JSON.stringify(staroSvjetlo.body),
  );

  const svojKlijent = await call("/rest/v1/customers?select=id", token, {}, salonA);
  assert(svojKlijent.status === 200, "Token je i dalje prihvacen i za customers.");
  assert(
    Array.isArray(svojKlijent.body) && svojKlijent.body.length === 0,
    "Obrisan identitet ne vidi svoj customers red, dobio je " + JSON.stringify(svojKlijent.body),
  );

  // Rezervacija sa istim tokenom mora pasti — inace bi obrisan nalog i dalje mogao trositi slotove.
  const ponovniUpsert = await call("/rest/v1/rpc/ensure_customer", token, rpc({ p_salon_id: salonA }), salonA);
  assert(
    ponovniUpsert.status === 401 || ponovniUpsert.status === 403,
    "ensure_customer mora odbiti obrisan identitet, bilo je " + ponovniUpsert.status,
  );

  // Drugo brisanje: nema sta da se brise.
  const drugoBrisanje = await call("/functions/v1/delete-account", token, { method: "POST" });
  assert(
    [401, 403].includes(drugoBrisanje.status),
    "Drugo brisanje mora biti odbijeno, bilo je " + drugoBrisanje.status,
  );

  // ---------------------------------------------------------------------------
  // Nova prijava istim mailom dobija **cist** nalog
  // ---------------------------------------------------------------------------
  // Ovo je zamka koju je task fajl imenovao: bez `where deleted_at is null` u trigeru bi
  // `on conflict do update` vratio stari nalog u zivot, sa svim starim vezama.
  const noviUser = await ok("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { full_name: "Opet Ja" } }),
  });
  users.push(noviUser.id);

  const noviIdentitet = await ok(
    "/rest/v1/auth_identities?select=id,deleted_at,display_name&supabase_user_id=eq." + noviUser.id,
    service,
  );
  assert(noviIdentitet.length === 1, "Nova prijava istim mailom pravi nov identitet.");
  assert(noviIdentitet[0].id !== identity[0].id, "Nov identitet je stvarno **nov** red, ne uskrsnuli stari.");
  assert(noviIdentitet[0].deleted_at === null, "Nov identitet nije obrisan.");
  identities.push(noviIdentitet[0].id);

  const stariOstaje = await ok(
    "/rest/v1/auth_identities?select=deleted_at&id=eq." + identity[0].id,
    service,
  );
  assert(stariOstaje[0].deleted_at !== null, "Stari identitet je i dalje obrisan — nije uskrsnuo.");

  console.log("Brisanje naloga prolazi: " + assertions + " asercija, stvaran JWT, Edge Function, oba salona.");
} finally {
  // Brise se samo ono sto je ovaj test napravio; nikad reset baze.
  for (const id of appointments) await call("/rest/v1/appointments?id=eq." + id, service, { method: "DELETE" });
  for (const id of customers) await call("/rest/v1/customers?id=eq." + id, service, { method: "DELETE" });
  for (const id of identities) await call("/rest/v1/auth_identities?id=eq." + id, service, { method: "DELETE" });
  for (const id of users) await call("/auth/v1/admin/users/" + id, service, { method: "DELETE" });
}
