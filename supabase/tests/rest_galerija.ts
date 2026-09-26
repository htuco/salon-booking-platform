// Galerija, logo i cover kroz stvaran PostgREST i Storage API (task 50).
// deno run --allow-env --allow-net supabase/tests/rest_galerija.ts
//
// pgTAP (`023_galerija_logo_cover.test.sql`) mjeri funkcije u izolaciji. Ovdje se vidi ono sto
// ekran stvarno radi: upload u bucket, pa javni URL koji Storage vrati ide u rpc — i klijent
// bez tokena ga procita. Uz to i oblik konflikta: `PT409` mora stici kao HTTP 409, jer po
// tome admin zna da galeriju treba ponovo ucitati.
//
// Test vraca zatečeno stanje: cover se isprobava na beautyju (seed nema cover, pa se vraca na
// `null`), a galerija na barberu samo dodaje pa uklanja svoju sliku — vanjske seed slike rpc
// ne bi primio nazad kao nove.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Galerija test may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
if (!anon) throw new Error("Set local Supabase anon key.");

const bucket = "salon-media";
const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const lozinka = "admin123456";
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

async function prijava(email: string) {
  const r = await fetch(url + "/auth/v1/token?grant_type=password", {
    method: "POST",
    headers: { apikey: anon!, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: lozinka }),
  });
  const body = await r.json();
  assert(r.status === 200, "Prijava " + email + " vratila " + r.status + ": " + JSON.stringify(body));
  return body.access_token as string;
}

async function upload(token: string, path: string) {
  const r = await fetch(url + "/storage/v1/object/" + bucket + "/" + path, {
    method: "POST",
    headers: { apikey: anon!, Authorization: "Bearer " + token, "Content-Type": "image/png" },
    body: png,
  });
  await r.body?.cancel();
  assert(r.status === 200, "Upload " + path + " vratio " + r.status);
  return url + "/storage/v1/object/public/" + bucket + "/" + path;
}

async function brisi(token: string, paths: string[]) {
  const r = await fetch(url + "/storage/v1/object/" + bucket, {
    method: "DELETE",
    headers: { apikey: anon!, Authorization: "Bearer " + token, "Content-Type": "application/json" },
    body: JSON.stringify({ prefixes: paths }),
  });
  await r.body?.cancel();
}

async function rpc(token: string | null, fn: string, args: Record<string, unknown>, salon: string) {
  const r = await fetch(url + "/rest/v1/rpc/" + fn, {
    method: "POST",
    headers: {
      apikey: anon!,
      Authorization: "Bearer " + (token ?? anon),
      "Content-Type": "application/json",
      "x-salon-id": salon,
    },
    body: JSON.stringify(args),
  });
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null };
}

// Ono sto vidi klijentska app bez prijave.
async function javniSalon(salon: string) {
  const r = await fetch(
    url + "/rest/v1/salons?id=eq." + salon + "&select=logo_url,cover_image_url,gallery_urls",
    { headers: { apikey: anon!, "x-salon-id": salon } },
  );
  const body = await r.json();
  assert(r.status === 200 && body.length === 1, "Anon mora procitati salon, a dobio je " + r.status);
  return body[0] as { logo_url: string | null; cover_image_url: string | null; gallery_urls: string[] };
}

const png = Uint8Array.from(atob(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
), (c) => c.charCodeAt(0));
const stamp = Date.now();
const tokenA = await prijava("admin@barberstudiovitez.test");
const tokenB = await prijava("admin@beautystudiotravnik.test");

// --- Cover: upload, rpc, anon cita --------------------------------------------------------
const coverPut = `${salonB}/cover/rest-${stamp}.png`;
const coverUrl = await upload(tokenB, coverPut);
const zatecenB = await javniSalon(salonB);

const cover = await rpc(tokenB, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: coverUrl }, salonB);
assert(cover.status === 200, "Vlasnik B mora postaviti svoj cover, a dobio je " + JSON.stringify(cover));
assert((await javniSalon(salonB)).cover_image_url === coverUrl, "Anon mora vidjeti novi cover bez novog builda");

const javnaSlika = await fetch(coverUrl);
await javnaSlika.body?.cancel();
assert(javnaSlika.status === 200, "URL iz rpc-a mora biti citljiv bez tokena, a vratio je " + javnaSlika.status);

// Vlasnik A pokusava isto nad salonom B — i sa headerom salona B.
const tudji = await rpc(tokenA, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: null }, salonB);
assert(tudji.status === 403 && tudji.body?.code === "42501", "Vlasnik A ne mijenja cover salona B: " + JSON.stringify(tudji));
assert((await javniSalon(salonB)).cover_image_url === coverUrl, "Odbijen poziv ne dira cover");

// Objekat salona B kao logo salona A — javni URL nije dokaz vlasnistva.
const podmetnut = await rpc(tokenA, "set_salon_image", { p_salon_id: salonA, p_kind: "logo", p_url: coverUrl }, salonA);
assert(podmetnut.status === 400 && podmetnut.body?.code === "PT400", "Tudji objekat se odbija: " + JSON.stringify(podmetnut));

const anonPoziv = await rpc(null, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: null }, salonB);
assert(anonPoziv.status === 401 || anonPoziv.status === 403 || anonPoziv.status === 404,
  "Anon ne zove set_salon_image, a dobio je " + anonPoziv.status);

// --- Galerija: dodaj, konflikt, vrati -----------------------------------------------------
const zatecenA = await javniSalon(salonA);
const galPut = `${salonA}/galerija/rest-${stamp}.png`;
const galUrl = await upload(tokenA, galPut);
const sa = [galUrl, ...zatecenA.gallery_urls];

const dodaj = await rpc(tokenA, "set_salon_gallery",
  { p_salon_id: salonA, p_expected: zatecenA.gallery_urls, p_urls: sa }, salonA);
assert(dodaj.status === 200, "Vlasnik A mora dodati sliku u galeriju: " + JSON.stringify(dodaj));
assert(JSON.stringify((await javniSalon(salonA)).gallery_urls) === JSON.stringify(sa),
  "Anon mora vidjeti novu galeriju u istom redoslijedu");

// Drugi tab je ucitao galeriju prije dodavanja i sada snima.
const stari = await rpc(tokenA, "set_salon_gallery",
  { p_salon_id: salonA, p_expected: zatecenA.gallery_urls, p_urls: [] }, salonA);
assert(stari.status === 409 && stari.body?.code === "PT409", "Zastarjela galerija mora dati 409: " + JSON.stringify(stari));
assert((await javniSalon(salonA)).gallery_urls.length === sa.length, "Konflikt ne brise galeriju");

const tudjaGal = await rpc(tokenB, "set_salon_gallery",
  { p_salon_id: salonA, p_expected: sa, p_urls: [] }, salonA);
assert(tudjaGal.status === 403 && tudjaGal.body?.code === "42501", "Vlasnik B ne mijenja galeriju salona A: " + JSON.stringify(tudjaGal));

// --- Vracanje zatečenog stanja --------------------------------------------------------------
const vrati = await rpc(tokenA, "set_salon_gallery",
  { p_salon_id: salonA, p_expected: sa, p_urls: zatecenA.gallery_urls }, salonA);
assert(vrati.status === 200, "Uklanjanje svoje slike mora proci: " + JSON.stringify(vrati));
const vratiCover = await rpc(tokenB, "set_salon_image",
  { p_salon_id: salonB, p_kind: "cover", p_url: zatecenB.cover_image_url }, salonB);
assert(vratiCover.status === 200, "Vracanje covera mora proci: " + JSON.stringify(vratiCover));
assert(JSON.stringify(await javniSalon(salonA)) === JSON.stringify(zatecenA), "Salon A je vracen");
await brisi(tokenA, [galPut]);
await brisi(tokenB, [coverPut]);

console.log(`rest_galerija: ${assertions} provjera prošlo`);
