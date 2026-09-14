// Seed admin se stvarno prijavi i vidi samo svoj salon (task 23).
// deno run --allow-env --allow-net supabase/tests/rest_admin_login.ts
//
// **Zasto zaseban test, kad `rest_cross_salon_isolation.ts` vec pokriva izolaciju:** taj test
// pravi svoje korisnike kroz `/auth/v1/admin/users`, gdje GoTrue sam popuni sva polja. Ovdje se
// provjerava **seed red**, pisan rukom u `seed.sql` — a upravo tu je greska koja je ovaj test i
// izazvala: nullable text kolone (`confirmation_token`, `email_change`, ...) ostanu NULL, GoTrue
// ih skenira u Go `string`, i prijava pada sa `500 Database error querying schema`. Red pritom
// izgleda savrseno ispravno u `psql`, i svaki pgTAP test prolazi — jer pgTAP glumi JWT claimove
// preko `set_config`, a **nikad ne prolazi kroz GoTrue**.
//
// Drugim rijecima: ovo je jedini test u repou koji pada ako se u admin app-i ne moze prijaviti.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Admin login test may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
if (!anon) throw new Error("Set local Supabase anon key.");

const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const adminA = "admin@barberstudiovitez.test";
const adminB = "admin@beautystudiotravnik.test";
const lozinka = "admin123456";
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

async function call(path: string, token: string | null, options: RequestInit = {}, salon?: string) {
  const response = await fetch(url + path, {
    ...options,
    headers: {
      apikey: anon!,
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
  if (result.status >= 300) {
    throw new Error("HTTP " + result.status + " at " + path + ": " + JSON.stringify(result.body));
  }
  return result.body;
}

/** Prijava lozinkom, kroz isti put kojim ide i admin aplikacija. */
async function prijava(email: string) {
  const odgovor = await call("/auth/v1/token?grant_type=password", null, {
    method: "POST",
    body: JSON.stringify({ email, password: lozinka }),
  });
  assert(
    odgovor.status === 200,
    "Seed admin " + email + " se mora moci prijaviti, a GoTrue je vratio " +
      odgovor.status + ": " + JSON.stringify(odgovor.body) +
      " — provjeri jesu li nullable text kolone u auth.users prazan string, ne NULL.",
  );
  return odgovor.body.access_token as string;
}

/** Claimovi iz JWT-a, bez biblioteke — `private.is_admin()` cita bas ovo. */
function claimovi(token: string): Record<string, unknown> {
  const payload = token.split(".")[1];
  const dekodiran = atob(payload.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    payload.length + ((4 - (payload.length % 4)) % 4),
    "=",
  ));
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(dekodiran, (c) => c.charCodeAt(0))));
}

const tokenA = await prijava(adminA);
const tokenB = await prijava(adminB);

// 1. Token nosi oba claima koja `private.is_admin()` trazi. Red u `public.users` bez ovih
//    claimova daje admina koji se prijavi ali ne vidi nijedan red — prazan ekran koji
//    izgleda kao prazna baza, a zapravo je pogresna konfiguracija.
const cA = claimovi(tokenA).app_metadata as Record<string, unknown>;
assert(cA.role === "salon_admin", "JWT mora nositi app_metadata.role = salon_admin.");
assert(cA.salon_id === salonA, "JWT mora nositi salon_id salona A.");
const cB = claimovi(tokenB).app_metadata as Record<string, unknown>;
assert(cB.salon_id === salonB, "JWT admina B mora nositi salon B.");

// 2. Drugi uslov: red u `public.users`. Admin vidi **samo svoj** red.
const jaA = await ok("/rest/v1/users?select=id,salon_id,role", tokenA);
assert(jaA.length === 1, "Admin A vidi tacno svoj red u public.users, dobio " + jaA.length + ".");
assert(jaA[0].salon_id === salonA, "Red admina A mora nositi salon A.");

// 3. Termini: brojevi su **namjerno razliciti** (A ima 3, B ima 2). Da su isti, zamijenjen
//    token bi prosao neprimjeceno kroz brojac.
const terminiA = await ok("/rest/v1/appointments?select=id,salon_id", tokenA);
const terminiB = await ok("/rest/v1/appointments?select=id,salon_id", tokenB);
assert(terminiA.length === 3, "Admin A vidi tri termina iz seeda, dobio " + terminiA.length + ".");
assert(terminiB.length === 2, "Admin B vidi dva termina iz seeda, dobio " + terminiB.length + ".");
assert(
  terminiA.every((t: Record<string, unknown>) => t.salon_id === salonA),
  "Nijedan termin koji vidi admin A ne smije biti iz drugog salona.",
);

// 4. Negativan smjer: eksplicitan filter po tudjem salonu vraca prazno, ne gresku.
const tudji = await ok("/rest/v1/appointments?select=id&salon_id=eq." + salonB, tokenA);
assert(tudji.length === 0, "Admin A ne smije procitati nijedan termin salona B.");

// 5. Header bira kontekst, **ne daje clanstvo** (ADR-0003). Admin A koji tvrdi da je u salonu
//    B i dalje vidi svoja tri termina — ne pet, i ne dva.
const lazniKontekst = await ok("/rest/v1/appointments?select=id,salon_id", tokenA, {}, salonB);
assert(
  lazniKontekst.length === 3 &&
    lazniKontekst.every((t: Record<string, unknown>) => t.salon_id === salonA),
  "x-salon-id salona B ne smije promijeniti sta admin A vidi.",
);

// 6. Pisanje u tudji salon pada na `with check`, ne prolazi tiho.
const upis = await call("/rest/v1/customers", tokenA, {
  method: "POST",
  body: JSON.stringify({ salon_id: salonB, name: "Ubaceni iz drugog salona" }),
});
assert(upis.status === 403, "Upis u tudji salon mora pasti sa 403, dobio " + upis.status + ".");

// 7. Bez tokena se ne vidi nista. Odgovor je **401, a ne prazan niz**: `anon` nema ni
//    `select` grant nad `appointments`, pa PostgREST odbije prije nego RLS uopste dodje na
//    red. To je jaci oblik zastite od prazne liste — grant i politika su dvije brave, i
//    ovdje drzi prva. Ocekivanje u testu je ispravljeno prema onome sto server stvarno
//    radi; prvo je bilo pisano napamet, kao prazan niz.
const bezTokena = await call("/rest/v1/appointments?select=id", null);
assert(
  bezTokena.status === 401,
  "anon ne smije citati termine; ocekivan 401 bez granta, dobio " + bezTokena.status + ".",
);

console.log(
  "Admin prijava i izolacija prolaze: " + assertions + " asercija, dva seed admina kroz GoTrue.",
);
