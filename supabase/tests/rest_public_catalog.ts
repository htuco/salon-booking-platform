// Proves the public catalog is readable WITHOUT a login, with exactly the columns the
// core_api repositories ask for (task 08).
//
// "Without a login" means: the anon apikey, and no user JWT in Authorization. That is what
// a freshly installed app does before the customer ever signs in — the catalog screen must
// work there, or the first screen of every tenant is empty.
//
// This is the CI proof for the task-08 DoD item "radi bez prijave (anon), dokazano pozivom
// bez tokena". It cannot be proven on the dev machine: no Docker, so no local stack.
//
// deno run --allow-env --allow-net supabase/tests/rest_public_catalog.ts
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Public catalog fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");

const activeSalon = "550e8400-e29b-41d4-a716-446655440000";
const otherSalon = "550e8400-e29b-41d4-a716-446655440001";
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

// No Authorization header at all — this is the whole point of the file. PostgREST needs the
// apikey to route the request; the absence of a user JWT is what makes the role `anon`.
async function anonRequest(path: string, options: RequestInit = {}) {
  const response = await fetch(url + path, {
    ...options,
    headers: { apikey: anon!, "Content-Type": "application/json", ...options.headers },
  });
  const raw = await response.text();
  return { status: response.status, body: raw ? JSON.parse(raw) : null };
}

async function anonRows(table: string, columns: string, filter = "") {
  const { status, body } = await anonRequest(
    "/rest/v1/" + table + "?select=" + encodeURIComponent(columns) + filter,
  );
  assert(status === 200, `Anon read of ${table} must succeed, got HTTP ${status}: ${JSON.stringify(body)}`);
  return body as Record<string, unknown>[];
}

async function serviceRequest(path: string, options: RequestInit = {}) {
  const response = await fetch(url + path, {
    ...options,
    headers: {
      apikey: service!,
      Authorization: "Bearer " + service,
      "Content-Type": "application/json",
      ...options.headers,
    },
  });
  const raw = await response.text();
  if (!response.ok) throw new Error("HTTP " + response.status + " at " + path + ": " + raw);
  return raw ? JSON.parse(raw) : null;
}

// The column lists below are copied from the repositories in packages/core_api/lib/src/catalog/.
// If a migration renames a column, this test fails here rather than in a released app —
// PostgREST answers an unknown column with 400, not with a null field.
const SALON_COLUMNS =
  "id,name,slug,description,logo_url,cover_image_url,primary_color,secondary_color,theme,address,city,phone,email,instagram_url,facebook_url,vertical_pack_key";
const SERVICE_COLUMNS = "id,salon_id,name,description,category,price,duration_minutes";
const EMPLOYEE_COLUMNS = "id,salon_id,name,role,bio,image_url";
const EMPLOYEE_SERVICE_COLUMNS = "id,salon_id,employee_id,service_id";
const WORKING_HOURS_COLUMNS =
  "id,salon_id,employee_id,day_of_week,start_time,end_time,break_start_time,break_end_time,is_closed";
const SETTINGS_COLUMNS =
  "id,salon_id,booking_mode,booking_granularity,buffer_minutes,slot_step_minutes,min_advance_booking_hours,max_advance_booking_days,pending_expiry_hours,min_cancel_hours,require_staff_choice,show_prices_in_app,allow_guest_booking,timezone,language";

try {
  // ---------------------------------------------------------------------------
  // 1. Every catalog repository's query works with no user token.
  // ---------------------------------------------------------------------------
  const salons = await anonRows("salons", SALON_COLUMNS, "&id=eq." + activeSalon);
  assert(salons.length === 1, "Anon must see the active salon.");
  assert(salons[0].name === "Barber Studio Vitez", "Salon name must map from the seeded row.");
  assert(salons[0].primary_color === "#C6A667", "primary_color must survive the column list.");
  assert(salons[0].vertical_pack_key === "barber", "vertical_pack_key must be readable by anon.");

  const services = await anonRows("services", SERVICE_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(services.length === 4, `Seeded barber salon has 4 services, got ${services.length}.`);
  assert(
    services.every((row) => typeof row.duration_minutes === "number"),
    "duration_minutes must come back as a number — the model reads it as int.",
  );

  const employees = await anonRows("employees", EMPLOYEE_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(employees.length === 2, `Seeded barber salon has 2 employees, got ${employees.length}.`);

  const links = await anonRows(
    "employee_services",
    EMPLOYEE_SERVICE_COLUMNS,
    "&salon_id=eq." + activeSalon,
  );
  assert(links.length === 8, `2 employees x 4 services = 8 links, got ${links.length}.`);

  const hours = await anonRows("working_hours", WORKING_HOURS_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(hours.length === 7, `Seeded schedule covers 7 ISO days, got ${hours.length}.`);
  // The LocalTime parser accepts exactly this shape. A change here breaks WorkingHour.fromJson.
  assert(
    /^\d{2}:\d{2}(:\d{2})?$/.test(String(hours[0].start_time)),
    `working_hours.start_time must be HH:mm[:ss], got ${hours[0].start_time}.`,
  );
  const sunday = hours.find((row) => row.day_of_week === 7);
  assert(sunday?.is_closed === true, "Sunday must be closed in the seed.");

  const settings = await anonRows("salon_settings", SETTINGS_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(settings.length === 1, "Every salon has exactly one salon_settings row.");
  assert(settings[0].timezone === "Europe/Sarajevo", "timezone must be readable by anon.");
  assert(settings[0].slot_step_minutes === 15, "slot_step_minutes must map from the seed.");

  // ---------------------------------------------------------------------------
  // 2. The catalog is public; appointments are not.
  // ---------------------------------------------------------------------------
  const appointments = await anonRequest("/rest/v1/appointments?select=id");
  assert(
    appointments.status === 401 || appointments.status === 403 ||
      (appointments.status === 200 && Array.isArray(appointments.body) && appointments.body.length === 0),
    `Anon must not read appointments, got HTTP ${appointments.status}: ${JSON.stringify(appointments.body)}`,
  );

  // Writes never come from the client — they go through book_appointment (task 05).
  const insert = await anonRequest("/rest/v1/appointments", {
    method: "POST",
    body: JSON.stringify({
      salon_id: activeSalon,
      service_id: "10000000-0000-4000-8000-000000000001",
      customer_id: "00000000-0000-4000-8000-000000000001",
      customer_name: "Anon",
      date: "2026-12-01",
      start_time: "09:00",
      end_time: "09:30",
    }),
  });
  assert(
    insert.status >= 400,
    `Anon insert into appointments must be rejected, got HTTP ${insert.status}.`,
  );

  // ---------------------------------------------------------------------------
  // 3. An inactive salon disappears from the public catalog.
  //
  // This is the reason SalonRepository maps "no row" to NotFoundError instead of treating
  // it as a network problem: RLS answers with emptiness, not with a 403.
  // ---------------------------------------------------------------------------
  await serviceRequest("/rest/v1/salons?id=eq." + otherSalon, {
    method: "PATCH",
    body: JSON.stringify({ status: "inactive" }),
  });
  try {
    const hidden = await anonRows("salons", SALON_COLUMNS, "&id=eq." + otherSalon);
    assert(hidden.length === 0, "An inactive salon must be invisible to anon.");

    const hiddenServices = await anonRows("services", SERVICE_COLUMNS, "&salon_id=eq." + otherSalon);
    assert(
      hiddenServices.length === 0,
      "Services of an inactive salon must be invisible too — private.salon_active guards them.",
    );
  } finally {
    await serviceRequest("/rest/v1/salons?id=eq." + otherSalon, {
      method: "PATCH",
      body: JSON.stringify({ status: "active" }),
    });
  }

  console.log(`Public catalog readable without a login: ${assertions} assertions passed.`);
} catch (error) {
  console.error("Public catalog test failed:", error instanceof Error ? error.message : error);
  Deno.exit(1);
}
