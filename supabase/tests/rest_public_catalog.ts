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
// Beauty salon: the only place left that seeds a service without a photo.
const beautySalon = "550e8400-e29b-41d4-a716-446655440001";
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
const SERVICE_COLUMNS = "id,salon_id,name,description,category,price,duration_minutes,image_url";
const EMPLOYEE_COLUMNS = "id,salon_id,name,role,bio,image_url,experience_years,is_active";
const EMPLOYEE_SERVICE_COLUMNS = "id,salon_id,employee_id,service_id";
const WORKING_HOURS_COLUMNS =
  "id,salon_id,employee_id,day_of_week,start_time,end_time,break_start_time,break_end_time,is_closed";
const REVIEW_COLUMNS = "id,salon_id,author_name,rating,comment,created_at";
const RATING_COLUMNS = "salon_id,average,total,count_5,count_4,count_3,count_2,count_1";
const POLICY_COLUMNS = "id,document,sort_order,title,body,updated_at";
const SALON_POLICY_COLUMNS = "id,salon_id,document,sort_order,title,body,updated_at";
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

  // Task 22: the new columns must reach `anon`. Grants in the init migration are
  // table-wide, not column-wide, so a new column joins the existing grant on its own — but
  // "should" is not "does". A column-level grant would make these invisible and the public
  // catalog would quietly lose its photos.
  assert(
    services.some((row) => typeof row.image_url === "string"),
    "services.image_url must be readable without a login — the catalog shows thumbnails.",
  );
  // The null case moved salons, so this assertion follows it. Task 22 left "Brada" without a
  // photo in the barber salon and asserted here; `e431229` ("fotografije za Barber Studio
  // Vitez") then gave every barber service a real photo, and this assertion had been failing
  // ever since — unnoticed, because CI is blocked and nobody reran the suite. The claim is
  // still worth making: an empty frame is a designed state, and a filtered-out row would mean
  // a salon with no photos loses its catalog. It just has to be made where the null actually
  // lives, which is now the beauty salon ("Pramenovi").
  const beautyServices = await anonRows("services", SERVICE_COLUMNS, "&salon_id=eq." + beautySalon);
  assert(
    beautyServices.some((row) => row.image_url === null),
    "A service without a photo must come back as null, not be filtered out — an empty frame is a designed state.",
  );

  const employees = await anonRows("employees", EMPLOYEE_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(employees.length === 2, `Seeded barber salon has 2 employees, got ${employees.length}.`);
  assert(
    employees.every((row) => typeof row.experience_years === "number"),
    "employees.experience_years must be readable without a login — the staff row reads '9 godina'.",
  );

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
  // 3. Reviews and the rating aggregate are readable without a token (task 20).
  //
  // The aggregate is the part worth testing here. `salon_rating_summary` collapses the whole
  // table into one row, so a policy gap does not show up as an extra row — it shows up as a
  // different number. The seed keeps one hidden 1-star review precisely so the leak has a
  // value: 4.8 is correct, 4.7 means anon reached a row it must not see.
  // ---------------------------------------------------------------------------
  const reviews = await anonRows("reviews", REVIEW_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(reviews.length === 25, `Anon must read 25 published reviews, got ${reviews.length}.`);
  assert(
    reviews.every((r) => typeof r.author_name === "string" && (r.author_name as string).length > 0),
    "Every review carries an author name — the screen has no anonymous row.",
  );
  assert(
    reviews.some((r) => r.comment === null),
    "Ratings without text must come through: they carry the histogram, not the list.",
  );
  assert(
    !reviews.some((r) => (r.author_name as string).startsWith("Sakriveni")),
    "A review with is_published=false must never reach anon.",
  );

  const summary = await anonRows("salon_rating_summary", RATING_COLUMNS, "&salon_id=eq." + activeSalon);
  assert(summary.length === 1, `Anon must read one aggregate row, got ${summary.length}.`);
  assert(
    Number(summary[0].average) === 4.8,
    `Aggregate average must be 4.8 without the hidden review, got ${summary[0].average}. ` +
      "4.7 means the view bypassed RLS — check security_invoker.",
  );
  assert(Number(summary[0].total) === 25, `Aggregate must count 25 ratings, got ${summary[0].total}.`);
  assert(
    [5, 4, 3, 2, 1].map((n) => Number(summary[0][`count_${n}`])).join(",") === "21,3,1,0,0",
    "Histogram must be 21/3/1/0/0, the shape 13-recenzije.png draws.",
  );

  // The beauty salon seeds no reviews at all. Empty state is a demo fixture, not just a test:
  // an empty aggregate must be no row, never a row of zeroes that renders as "0,0 od 5".
  const beautySummary = await anonRows("salon_rating_summary", RATING_COLUMNS, "&salon_id=eq." + beautySalon);
  assert(
    beautySummary.length === 0,
    "A salon without reviews has no aggregate row — the section hides instead of showing 0,0.",
  );

  const reviewInsert = await anonRequest("/rest/v1/reviews", {
    method: "POST",
    body: JSON.stringify({ salon_id: activeSalon, author_name: "Napadac", rating: 5 }),
  });
  assert(
    reviewInsert.status >= 400,
    `Anon insert into reviews must be rejected, got HTTP ${reviewInsert.status}. The screen is read-only.`,
  );

  // ---------------------------------------------------------------------------
  // 4. Terms and the privacy policy are readable without a token (task 21).
  //
  // This one has to work for anon or the app cannot ship: the store review opens
  // "Pravila korištenja" and "Politika privatnosti" on a fresh install, before any sign-in.
  // A policy that only works for a signed-in user fails review, and nothing in the app
  // itself would reveal it — the developer is always signed in.
  // ---------------------------------------------------------------------------
  const appTerms = await anonRows("app_policies", POLICY_COLUMNS, "&document=eq.terms&order=sort_order");
  assert(appTerms.length === 3, `Anon must read 3 platform terms sections, got ${appTerms.length}.`);

  // No `order=` on purpose: this asserts what the repository actually sends. Dart's
  // `PostgrestTransformBuilder.order` defaults to `ascending = false`, so `.order('sort_order')`
  // returns the document **backwards** — "Kontakt" renders as section 01 and "Ko obrađuje
  // podatke" as 09. That bug shipped once and no unit test saw it: mapping a row says nothing
  // about the order rows arrive in. PolicyRepository now sorts in Dart instead, and this
  // asserts the raw rows are the full set the sort is applied to.
  const privacy = await anonRows("app_policies", POLICY_COLUMNS, "&document=eq.privacy");
  assert(privacy.length === 9, `Anon must read 9 privacy sections, got ${privacy.length}.`);

  const privacyOrder = [...privacy]
    .sort((a, b) => Number(a.sort_order) - Number(b.sort_order))
    .map((row) => row.title);
  assert(
    privacyOrder[0] === "Ko obrađuje podatke" && privacyOrder[8] === "Kontakt",
    `Privacy must run from "Ko obrađuje podatke" to "Kontakt", got: ${privacyOrder.join(" · ")}`,
  );

  const salonTerms = await anonRows(
    "salon_policies",
    SALON_POLICY_COLUMNS,
    "&salon_id=eq." + activeSalon + "&order=sort_order",
  );
  assert(salonTerms.length === 3, `Anon must read 3 salon sections for the barber, got ${salonTerms.length}.`);

  // The merged order is what the screen numbers 01..06. Asserting it here and not only in
  // pgTAP is the point: PostgREST is where `order=` is actually applied, and a sort_order
  // collision between the two tables would show up as a shuffled legal document.
  const merged = [...appTerms, ...salonTerms]
    .sort((a, b) => Number(a.sort_order) - Number(b.sort_order))
    .map((row) => row.title)
    .join(" · ");
  assert(
    merged === "Zakazivanje · Otkazivanje · Kašnjenje · Cijene · Vaši podaci · Kontakt",
    `Merged terms must follow 15-pravila-koristenja.png, got: ${merged}`,
  );

  // The body keeps the placeholder; the screen fills it from salon_settings. If a seed ever
  // hardcodes the number, this fails — and it must, because cancel_appointment enforces 3 for
  // the barber and 6 for beauty while the handoff text says 2.
  const cancellation = salonTerms.find((row) => row.title === "Otkazivanje");
  assert(
    typeof cancellation?.body === "string" && cancellation.body.includes("{minCancelHours}"),
    "The cancellation section must carry {minCancelHours}, not a hardcoded number.",
  );

  // The beauty salon has no "Kontakt" section: no phone and no email in the seed. A shorter
  // document is a supported state, and it is seeded so the screen is proven against it.
  const beautyTerms = await anonRows("salon_policies", SALON_POLICY_COLUMNS, "&salon_id=eq." + beautySalon);
  assert(beautyTerms.length === 2, `Beauty must expose 2 salon sections, got ${beautyTerms.length}.`);

  const policyInsert = await anonRequest("/rest/v1/app_policies", {
    method: "POST",
    body: JSON.stringify({ document: "terms", sort_order: 99, title: "Napadac", body: "Tekst." }),
  });
  assert(
    policyInsert.status >= 400,
    `Anon insert into app_policies must be rejected, got HTTP ${policyInsert.status}.`,
  );

  // ---------------------------------------------------------------------------
  // 5. An inactive salon disappears from the public catalog.
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

    const hiddenPolicies = await anonRows("salon_policies", SALON_POLICY_COLUMNS, "&salon_id=eq." + otherSalon);
    assert(
      hiddenPolicies.length === 0,
      "Terms sections of an inactive salon must be invisible — same guard as the rest of the catalog.",
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
