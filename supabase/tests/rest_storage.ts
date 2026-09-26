// Storage bucket po salonu, kroz stvaran Storage API (task 48, ADR-0015).
// deno run --allow-env --allow-net supabase/tests/rest_storage.ts
//
// pgTAP (`022_storage_bucket.test.sql`) mjeri politiku nad `storage.objects`, ali ogranicenje
// tipa i velicine sprovodi Storage servis, ne baza — pa se to vidi samo ovdje. Isto vazi za
// javno citanje: `/object/public/...` ne prolazi kroz RLS.
const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Storage test may only run against local Supabase.");
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

async function upload(token: string | null, path: string, bytes: Uint8Array, type: string) {
  const r = await fetch(url + "/storage/v1/object/" + bucket + "/" + path, {
    method: "POST",
    headers: {
      apikey: anon!,
      Authorization: "Bearer " + (token ?? anon),
      "Content-Type": type,
      "x-upsert": "true",
    },
    body: bytes,
  });
  await r.body?.cancel();
  return r.status;
}

async function brisi(token: string, path: string) {
  const r = await fetch(url + "/storage/v1/object/" + bucket, {
    method: "DELETE",
    headers: { apikey: anon!, Authorization: "Bearer " + token, "Content-Type": "application/json" },
    body: JSON.stringify({ prefixes: [path] }),
  });
  const body = await r.json();
  return (body as unknown[]).length;
}

// Najmanji validan PNG — Storage ne provjerava sadrzaj, ali test neka ne lazira ni to.
const png = Uint8Array.from(atob(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
), (c) => c.charCodeAt(0));
const stamp = Date.now();
const putA = `${salonA}/usluge/rest-${stamp}.png`;
const putB = `${salonB}/usluge/rest-${stamp}.png`;

const tokenA = await prijava("admin@barberstudiovitez.test");
const tokenB = await prijava("admin@beautystudiotravnik.test");

// Upis
assert(await upload(tokenA, putA, png, "image/png") === 200, "Vlasnik A mora upisati u svoj salon");
const tudji = await upload(tokenA, putB, png, "image/png");
assert(tudji >= 400, "Vlasnik A ne smije upisati u salon B, a dobio je " + tudji);
const anonUpis = await upload(null, putA.replace("rest-", "anon-"), png, "image/png");
assert(anonUpis >= 400, "Anon ne smije upisivati, a dobio je " + anonUpis);

// Tip i velicina — sprovodi bucket, ne aplikacija
const tip = await upload(tokenA, `${salonA}/usluge/rest-${stamp}.txt`, new TextEncoder().encode("nije slika"), "text/plain");
assert(tip >= 400, "Bucket mora odbiti text/plain, a vratio je " + tip);
const svg = await upload(tokenA, `${salonA}/usluge/rest-${stamp}.svg`, new TextEncoder().encode("<svg/>"), "image/svg+xml");
assert(svg >= 400, "Bucket mora odbiti SVG (moze nositi skriptu), a vratio je " + svg);
const velik = await upload(tokenA, `${salonA}/usluge/rest-${stamp}-velik.png`, new Uint8Array(5 * 1024 * 1024 + 1), "image/png");
assert(velik >= 400, "Bucket mora odbiti fajl veci od 5 MiB, a vratio je " + velik);

// Javno citanje bez tokena
const javno = await fetch(url + "/storage/v1/object/public/" + bucket + "/" + putA);
await javno.body?.cancel();
assert(javno.status === 200, "Javni URL mora raditi bez tokena, a vratio je " + javno.status);

// Prepis, move i copy — svaki ide drugom politikom (UPDATE; UPDATE name; SELECT + INSERT)
async function akcija(token: string, ruta: "move" | "copy", od: string, ka: string) {
  const r = await fetch(url + "/storage/v1/object/" + ruta, {
    method: "POST",
    headers: { apikey: anon!, Authorization: "Bearer " + token, "Content-Type": "application/json" },
    body: JSON.stringify({ bucketId: bucket, sourceKey: od, destinationKey: ka }),
  });
  await r.body?.cancel();
  return r.status;
}
const prepis = await upload(tokenB, putA, new Uint8Array(png.length + 7), "image/png");
assert(prepis >= 400, "Vlasnik B ne smije prepisati objekat salona A, a dobio je " + prepis);
const poslije = await fetch(url + "/storage/v1/object/public/" + bucket + "/" + putA);
assert((await poslije.arrayBuffer()).byteLength === png.length, "Objekat salona A mora ostati netaknut");
const move = await akcija(tokenA, "move", putA, putB);
assert(move >= 400, "Vlasnik A ne smije preseliti objekat u salon B, a dobio je " + move);
const copy = await akcija(tokenA, "copy", putA, putB);
assert(copy >= 400, "Vlasnik A ne smije kopirati objekat u salon B, a dobio je " + copy);
const kradja = await akcija(tokenB, "copy", putA, putB);
assert(kradja >= 400, "Vlasnik B ne smije kopirati objekat salona A (ne vidi ga), a dobio je " + kradja);
const svojMove = await akcija(tokenA, "move", putA, putA.replace("rest-", "moved-"));
assert(svojMove === 200, "Vlasnik A mora moci preseliti objekat unutar svog salona, a dobio je " + svojMove);
assert(await akcija(tokenA, "move", putA.replace("rest-", "moved-"), putA) === 200, "Vracanje nazad mora proci");

// Brisanje: vlasnik B ne brise objekat salona A, vlasnik A brise svoj
assert(await brisi(tokenB, putA) === 0, "Vlasnik B ne smije obrisati objekat salona A");
assert(await brisi(tokenA, putA) === 1, "Vlasnik A mora obrisati svoj objekat");
const nestao = await fetch(url + "/storage/v1/object/public/" + bucket + "/" + putA);
await nestao.body?.cancel();
assert(nestao.status >= 400, "Obrisan objekat ne smije biti javno dostupan");

console.log(`rest_storage: ${assertions} provjera prolazi`);
