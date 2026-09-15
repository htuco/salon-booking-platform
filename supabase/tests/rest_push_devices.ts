const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Test radi samo nad lokalnim Supabaseom");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
if (!anon || !service) throw new Error("Nedostaju lokalni kljucevi");
const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const installation = crypto.randomUUID();
const secret = "a".repeat(64);
const userIds: string[] = [];
const deviceIds: string[] = [];
let assertions = 0;

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
  assertions++;
}

async function call(
  path: string,
  token: string,
  body?: unknown,
  salon?: string,
  method?: string,
) {
  const response = await fetch(url + path, {
    method: method ?? (body === undefined ? "GET" : "POST"),
    headers: {
      apikey: anon,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(salon ? { "x-salon-id": salon } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const raw = await response.text();
  return { status: response.status, body: raw ? JSON.parse(raw) : null };
}

async function ok(
  path: string,
  token: string,
  body?: unknown,
  salon?: string,
  method?: string,
) {
  const result = await call(path, token, body, salon, method);
  if (result.status >= 300) throw new Error(`HTTP ${result.status}: ${path}`);
  return result.body;
}

function registration(salon: string, providedSecret = secret) {
  return {
    p_salon_id: salon,
    p_installation_id: installation,
    p_secret: providedSecret,
    p_platform: "ios",
    p_fcm_token: "test-" + installation,
    p_staff: false,
  };
}

try {
  const tokens: string[] = [];
  for (let i = 0; i < 2; i++) {
    const email = `push-${crypto.randomUUID()}@test.invalid`;
    const password = crypto.randomUUID();
    const user = await ok("/auth/v1/admin/users", service, {
      email,
      password,
      email_confirm: true,
    });
    userIds.push(user.id);
    const session = await ok("/auth/v1/token?grant_type=password", anon, {
      email,
      password,
    });
    tokens.push(session.access_token);
  }
  const id = await ok(
    "/rest/v1/rpc/register_device",
    anon,
    registration(salonA),
    salonA,
  );
  deviceIds.push(id);
  assert(typeof id === "string", "Anon registracija vraca devices.id");
  const bound = await ok(
    "/rest/v1/rpc/register_device",
    tokens[0],
    registration(salonA),
    salonA,
  );
  assert(bound === id, "Prijava zadrzava isti devices.id");
  const rows = await ok(
    `/rest/v1/devices?id=eq.${id}&select=id,auth_identity_id`,
    tokens[0],
    undefined,
    salonA,
  );
  assert(
    rows.length === 1 && rows[0].auth_identity_id,
    "Identitet je izveden iz pravog JWT-a",
  );
  const stolen = await call(
    "/rest/v1/rpc/register_device",
    tokens[1],
    registration(salonA, "b".repeat(64)),
    salonA,
  );
  assert(stolen.status === 403, "Tudja tajna mora biti 403");
  const invisible = await ok(
    `/rest/v1/devices?id=eq.${id}&select=id`,
    tokens[1],
    undefined,
    salonA,
  );
  assert(invisible.length === 0, "Drugi korisnik ne vidi uredjaj");
  const cross = await ok(
    `/rest/v1/devices?id=eq.${id}&select=id`,
    tokens[0],
    undefined,
    salonB,
  );
  assert(
    cross.length === 0,
    "Vlasnik bez konteksta pravog salona ne vidi uredjaj",
  );
  assert(
    (await call(
      "/rest/v1/rpc/register_device",
      tokens[0],
      registration(salonA),
    )).status === 403,
    "Nedostajuci header mora biti 403",
  );
  assert(
    (await call(
      "/rest/v1/rpc/register_device",
      tokens[0],
      registration(salonA),
      salonB,
    )).status === 403,
    "Nepoklapanje salona mora biti 403",
  );
  const second = await ok(
    "/rest/v1/rpc/register_device",
    tokens[0],
    registration(salonB),
    salonB,
  );
  deviceIds.push(second);
  assert(
    second !== id,
    "Isti identitet i instalacija imaju zaseban red po salonu",
  );
  assert(
    (await call(
      `/rest/v1/devices?id=eq.${id}`,
      tokens[0],
      { fcm_token: "stolen" },
      salonA,
      "PATCH",
    )).status === 403,
    "Direktan update mora biti 403",
  );
  assert(
    (await call("/rest/v1/rpc/claim_push_notifications", tokens[0], {}))
      .status === 403,
    "Korisnik ne moze pozvati servisni RPC",
  );
  await ok("/rest/v1/rpc/unregister_device", anon, {
    p_salon_id: salonA,
    p_installation_id: installation,
    p_secret: secret,
  });
  const after = await ok(
    `/rest/v1/devices?id=eq.${id}&select=fcm_token,auth_identity_id`,
    service,
  );
  assert(
    after[0].fcm_token === null && after[0].auth_identity_id === null,
    "Odjava gasi push i vezu",
  );
  console.log(
    `Push REST: ${assertions} asercija, dva stvarna JWT-a, dva salona.`,
  );
} finally {
  for (const id of deviceIds) {
    await ok(
      `/rest/v1/devices?id=eq.${id}`,
      service,
      undefined,
      undefined,
      "DELETE",
    );
  }
  for (const id of userIds) {
    await ok(
      `/auth/v1/admin/users/${id}`,
      service,
      undefined,
      undefined,
      "DELETE",
    );
  }
}
