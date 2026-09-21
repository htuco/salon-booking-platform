// Task 33: stvarni JWT, RPC, anonimni katalog i klijentova historija.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Test radi samo nad lokalnim Supabaseom.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Nedostaju lokalni kljucevi.");
const salon = "550e8400-e29b-41d4-a716-446655440000";
const serviceId = "10000000-0000-4000-8000-000000000001";
let checks = 0;
function assert(value: unknown, message: string) {
  if (!value) throw new Error(message);
  checks++;
}
async function call(
  path: string,
  token: string | null,
  method = "GET",
  body?: unknown,
) {
  const r = await fetch(url + path, {
    method,
    headers: {
      apikey: anon!,
      ...(token ? { Authorization: "Bearer " + token } : {}),
      "Content-Type": "application/json",
      "x-salon-id": salon,
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null };
}
async function ok(
  path: string,
  token: string | null,
  method = "GET",
  body?: unknown,
) {
  const r = await call(path, token, method, body);
  if (r.status >= 300) {
    throw new Error(`${method} ${path}: ${r.status} ${JSON.stringify(r.body)}`);
  }
  return r.body;
}
async function login(email: string, password = "admin123456") {
  return (await ok("/auth/v1/token?grant_type=password", null, "POST", {
    email,
    password,
  })).access_token;
}
const a = await login("admin@barberstudiovitez.test");
const b = await login("admin@beautystudiotravnik.test");
let employee: string | undefined;
let user: string | undefined;
let customer: string | undefined;
let appointment: string | undefined;
let identity: string | undefined;
const input = {
  p_salon_id: salon,
  p_name: "REST Radnik",
  p_role: "Barber",
  p_bio: "",
  p_experience_years: null,
  p_service_ids: [serviceId],
  p_image_url: null,
};
try {
  const email = `employee-test-${crypto.randomUUID()}@invalid.test`;
  const password = "Test-task33-strong-password";
  const created = await ok("/auth/v1/admin/users", service, "POST", {
    email,
    password,
    email_confirm: true,
    user_metadata: { name: "Test klijent" },
  });
  user = created.id;
  const client = await login(email, password);
  const clientRow = await ok("/rest/v1/rpc/ensure_customer", client, "POST", {
    p_salon_id: salon,
  });
  customer = clientRow.id;
  identity = clientRow.auth_identity_id;
  const row = await ok("/rest/v1/rpc/create_employee", a, "POST", input);
  employee = row.id;
  assert(
    row.experience_years === null && row.is_active,
    "Nullable staz i aktivan novi radnik",
  );
  const publicRow = await ok(
    `/rest/v1/employees?id=eq.${employee}&select=id,is_active,experience_years`,
    null,
  );
  assert(
    publicRow.length === 1 && publicRow[0].is_active,
    "Anon vidi novi katalog i kolone",
  );
  for (
    const [rpc, body] of [
      ["create_employee", input],
      ["update_employee", { ...input, p_employee_id: employee }],
      ["set_employee_active", {
        p_salon_id: salon,
        p_employee_id: employee,
        p_is_active: false,
      }],
    ] as const
  ) {
    for (const token of [b, client, null]) {
      const r = await call("/rest/v1/rpc/" + rpc, token, "POST", body);
      assert(
        r.status === 401 || r.status === 403,
        `${rpc} odbija tudjeg admina/klijenta/anon`,
      );
    }
  }
  let date = "";
  let slot: { start_time: string } | undefined;
  for (let offset = 7; offset < 14; offset++) {
    const d = new Date();
    d.setUTCDate(d.getUTCDate() + offset);
    date = d.toISOString().slice(0, 10);
    const slots = await ok("/rest/v1/rpc/get_available_slots", client, "POST", {
      p_salon_id: salon,
      p_service_id: serviceId,
      p_date: date,
      p_employee_id: employee,
    });
    if (slots.length) {
      slot = slots[0];
      break;
    }
  }
  assert(slot, "Novi radnik ima slobodan slot prema salonskom rasporedu");
  const booked = await ok("/rest/v1/rpc/book_appointment", client, "POST", {
    p_salon_id: salon,
    p_customer_id: customer,
    p_service_id: serviceId,
    p_date: date,
    p_start_time: slot!.start_time,
    p_employee_id: employee,
  });
  appointment = booked.id;
  assert(
    booked.employee_name === "REST Radnik",
    "Rezervacija snapshotuje radnika",
  );
  await ok("/rest/v1/rpc/update_employee", a, "POST", {
    ...input,
    p_employee_id: employee,
    p_name: "Promijenjeno ime",
  });
  await ok("/rest/v1/rpc/set_employee_active", a, "POST", {
    p_salon_id: salon,
    p_employee_id: employee,
    p_is_active: false,
  });
  assert(
    (await ok(`/rest/v1/employees?id=eq.${employee}&select=id`, null))
      .length === 0,
    "Anon ne vidi deaktiviranog radnika",
  );
  assert(
    (await ok(`/rest/v1/employees?id=eq.${employee}&select=id`, b)).length ===
      0,
    "Admin B ne vidi deaktiviranog radnika A",
  );
  const history = await ok(
    `/rest/v1/appointments?id=eq.${appointment}&select=id,employee_id,employee_name,status`,
    client,
  );
  assert(
    history.length === 1 && history[0].employee_id === employee &&
      history[0].employee_name === "REST Radnik",
    "Klijent zadrzava termin i originalno ime bez pristupa neaktivnom katalogu",
  );
  assert(
    history[0].status === booked.status,
    "Deaktivacija ne otkazuje termin",
  );
  const removed = await call(
    `/rest/v1/employees?id=eq.${employee}`,
    a,
    "DELETE",
  );
  assert(
    removed.status === 403,
    "Admin ne moze fizicki obrisati radnika s terminom",
  );
  await ok("/rest/v1/rpc/set_employee_active", a, "POST", {
    p_salon_id: salon,
    p_employee_id: employee,
    p_is_active: true,
  });
  assert(
    (await ok(`/rest/v1/employees?id=eq.${employee}&select=id`, null))
      .length === 1,
    "Reaktivacija vraca katalog",
  );
  console.log(`PASS: ${checks} REST provjera osoblja`);
} finally {
  if (appointment) {
    await ok(`/rest/v1/appointments?id=eq.${appointment}`, service, "DELETE");
  }
  if (employee) {
    await ok(`/rest/v1/employees?id=eq.${employee}`, service, "DELETE");
  }
  if (customer) {
    await ok(`/rest/v1/customers?id=eq.${customer}`, service, "DELETE");
  }
  if (identity) {
    await ok(`/rest/v1/auth_identities?id=eq.${identity}`, service, "DELETE");
  }
  if (user) await ok("/auth/v1/admin/users/" + user, service, "DELETE");
}
