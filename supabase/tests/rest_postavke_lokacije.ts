// Task 36: postavke koje vlasnik promijeni u adminu vidi klijentska app, bez novog builda.
//
// pgTAP (`014`) dokazuje pravila **unutar** baze. Ovo je jedini test koji ide istim putem
// kojim ide aplikacija: pravi JWT, PostgREST, grantovi. DoD taska trazi bas to — „promjena
// se vidi bez novog builda" je tvrdnja o toj putanji, ne o funkciji u bazi.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Test radi samo nad lokalnim Supabaseom.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
if (!anon) throw new Error("Nedostaju lokalni kljucevi.");

const salon = "550e8400-e29b-41d4-a716-446655440000";
const drugiSalon = "550e8400-e29b-41d4-a716-446655440001";

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
  salonHeader = salon,
) {
  const r = await fetch(url + path, {
    method,
    headers: {
      apikey: anon!,
      ...(token ? { Authorization: "Bearer " + token } : {}),
      "Content-Type": "application/json",
      "x-salon-id": salonHeader,
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

const admin = await login("admin@barberstudiovitez.test");
const tudjiAdmin = await login("admin@beautystudiotravnik.test");

// Polazno stanje, da se seed vrati kakav je bio.
const polazniSalon =
  (await ok(`/rest/v1/salons?id=eq.${salon}&select=*`, admin))[0];
const polaznePostavke =
  (await ok(`/rest/v1/salon_settings?salon_id=eq.${salon}&select=*`, admin))[0];

try {
  // -------------------------------------------------------------------------
  // 1. Direktan upis vise ne prolazi — ni za vlasnika
  // -------------------------------------------------------------------------
  // Do ovog taska je `salon_settings` imao pun grant i `staff_manage` politiku, pa je
  // ovaj `PATCH` **prolazio** i zaobilazio validaciju. Sada je jedini put `rpc`.
  const direktno = await call(
    `/rest/v1/salon_settings?salon_id=eq.${salon}`,
    admin,
    "PATCH",
    { min_cancel_hours: 0 },
  );
  assert(
    direktno.status >= 400,
    `Direktan PATCH postavki mora pasti, dobio ${direktno.status}`,
  );

  const direktnoSalon = await call(
    `/rest/v1/salons?id=eq.${salon}`,
    admin,
    "PATCH",
    { name: "Preuzeto direktnim upisom" },
  );
  assert(
    direktnoSalon.status >= 400,
    `Direktan PATCH salona mora pasti, dobio ${direktnoSalon.status}`,
  );

  // -------------------------------------------------------------------------
  // 2. Kontakt podaci: vlasnik pise, anon cita promjenu
  // -------------------------------------------------------------------------
  await ok("/rest/v1/rpc/update_salon_contact", admin, "POST", {
    p_salon_id: salon,
    p_name: "Barber Studio Vitez",
    p_address: "Nova adresa 7",
    p_city: "Vitez",
    p_description: "Opis iz admina.",
    p_phone: "030 999 111",
    p_email: "novi@barberstudiovitez.test",
    p_instagram_url: "",
    p_facebook_url: "https://facebook.com/barberstudiovitez",
  });

  // **Bez tokena** — klijentska app cita salon prije prijave (`public_salons`). Ovo je
  // cijeli smisao taska: promjena je vidljiva bez novog builda.
  const javni = (await ok(
    `/rest/v1/salons?id=eq.${salon}&select=name,address,phone,email,instagram_url,facebook_url`,
    null,
  ))[0];
  assert(
    javni.address === "Nova adresa 7",
    `Anon vidi novu adresu, dobio ${javni.address}`,
  );
  assert(
    javni.phone === "030 999 111",
    `Anon vidi novi telefon, dobio ${javni.phone}`,
  );
  // Prazan string je postao NULL, ne prazan string.
  assert(
    javni.instagram_url === null,
    `Prazan Instagram je NULL, dobio ${JSON.stringify(javni.instagram_url)}`,
  );
  // Facebook **stranica** ostaje kontakt podatak (ADR-0011).
  assert(
    javni.facebook_url === "https://facebook.com/barberstudiovitez",
    "Facebook stranica salona ostaje",
  );

  // Platformska polja nisu ni parametri — boja i slug su netaknuti.
  const platformska = (await ok(
    `/rest/v1/salons?id=eq.${salon}&select=primary_color,slug`,
    null,
  ))[0];
  assert(
    platformska.primary_color === polazniSalon.primary_color,
    "Boja se ne mijenja iz admina — dolazi iz tenant.yaml",
  );
  assert(platformska.slug === polazniSalon.slug, "Slug ostaje platformski");

  // -------------------------------------------------------------------------
  // 3. Booking pravila: vlasnik pise, anon cita
  // -------------------------------------------------------------------------
  await ok("/rest/v1/rpc/update_salon_settings", admin, "POST", {
    p_salon_id: salon,
    p_booking_mode: "auto",
    p_booking_granularity: "exact_slot",
    p_buffer_minutes: 20,
    p_slot_step_minutes: 30,
    p_min_advance_booking_hours: 1,
    p_max_advance_booking_days: 45,
    p_min_cancel_hours: 9,
    p_require_staff_choice: true,
    p_show_prices_in_app: false,
    p_allow_guest_booking: true,
  });

  const javnePostavke = (await ok(
    `/rest/v1/salon_settings?salon_id=eq.${salon}&select=booking_mode,min_cancel_hours,buffer_minutes,allow_guest_booking,timezone`,
    null,
  ))[0];
  assert(
    javnePostavke.booking_mode === "auto",
    `Anon vidi novi nacin potvrde, dobio ${javnePostavke.booking_mode}`,
  );
  assert(
    javnePostavke.min_cancel_hours === 9,
    `Anon vidi novi rok otkazivanja, dobio ${javnePostavke.min_cancel_hours}`,
  );
  assert(
    javnePostavke.allow_guest_booking === true,
    "Anon vidi da je gostujuce zakazivanje ukljuceno",
  );
  // Zona nije parametar funkcije i ostaje ista.
  assert(
    javnePostavke.timezone === polaznePostavke.timezone,
    "Vremenska zona se ne mijenja iz admina",
  );

  // Validacija stize kao poruka, ne kao `23514` sa imenom constrainta.
  const losa = await call("/rest/v1/rpc/update_salon_settings", admin, "POST", {
    p_salon_id: salon,
    p_booking_mode: "poluautomatski",
    p_booking_granularity: "exact_slot",
    p_buffer_minutes: 5,
    p_slot_step_minutes: 15,
    p_min_advance_booking_hours: 2,
    p_max_advance_booking_days: 30,
    p_min_cancel_hours: 3,
    p_require_staff_choice: false,
    p_show_prices_in_app: true,
    p_allow_guest_booking: false,
  });
  assert(
    losa.status >= 400 &&
      JSON.stringify(losa.body).includes("Nepoznat nacin potvrde"),
    `Nepoznat booking_mode daje citljivu gresku, dobio ${losa.status} ${
      JSON.stringify(losa.body)
    }`,
  );

  // -------------------------------------------------------------------------
  // 4. Tudji salon — header ne pomaze
  // -------------------------------------------------------------------------
  // `x-salon-id` je postavljen na salon B, a token je vlasnika A: header bira kontekst
  // citanja, clanstvo ne daje (ADR-0003).
  const tudje = await call(
    "/rest/v1/rpc/update_salon_contact",
    admin,
    "POST",
    { p_salon_id: drugiSalon, p_name: "Preuzeto", p_address: "", p_city: "Travnik" },
    drugiSalon,
  );
  assert(
    tudje.status >= 400,
    `Vlasnik A ne mijenja salon B ni sa njegovim headerom, dobio ${tudje.status}`,
  );

  const tudjePostavke = await call(
    "/rest/v1/rpc/update_salon_settings",
    admin,
    "POST",
    {
      p_salon_id: drugiSalon,
      p_booking_mode: "auto",
      p_booking_granularity: "exact_slot",
      p_buffer_minutes: 5,
      p_slot_step_minutes: 15,
      p_min_advance_booking_hours: 2,
      p_max_advance_booking_days: 30,
      p_min_cancel_hours: 0,
      p_require_staff_choice: false,
      p_show_prices_in_app: true,
      p_allow_guest_booking: false,
    },
    drugiSalon,
  );
  assert(
    tudjePostavke.status >= 400,
    `Vlasnik A ne mijenja postavke salona B, dobio ${tudjePostavke.status}`,
  );

  // Salon B je stvarno netaknut — provjereno njegovim vlasnikom.
  const bStanje = (await ok(
    `/rest/v1/salon_settings?salon_id=eq.${drugiSalon}&select=min_cancel_hours`,
    tudjiAdmin,
  ))[0];
  assert(
    bStanje.min_cancel_hours === 6,
    `Rok salona B je netaknut, dobio ${bStanje.min_cancel_hours}`,
  );

  // -------------------------------------------------------------------------
  // 5. `app_policies` ostaje kod platforme (ADR-0009)
  // -------------------------------------------------------------------------
  // Negativan test taska 21, kroz pravi PostgREST: vlasnik salona ne smije dotaci tekst
  // koji obavezuje firmu pod cijim imenom app stoji u storeu.
  const pravila = await call("/rest/v1/app_policies", admin, "POST", {
    document: "terms",
    sort_order: 97,
    title: "Moje pravilo",
    body: "Tekst salona.",
  });
  assert(
    pravila.status >= 400,
    `Vlasnik ne pise platformska pravila, dobio ${pravila.status}`,
  );

  // Njegove sekcije **jesu** njegove i idu direktnim upisom (v. migracija).
  const moja = await call("/rest/v1/salon_policies?select=id", admin, "POST", {
    salon_id: salon,
    sort_order: 97,
    title: "Kasnjenje",
    body: "Cekamo vas 10 minuta.",
  });
  assert(
    moja.status < 300,
    `Vlasnik pise svoju sekciju, dobio ${moja.status} ${
      JSON.stringify(moja.body)
    }`,
  );
  await call(
    `/rest/v1/salon_policies?salon_id=eq.${salon}&sort_order=eq.97`,
    admin,
    "DELETE",
  );

  // Anon ne pise nista.
  const anonPokusaj = await call(
    "/rest/v1/rpc/update_salon_settings",
    null,
    "POST",
    {
      p_salon_id: salon,
      p_booking_mode: "auto",
      p_booking_granularity: "exact_slot",
      p_buffer_minutes: 5,
      p_slot_step_minutes: 15,
      p_min_advance_booking_hours: 2,
      p_max_advance_booking_days: 30,
      p_min_cancel_hours: 0,
      p_require_staff_choice: false,
      p_show_prices_in_app: true,
      p_allow_guest_booking: false,
    },
  );
  assert(
    anonPokusaj.status >= 400,
    `Anon ne mijenja booking pravila, dobio ${anonPokusaj.status}`,
  );
} finally {
  // Vrati salon u polazno stanje: seed ostaje kakav je bio prije testa.
  await call("/rest/v1/rpc/update_salon_contact", admin, "POST", {
    p_salon_id: salon,
    p_name: polazniSalon.name,
    p_address: polazniSalon.address,
    p_city: polazniSalon.city,
    p_description: polazniSalon.description,
    p_phone: polazniSalon.phone,
    p_email: polazniSalon.email,
    p_instagram_url: polazniSalon.instagram_url,
    p_facebook_url: polazniSalon.facebook_url,
  });
  await call("/rest/v1/rpc/update_salon_settings", admin, "POST", {
    p_salon_id: salon,
    p_booking_mode: polaznePostavke.booking_mode,
    p_booking_granularity: polaznePostavke.booking_granularity,
    p_buffer_minutes: polaznePostavke.buffer_minutes,
    p_slot_step_minutes: polaznePostavke.slot_step_minutes,
    p_min_advance_booking_hours: polaznePostavke.min_advance_booking_hours,
    p_max_advance_booking_days: polaznePostavke.max_advance_booking_days,
    p_min_cancel_hours: polaznePostavke.min_cancel_hours,
    p_require_staff_choice: polaznePostavke.require_staff_choice,
    p_show_prices_in_app: polaznePostavke.show_prices_in_app,
    p_allow_guest_booking: polaznePostavke.allow_guest_booking,
  });
}

console.log(`rest_postavke_lokacije: ${checks} provjera proslo`);
