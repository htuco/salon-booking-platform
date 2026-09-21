// Task 34: promjena radnog vremena i blokade u adminu mijenja ono sto klijent vidi.
//
// Ovo je jedini test koji spaja dva kraja: pgTAP dokazuje pravila unutar baze, ali ne
// prolazi kroz PostgREST, grantove i pravi JWT. DoD taska trazi bas to — „promjena se
// odmah vidi u klijentskoj app-i, dokazano upitom".
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Test radi samo nad lokalnim Supabaseom.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
if (!anon) throw new Error("Nedostaju lokalni kljucevi.");
const salon = "550e8400-e29b-41d4-a716-446655440000";
const serviceId = "10000000-0000-4000-8000-000000000001";
const employeeId = "20000000-0000-4000-8000-000000000001";
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

/// Sedmica sa istim vremenom svaki dan — ulaz za `set_working_hours`.
function sedmica(
  start: string,
  end: string,
  opts: { breakStart?: string; breakEnd?: string; closed?: boolean } = {},
) {
  return Array.from({ length: 7 }, (_, i) => ({
    day_of_week: i + 1,
    start_time: start,
    end_time: end,
    break_start_time: opts.breakStart ?? null,
    break_end_time: opts.breakEnd ?? null,
    is_closed: opts.closed ?? false,
  }));
}

/// Datum za koji se traze slotovi — dovoljno daleko da `min_advance_booking_hours` ne
/// pojede pocetak dana, i uvijek isti dan u sedmici nije bitan jer se pise svih sedam.
const datum = new Date(Date.now() + 8 * 86400000).toISOString().slice(0, 10);

const admin = await login("admin@barberstudiovitez.test");
const tudji = await login("admin@beautystudiotravnik.test");

/// Polazno stanje, da test ne ostavi salon izmijenjen za sljedeceg.
const polazno = await ok(
  `/rest/v1/working_hours?salon_id=eq.${salon}&employee_id=is.null` +
    `&select=day_of_week,start_time,end_time,break_start_time,break_end_time,is_closed` +
    `&order=day_of_week.asc`,
  admin,
);
let blokada: string | undefined;

async function slotovi() {
  const rows = await ok("/rest/v1/rpc/get_available_slots", null, "POST", {
    p_salon_id: salon,
    p_service_id: serviceId,
    p_date: datum,
    p_employee_id: employeeId,
  });
  return (rows as Array<{ start_time: string }>).map((r) =>
    r.start_time.slice(0, 5)
  );
}

try {
  // 1. Grant je stvarno oduzet: direktan upis vise ne prolazi kroz PostgREST.
  const direktno = await call("/rest/v1/working_hours", admin, "POST", {
    salon_id: salon,
    day_of_week: 1,
    start_time: "09:00",
    end_time: "17:00",
  });
  assert(
    direktno.status === 401 || direktno.status === 403,
    `Direktan upis radnog vremena mora pasti, dobio ${direktno.status}`,
  );
  const direktnaBlokada = await call("/rest/v1/blocked_slots", admin, "POST", {
    salon_id: salon,
    date: datum,
    start_time: "09:00",
    end_time: "10:00",
  });
  assert(
    direktnaBlokada.status === 401 || direktnaBlokada.status === 403,
    `Direktan upis blokade mora pasti, dobio ${direktnaBlokada.status}`,
  );

  // 2. Admin skrati radno vrijeme — klijent odmah vidi manje slotova.
  await ok("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: sedmica("09:00", "17:00"),
  });
  const puno = await slotovi();
  assert(puno.length > 0, "Otvoren dan mora imati slotova");
  assert(puno.includes("16:00"), "16:00 je unutar 09–17");

  await ok("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: sedmica("09:00", "12:00"),
  });
  const kratko = await slotovi();
  assert(
    kratko.length < puno.length && !kratko.includes("16:00"),
    "Skraceno radno vrijeme mora smanjiti ponudu klijentu",
  );

  // 3. Pauza izbija slotove iz sredine dana, ne sa kraja.
  await ok("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: sedmica("09:00", "17:00", {
      breakStart: "12:00",
      breakEnd: "13:00",
    }),
  });
  const saPauzom = await slotovi();
  assert(
    !saPauzom.includes("12:00") && !saPauzom.includes("12:30"),
    "Pauza mora ukloniti slotove iz svog intervala",
  );
  assert(
    saPauzom.includes("16:00"),
    "Pauza u podne ne smije dirati popodne",
  );

  // 4. Zatvoren dan ne nudi nista.
  await ok("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: sedmica("09:00", "17:00", { closed: true }),
  });
  assert((await slotovi()).length === 0, "Zatvoren dan nema slotova");

  // 5. Blokada oduzima svoj interval, i to kroz `rpc`, ne direktnim upisom.
  await ok("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: sedmica("09:00", "17:00"),
  });
  const prijeBlokade = await slotovi();
  const red = await ok("/rest/v1/rpc/create_blocked_slot", admin, "POST", {
    p_salon_id: salon,
    p_date: datum,
    p_start_time: "10:00",
    p_end_time: "11:00",
    p_reason: "  REST blokada  ",
    p_employee_id: null,
  });
  blokada = red.id;
  assert(red.reason === "REST blokada", "Razlog se normalizuje u bazi");
  const saBlokadom = await slotovi();
  assert(
    prijeBlokade.includes("10:00") && !saBlokadom.includes("10:00"),
    "Blokada mora ukloniti svoj interval iz ponude",
  );

  // Brisanje vraca slotove — dokaz da blokada nije nepovratna.
  await ok("/rest/v1/rpc/delete_blocked_slot", admin, "POST", {
    p_salon_id: salon,
    p_blocked_slot_id: blokada,
  });
  blokada = undefined;
  assert(
    (await slotovi()).includes("10:00"),
    "Brisanje blokade vraca slotove",
  );

  // 6. Tudji salon: ni pisanje ni citanje konflikata kroz pravi JWT.
  for (
    const [rpc, body] of [
      ["set_working_hours", {
        p_salon_id: salon,
        p_days: sedmica("09:00", "17:00"),
      }],
      ["create_blocked_slot", {
        p_salon_id: salon,
        p_date: datum,
        p_start_time: "09:00",
        p_end_time: "10:00",
      }],
      ["working_hours_conflicts", {
        p_salon_id: salon,
        p_employee_id: null,
        p_days: sedmica("09:00", "17:00"),
      }],
    ] as const
  ) {
    const r = await call(`/rest/v1/rpc/${rpc}`, tudji, "POST", body);
    assert(r.status >= 400, `${rpc} mora odbiti tudjeg admina`);
  }

  // 7. Anon ne smije nista od ovoga.
  const anonPokusaj = await call(
    "/rest/v1/rpc/set_working_hours",
    null,
    "POST",
    { p_salon_id: salon, p_days: sedmica("09:00", "17:00") },
  );
  assert(anonPokusaj.status >= 400, "Anon ne pise radno vrijeme");
} finally {
  // Vrati salon u polazno stanje: seed ostaje kakav je bio prije testa.
  if (blokada) {
    await call("/rest/v1/rpc/delete_blocked_slot", admin, "POST", {
      p_salon_id: salon,
      p_blocked_slot_id: blokada,
    });
  }
  await call("/rest/v1/rpc/set_working_hours", admin, "POST", {
    p_salon_id: salon,
    p_days: (polazno as Array<Record<string, unknown>>).map((d) => ({
      day_of_week: d.day_of_week,
      start_time: d.start_time,
      end_time: d.end_time,
      break_start_time: d.break_start_time,
      break_end_time: d.break_end_time,
      is_closed: d.is_closed,
    })),
  });
}

console.log(`rest_working_hours: ${checks} provjera proslo`);
