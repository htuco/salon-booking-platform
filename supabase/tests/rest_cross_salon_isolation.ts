// Isti covjek, dva salona: dokaz da salon A ne vidi da je njegov klijent i klijent salona B.
// deno run --allow-env --allow-net supabase/tests/rest_cross_salon_isolation.ts
//
// **Ovo je poslovni rizik, ne tehnicka formalnost** (task 15): salon koji otkrije da mu
// konkurencija vidi klijentelu otkazuje ugovor. Zato se ne testira samo direktan upit nego i
// putevi kojima curenje stvarno prolazi — join, embed, i filter po `auth_identity_id`, koji
// admin **zna** jer stoji u njegovom vlastitom redu.
//
// pgTAP ovo ne moze dokazati do kraja: on vrti SQL kao rola, a ovdje je pitanje sta vrati
// **PostgREST** na stvaran token i stvaran `x-salon-id` header.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Cross-salon fixtures may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service-role keys.");

const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const uslugaA = "10000000-0000-4000-8000-000000000001"; // Barber: Musko sisanje
const uslugaB = "10000000-0000-4000-8000-000000000005"; // Beauty: prva usluga

const users: string[] = [];
const staff: string[] = [];
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
  return { status: response.status, body: raw ? JSON.parse(raw) : null };
}

async function ok(path: string, token: string | null, options: RequestInit = {}, salon?: string) {
  const result = await call(path, token, options, salon);
  // Prag je 300, ne 400: PostgREST na dvosmislen embed vraca **300** sa `PGRST201` u
  // tijelu. Sa pragom 400 bi taj odgovor prosao kao uspjeh i test bi se srusio kasnije,
  // na `.every is not a function`, umjesto da kaze sta je stvarno vratio.
  if (result.status >= 300) {
    throw new Error("HTTP " + result.status + " at " + path + ": " + JSON.stringify(result.body));
  }
  return result.body;
}

const rpc = (args: Record<string, unknown>): RequestInit => ({
  method: "POST",
  body: JSON.stringify(args),
});

/** Pravi korisnika i vraca njegov stvaran JWT. */
async function prijaviSe(appMetadata: Record<string, unknown> = {}, ime = "Test") {
  const email = "izolacija-" + crypto.randomUUID() + "@example.test";
  const password = crypto.randomUUID() + "Aa1!";
  const user = await ok("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: ime },
      app_metadata: appMetadata,
    }),
  });
  const session = await ok("/auth/v1/token?grant_type=password", anon, {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  return { id: user.id as string, email, token: session.access_token as string };
}

/** Prvi slobodan slot za uslugu u salonu, gledan kroz stvaran token. */
async function prviSlot(token: string, salon: string, usluga: string) {
  const danas = new Date();
  const dani = await ok(
    "/rest/v1/rpc/get_available_dates",
    token,
    rpc({
      p_salon_id: salon,
      p_service_id: usluga,
      p_from: danas.toISOString().slice(0, 10),
      p_to: new Date(danas.getTime() + 20 * 864e5).toISOString().slice(0, 10),
    }),
    salon,
  );
  assert(Array.isArray(dani) && dani.length > 0, "Seed mora imati slobodan dan u salonu " + salon);
  const dan: string = dani[0].available_date ?? dani[0];

  const slotovi = await ok(
    "/rest/v1/rpc/get_available_slots",
    token,
    rpc({ p_salon_id: salon, p_service_id: usluga, p_date: dan }),
    salon,
  );
  assert(Array.isArray(slotovi) && slotovi.length > 0, "Seed mora imati slobodan slot u salonu " + salon);
  return { dan, slot: slotovi[0] };
}

try {
  // ---------------------------------------------------------------------------
  // Jedan covjek, dva salona, dva termina
  // ---------------------------------------------------------------------------
  const klijent = await prijaviSe({ providers: ["email"] }, "Isti Covjek");
  users.push(klijent.id);

  const identitet = await ok(
    "/rest/v1/auth_identities?select=*&supabase_user_id=eq." + klijent.id,
    service,
  );
  assert(identitet.length === 1, "Trigger mora napraviti tacno jedan globalan identitet.");
  identities.push(identitet[0].id);

  const uA = await ok("/rest/v1/rpc/ensure_customer", klijent.token, rpc({ p_salon_id: salonA }), salonA);
  const uB = await ok("/rest/v1/rpc/ensure_customer", klijent.token, rpc({ p_salon_id: salonB }), salonB);
  customers.push(uA.id, uB.id);

  assert(uA.id !== uB.id, "Isti identitet u dva salona mora dati dva odvojena customers reda.");
  assert(uA.auth_identity_id === uB.auth_identity_id, "Oba reda pokazuju na isti globalni identitet.");

  const a = await prviSlot(klijent.token, salonA, uslugaA);
  const terminA = await ok(
    "/rest/v1/rpc/book_appointment",
    klijent.token,
    rpc({
      p_salon_id: salonA, p_customer_id: uA.id, p_service_id: uslugaA,
      p_date: a.dan, p_start_time: a.slot.start_time, p_employee_id: a.slot.employee_id,
    }),
    salonA,
  );
  appointments.push(terminA.id);

  const b = await prviSlot(klijent.token, salonB, uslugaB);
  const terminB = await ok(
    "/rest/v1/rpc/book_appointment",
    klijent.token,
    rpc({
      p_salon_id: salonB, p_customer_id: uB.id, p_service_id: uslugaB,
      p_date: b.dan, p_start_time: b.slot.start_time, p_employee_id: b.slot.employee_id,
    }),
    salonB,
  );
  appointments.push(terminB.id);

  // ---------------------------------------------------------------------------
  // Klijent: header bira kontekst, i vidi se samo taj kontekst
  // ---------------------------------------------------------------------------
  const mojiA = await ok("/rest/v1/customers?select=*", klijent.token, {}, salonA);
  assert(mojiA.length === 1 && mojiA[0].id === uA.id, "Klijent u kontekstu A vidi samo svoj A red.");

  const terminiA = await ok("/rest/v1/appointments?select=*", klijent.token, {}, salonA);
  assert(terminiA.length === 1 && terminiA[0].id === terminA.id,
    "Klijent u kontekstu A ne vidi svoj termin iz salona B.");

  const terminiB = await ok("/rest/v1/appointments?select=*", klijent.token, {}, salonB);
  assert(terminiB.length === 1 && terminiB[0].id === terminB.id,
    "Prebacivanje konteksta pokazuje samo termine tog salona.");

  // Filter u upitu ne moze zaobici kontekst — RLS se primjenjuje prije `where`-a.
  const preskok = await ok(
    "/rest/v1/appointments?select=*&salon_id=eq." + salonB, klijent.token, {}, salonA);
  assert(preskok.length === 0, "Filter po salon_id ne moze izvuci termin iz drugog konteksta.");

  // ---------------------------------------------------------------------------
  // Admin salona A: ono zbog cega ovaj test postoji
  // ---------------------------------------------------------------------------
  const adminA = await prijaviSe({ role: "salon_admin", salon_id: salonA }, "Vlasnik A");
  users.push(adminA.id);
  await ok("/rest/v1/users", service, {
    method: "POST",
    body: JSON.stringify({
      id: adminA.id, salon_id: salonA, name: "Vlasnik A", email: adminA.email, role: "salon_admin",
    }),
  });
  staff.push(adminA.id);

  const sviKlijenti = await ok("/rest/v1/customers?select=*", adminA.token, {}, salonA);
  assert(sviKlijenti.every((c: Record<string, unknown>) => c.salon_id === salonA),
    "Admin A ne smije dobiti nijedan red iz drugog salona.");
  assert(sviKlijenti.some((c: Record<string, unknown>) => c.id === uA.id),
    "Admin A mora vidjeti svog klijenta — inace test prolazi iz pogresnog razloga.");
  assert(!sviKlijenti.some((c: Record<string, unknown>) => c.id === uB.id),
    "Admin A ne smije vidjeti red istog covjeka iz salona B.");

  // Direktno po `id`-u: admin ga ne bi trebao znati, ali pretpostavimo da ga je nagadjao.
  const poId = await ok("/rest/v1/customers?select=*&id=eq." + uB.id, adminA.token, {}, salonA);
  assert(poId.length === 0, "Tudji customers red se ne smije dobiti ni po tacnom id-u.");

  // **Najopasniji put**: admin zna `auth_identity_id` iz svog reda i pita po njemu.
  // Ako ovo propusti, admin salona A moze nabrojati sve salone u kojima je njegov klijent.
  const poIdentitetu = await ok(
    "/rest/v1/customers?select=*&auth_identity_id=eq." + identitet[0].id, adminA.token, {}, salonA);
  assert(poIdentitetu.length === 1 && poIdentitetu[0].salon_id === salonA,
    "Filter po auth_identity_id ne smije otkriti da je isti covjek klijent i drugog salona.");

  // Curenje kroz **embed** je cesce od curenja kroz direktan upit.
  //
  // Veza se mora imenovati: `customers(*)` je dvosmisleno jer `appointments` ima **dva**
  // kompozitna FK-a ka `customers` (`salon_id,customer_id` i `salon_id,customer_id,
  // auth_identity_id`), pa PostgREST vrati 300/`PGRST201`. To je usput i prva prepreka
  // napadacu — ali prepreka koja samo trazi da procita poruku o gresci, pa se ispod
  // testira **imenovana** veza, tacno onako kako bi je on napisao.
  const sviTermini = await ok(
    "/rest/v1/appointments?select=*,customers!appointments_salon_id_customer_id_fkey(*)",
    adminA.token, {}, salonA);
  assert(sviTermini.every((t: Record<string, unknown>) => t.salon_id === salonA),
    "Embed na appointments ne smije povuci termin drugog salona.");
  for (const t of sviTermini) {
    const c = (t as Record<string, unknown>).customers as Record<string, unknown> | null;
    assert(!c || c.salon_id === salonA, "Embed-ovan customers red mora pripadati salonu A.");
  }
  assert(!sviTermini.some((t: Record<string, unknown>) => t.id === terminB.id),
    "Termin iz salona B ne smije proci kroz join.");

  // Header ne daje clanstvo: admin A koji tvrdi da je u salonu B i dalje vidi samo A.
  const lazniKontekst = await ok("/rest/v1/customers?select=*", adminA.token, {}, salonB);
  assert(lazniKontekst.every((c: Record<string, unknown>) => c.salon_id === salonA),
    "x-salon-id bira kontekst, ne daje clanstvo — admin A ostaje admin A.");
  assert(!lazniKontekst.some((c: Record<string, unknown>) => c.id === uB.id),
    "Promjena headera ne otvara klijente salona B.");

  // ---------------------------------------------------------------------------
  // Putevi koje otvara modul klijenata (task 35)
  // ---------------------------------------------------------------------------
  //
  // Gornje asercije pokrivaju upit bez filtera, upit po `id`-u i upit po
  // `auth_identity_id`. Ekran `/clients` uvodi dva puta kojih tamo nema, i oba su
  // neugodna na isti nacin: **ne trazi se tudji red, nego se salje uzorak** — pa
  // curenje ne bi izgledalo kao napad nego kao klijent koji se pojavio niotkuda.

  // Pretraga po imenu. Admin A trazi **tacno ime covjeka** koje zna iz svog reda;
  // salon B ima red sa istim imenom. Tacno jedan smije doci nazad.
  const poImenu = await ok(
    "/rest/v1/customers?select=*&name=ilike.*Isti%20Covjek*", adminA.token, {}, salonA);
  assert(poImenu.length === 1 && poImenu[0].id === uA.id,
    "Pretraga po imenu vraca samo red iz salona A, iako isto ime postoji i u salonu B.");

  // Pretraga po telefonu ide istim `or` izrazom kao u `StaffCustomerRepository`.
  // Testira se **cijeli izraz**, ne jedna njegova strana: `or` koji bi procurio
  // pogrijesio bi bas na drugoj grani, koju pojedinacan filter ne bi ni dotakao.
  const poIzrazu = await ok(
    "/rest/v1/customers?select=*&or=(name.ilike.*Isti%20Covjek*,phone.ilike.*Isti%20Covjek*)",
    adminA.token, {}, salonA);
  assert(poIzrazu.every((c: Record<string, unknown>) => c.salon_id === salonA),
    "`or` pretraga ne smije propustiti red drugog salona ni kroz jednu granu.");
  assert(!poIzrazu.some((c: Record<string, unknown>) => c.id === uB.id),
    "Red istog covjeka iz salona B ne smije doci kroz pretragu.");

  // Prazna pretraga je i dalje pretraga: RLS vrijedi i kad filtera nema.
  const praznaPretraga = await ok(
    "/rest/v1/customers?select=*&name=ilike.**", adminA.token, {}, salonA);
  assert(praznaPretraga.every((c: Record<string, unknown>) => c.salon_id === salonA),
    "Uzorak koji pogadja sve redove i dalje vraca samo salon A.");

  // **Obrnuti embed**: profil klijenta trazi njegovu istoriju. Ovdje se ne pita
  // „ciji je termin" nego „ciji je klijent", pa je smjer curenja obrnut od onog
  // koji gornji blok pokriva.
  //
  // Veza se opet mora imenovati, iz istog razloga i sa istim ishodom (300/`PGRST201`).
  const saIstorijom = await ok(
    "/rest/v1/customers?select=*,appointments!appointments_salon_id_customer_id_fkey(*)",
    adminA.token, {}, salonA);
  assert(saIstorijom.every((c: Record<string, unknown>) => c.salon_id === salonA),
    "Embed na customers ne smije povuci klijenta drugog salona.");
  for (const c of saIstorijom) {
    const termini = (c as Record<string, unknown>).appointments as Record<string, unknown>[] | null;
    for (const t of termini ?? []) {
      assert(t.salon_id === salonA, "Embed-ovan termin mora pripadati salonu A.");
      assert(t.id !== terminB.id, "Termin iz salona B ne smije doci kroz embed na customers.");
    }
  }

  // Isti embed, ali trazen **za tacan tudji `id`**: prazna lista, ne red bez termina.
  const tudjiSaIstorijom = await ok(
    "/rest/v1/customers?select=*,appointments!appointments_salon_id_customer_id_fkey(*)&id=eq." + uB.id,
    adminA.token, {}, salonA);
  assert(tudjiSaIstorijom.length === 0,
    "Embed po tacnom id-u tudjeg klijenta ne smije vratiti nista.");

  // Istorija kao zaseban upit — tako je stvarno cita `StaffCustomerRepository`.
  // `customer_id` je tudji, i admin ga ovdje **zna**, jer ga je test maloprije imao.
  const tudjaIstorija = await ok(
    "/rest/v1/appointments?select=*&customer_id=eq." + uB.id, adminA.token, {}, salonA);
  assert(tudjaIstorija.length === 0,
    "Istorija tudjeg klijenta se ne smije dobiti ni po tacnom customer_id-u.");

  // Globalni identitet je klijentov, ne salonov.
  const identitetiZaAdmina = await ok("/rest/v1/auth_identities?select=*", adminA.token, {}, salonA);
  assert(identitetiZaAdmina.length === 0,
    "Admin ne cita auth_identities — inace bi imao spisak ljudi izvan svog salona.");

  console.log("Izolacija izmedju salona prolazi: " + assertions + " asercija, tri stvarna JWT-a.");
} finally {
  for (const id of appointments) await call("/rest/v1/appointments?id=eq." + id, service, { method: "DELETE" });
  for (const id of customers) await call("/rest/v1/customers?id=eq." + id, service, { method: "DELETE" });
  for (const id of staff) await call("/rest/v1/users?id=eq." + id, service, { method: "DELETE" });
  for (const id of identities) await call("/rest/v1/auth_identities?id=eq." + id, service, { method: "DELETE" });
  for (const id of users) await call("/auth/v1/admin/users/" + id, service, { method: "DELETE" });
}
