// Local-only integration test using real GoTrue JWTs and PostgREST requests.
// deno run --allow-env --allow-net supabase/tests/rest_isolation.ts
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("REST isolation fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");
const salons = ["550e8400-e29b-41d4-a716-446655440000", "550e8400-e29b-41d4-a716-446655440001"];
const users: string[] = [];
const customers: string[] = [];
const identities: string[] = [];
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}
async function request(path: string, token: string, options: RequestInit = {}, salon?: string) {
  const response = await fetch(url + path, {
    ...options,
    headers: {
      apikey: token === service ? service! : anon!,
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
      ...(salon ? { "x-salon-id": salon } : {}),
      ...options.headers,
    },
  });
  const raw = await response.text();
  const body = raw ? JSON.parse(raw) : null;
  if (!response.ok) throw new Error("HTTP " + response.status + " at " + path + ": " + JSON.stringify(body));
  return body;
}
async function rows(table: string, token: string, salon?: string, filter = "") {
  return await request("/rest/v1/" + table + "?select=*" + filter, token, {}, salon) as Record<string, unknown>[];
}

try {
  const sessions: { token: string; refreshToken: string; id: string }[] = [];
  for (let index = 0; index < 2; index++) {
    const email = "tenant-isolation-" + crypto.randomUUID() + "@example.test";
    const password = crypto.randomUUID() + "Aa1!";
    const user = await request("/auth/v1/admin/users", service, {
      method: "POST",
      body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { name: "Isolation " + index } }),
    });
    users.push(user.id);
    const session = await request("/auth/v1/token?grant_type=password", anon, {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    sessions.push({ token: session.access_token, refreshToken: session.refresh_token, id: user.id });
    const identity = await rows("auth_identities", service, undefined, "&supabase_user_id=eq." + user.id);
    assert(identity.length === 1, "Auth trigger must create exactly one global identity.");
    identities.push(identity[0].id as string);
    for (const salonId of salons) {
      const result = await request("/rest/v1/customers", service, {
        method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          salon_id: salonId,
          auth_identity_id: identity[0].id,
          name: "Isolation " + index,
          visit_count: salonId === salons[0] ? index + 1 : index + 9,
        }),
      });
      customers.push(result[0].id);
    }
  }
  assert(sessions[0].token !== sessions[1].token, "The integration test requires two different JWTs.");
  for (let index = 0; index < sessions.length; index++) {
    const token = sessions[index].token;
    const a = await rows("customers", token, salons[0]);
    assert(a.length === 1, "Salon A client must see exactly its own customer.");
    assert(a[0].salon_id === salons[0], "Salon A must not leak salon B rows.");
    assert(a[0].auth_identity_id === identities[index], "Different identity must remain hidden.");
    assert(a[0].visit_count === index + 1, "Visit count is strictly local to salon A.");
    const malicious = await rows("customers", token, salons[0], "&salon_id=eq." + salons[1]);
    assert(malicious.length === 0, "Query filter cannot bypass salon context.");
    assert((await rows("customers", token)).length === 0, "Missing salon header must fail closed.");
    assert((await rows("customers", token, "invalid")).length === 0, "Malformed salon header must fail closed.");
    const b = await rows("customers", token, salons[1]);
    assert(b.length === 1 && b[0].visit_count === index + 9, "Explicit context switch sees only own salon B data.");
    const global = await rows("auth_identities", token, salons[0]);
    assert(global.length === 1 && global[0].supabase_user_id === sessions[index].id, "Only own identity may be read.");

    // A real user-metadata mutation and freshly signed JWT must not grant staff rights.
    await request("/auth/v1/user", token, {
      method: "PUT",
      body: JSON.stringify({ data: { role: "super_admin", salon_id: salons[1] } }),
    });
    const refreshed = await request("/auth/v1/token?grant_type=refresh_token", anon, { method: "POST", body: JSON.stringify({ refresh_token: sessions[index].refreshToken }) });
    const unchanged = await rows("customers", refreshed.access_token, salons[0]);
    assert(unchanged.length === 1, "User metadata must never broaden tenant access.");
  }
  const publicServices = await rows("services", anon);
  assert(publicServices.length >= 8, "Unauthenticated customers can browse the demo services.");
  console.log("REST tenant isolation passed: " + assertions + " assertions, two real JWTs.");
} finally {
  // Remove only UUIDs created in this test; never truncate/reset a database.
  for (const id of customers) await request("/rest/v1/customers?id=eq." + id, service, { method: "DELETE" });
  for (const id of identities) await request("/rest/v1/auth_identities?id=eq." + id, service, { method: "DELETE" });
  for (const id of users) await request("/auth/v1/admin/users/" + id, service, { method: "DELETE" });
}
