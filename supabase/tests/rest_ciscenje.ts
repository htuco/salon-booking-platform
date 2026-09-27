// Ciscenje bucketa i prijava slike kroz stvaran Storage API i PostgREST (task 51, ADR-0024).
// deno run --allow-env --allow-net supabase/tests/rest_ciscenje.ts
//
// pgTAP (`024_ciscenje_i_prijava.test.sql`) mjeri listu siročadi nad redovima u
// `storage.objects`. Ovdje se vidi ono sto pgTAP ne moze: da stvaran `cleanup-media` handler
// kroz Storage API obrise fajl — ne samo red — a da fajl sa referencom ostane citljiv.
// Edge runtime se ne dize: handler se zove direktno, sa istim zavisnostima kao `index.ts`.
//
// Lista je suzena na objekte ovog testa, da lokalni stack ne izgubi siročad iz uzivo provjera.
// Test vraca zatečeno stanje: cover salona B (seed ga nema) i galeriju salona A.
import { createHandler, type Orphan } from "../functions/cleanup-media/handler.ts";
import { workerAuthorization } from "../functions/_shared/worker_auth.ts";

const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(url).hostname)) {
  throw new Error("Ciscenje test may only run against local Supabase.");
}
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY");
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
if (!anon || !service) throw new Error("Set local Supabase anon and service role keys.");

const bucket = "salon-media";
const salonA = "550e8400-e29b-41d4-a716-446655440000";
const salonB = "550e8400-e29b-41d4-a716-446655440001";
const stamp = `rest51-${Date.now()}`;
let assertions = 0;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
  assertions++;
}

async function call(path: string, token: string, init: RequestInit = {}, salon?: string) {
  const r = await fetch(url + path, {
    ...init,
    headers: {
      apikey: anon!,
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
      ...(salon ? { "x-salon-id": salon } : {}),
      ...init.headers,
    },
  });
  const text = await r.text();
  return { status: r.status, body: text ? JSON.parse(text) : null };
}

const rpc = (token: string, fn: string, args: Record<string, unknown>, salon?: string) =>
  call("/rest/v1/rpc/" + fn, token, { method: "POST", body: JSON.stringify(args) }, salon);

async function prijava(email: string, password = "admin123456") {
  const r = await call("/auth/v1/token?grant_type=password", anon!, {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  assert(r.status === 200, "Prijava " + email + " vratila " + r.status);
  return r.body.access_token as string;
}

const png = Uint8Array.from(atob(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
), (c) => c.charCodeAt(0));

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

async function javnoStatus(publicUrl: string) {
  const r = await fetch(publicUrl);
  await r.body?.cancel();
  return r.status;
}

const tokenA = await prijava("admin@barberstudiovitez.test");
const tokenB = await prijava("admin@beautystudiotravnik.test");
let klijentId: string | null = null;
let galerijaA: string[] | null = null;
const putanje: string[] = [];

try {
  // --- Zamjena covera: dvije slike gore, referenca samo na drugu ---------------------------
  const staraPut = `${salonB}/cover/${stamp}-stara.png`;
  const novaPut = `${salonB}/cover/${stamp}-nova.png`;
  const prekinutPut = `${salonA}/usluge/${stamp}-prekinut.png`;
  putanje.push(staraPut, novaPut, prekinutPut);

  const staraUrl = await upload(tokenB, staraPut);
  assert((await rpc(tokenB, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: staraUrl }, salonB)).status === 200,
    "Vlasnik B postavlja prvi cover");
  const novaUrl = await upload(tokenB, novaPut);
  assert((await rpc(tokenB, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: novaUrl }, salonB)).status === 200,
    "Vlasnik B zamjenjuje cover");
  // Upload bez RPC-a — tab zatvoren prije snimanja.
  const prekinutUrl = await upload(tokenA, prekinutPut);

  // --- Lista je samo za service role ------------------------------------------------------
  const kaoVlasnik = await rpc(tokenA, "media_orphans", { p_min_age: "0 seconds" });
  assert(kaoVlasnik.status === 401 || kaoVlasnik.status === 403 || kaoVlasnik.status === 404,
    "Vlasnik salona ne lista siročad, a dobio je " + kaoVlasnik.status);

  // Svjez upload se ne dira dok ne prode prag.
  const podrazumijevano = await rpc(service, "media_orphans", {});
  assert(podrazumijevano.status === 200, "service role lista siročad: " + JSON.stringify(podrazumijevano));
  assert(!(podrazumijevano.body as Orphan[]).some((o) => o.name.includes(stamp)),
    "Upload mladji od sat vremena nije siroce");

  // --- Stvaran handler, stvaran Storage API -----------------------------------------------
  const pozivi: string[][] = [];
  const handler = createHandler({
    secret: "rest-secret",
    async orphans() {
      const r = await rpc(service, "media_orphans", { p_min_age: "0 seconds" });
      if (r.status !== 200) throw new Error("media_orphans " + r.status);
      return (r.body as Orphan[]).filter((o) => o.name.includes(stamp));
    },
    async remove(paths) {
      pozivi.push(paths);
      const r = await call("/storage/v1/object/" + bucket, service, {
        method: "DELETE",
        body: JSON.stringify({ prefixes: paths }),
      });
      if (r.status !== 200) throw new Error("remove " + r.status);
    },
  });
  const odgovor = await handler(new Request("http://localhost/cleanup-media", {
    method: "POST",
    headers: { Authorization: await workerAuthorization("rest-secret", "cleanup-media") },
  }));
  const rezultat = await odgovor.json();
  assert(odgovor.status === 200 && rezultat.removed === 2 && rezultat.rejected === 0,
    "Handler brise dva siročeta: " + JSON.stringify(rezultat));
  assert(pozivi.length === 2 && pozivi.every((p) => p.length === 1),
    "Svaki salon ima svoj remove poziv: " + JSON.stringify(pozivi));

  assert(await javnoStatus(staraUrl) !== 200, "Zamijenjeni cover je nestao iz bucketa");
  assert(await javnoStatus(prekinutUrl) !== 200, "Upload bez reference je nestao iz bucketa");
  assert(await javnoStatus(novaUrl) === 200, "Cover sa referencom je i dalje javno citljiv");

  const uFolderu = await call("/storage/v1/object/list/" + bucket, tokenB, {
    method: "POST",
    body: JSON.stringify({ prefix: `${salonB}/cover/`, search: stamp }),
  });
  assert(uFolderu.status === 200 && uFolderu.body.length === 1,
    "Nakon zamjene u folderu ostaje jedan fajl, ne dva: " + JSON.stringify(uFolderu.body));

  // --- Prijava slike iz galerije ----------------------------------------------------------
  const galerijaPut = `${salonA}/galerija/${stamp}.png`;
  putanje.push(galerijaPut);
  const galerijaUrl = await upload(tokenA, galerijaPut);
  const salon = await call(`/rest/v1/salons?id=eq.${salonA}&select=gallery_urls`, anon, {}, salonA);
  galerijaA = salon.body[0].gallery_urls as string[];
  const dodaj = await rpc(tokenA, "set_salon_gallery",
    { p_salon_id: salonA, p_expected: galerijaA, p_urls: [...galerijaA, galerijaUrl] }, salonA);
  assert(dodaj.status === 200, "Vlasnik A dodaje sliku u galeriju: " + JSON.stringify(dodaj));

  const email = `klijent-${stamp}@example.test`;
  const password = crypto.randomUUID() + "Aa1!";
  const user = await call("/auth/v1/admin/users", service, {
    method: "POST",
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  assert(user.status === 200, "Klijent napravljen: " + user.status);
  klijentId = user.body.id;
  const tokenKlijent = await prijava(email, password);

  const prijavaSlike = await rpc(tokenKlijent, "report_content",
    { p_salon_id: salonA, p_image_url: galerijaUrl, p_reason: "Neprikladno" }, salonA);
  assert(prijavaSlike.status === 200 && typeof prijavaSlike.body === "string",
    "Klijent prijavljuje sliku: " + JSON.stringify(prijavaSlike));
  const ponovo = await rpc(tokenKlijent, "report_content",
    { p_salon_id: salonA, p_image_url: galerijaUrl }, salonA);
  assert(ponovo.body === prijavaSlike.body, "Ponovljena prijava vraca isti id");

  const vanGalerije = await rpc(tokenKlijent, "report_content",
    { p_salon_id: salonA, p_image_url: novaUrl }, salonA);
  assert(vanGalerije.status === 400 && vanGalerije.body?.code === "PT400",
    "Slika van galerije se ne prijavljuje: " + JSON.stringify(vanGalerije));

  const anonPrijava = await rpc(anon, "report_content",
    { p_salon_id: salonA, p_image_url: galerijaUrl }, salonA);
  assert(anonPrijava.status === 401 || anonPrijava.status === 403 || anonPrijava.status === 404,
    "Anon ne prijavljuje, a dobio je " + anonPrijava.status);

  // Salon ne vidi prijavu svog sadrzaja; service role (platforma) vidi.
  const vlasnikCita = await call("/rest/v1/content_reports?select=id", tokenA, {}, salonA);
  assert(vlasnikCita.status === 200 && vlasnikCita.body.length === 0,
    "Vlasnik salona ne cita prijave: " + JSON.stringify(vlasnikCita.body));
  const klijentCita = await call("/rest/v1/content_reports?select=id", tokenKlijent, {}, salonA);
  assert(klijentCita.status === 200 && klijentCita.body.length === 0, "Klijent ne cita prijave");
  const platforma = await call(`/rest/v1/content_reports?id=eq.${prijavaSlike.body}&select=salon_id,image_url,reason,status`, service);
  assert(platforma.body.length === 1 && platforma.body[0].status === "open" &&
    platforma.body[0].image_url === galerijaUrl, "Prijava je stigla platformi: " + JSON.stringify(platforma.body));

  // Prijavljena slika ostaje vidljiva dok platforma ne odluci (ADR-0024).
  assert(await javnoStatus(galerijaUrl) === 200, "Prijavljena slika ostaje javna");
  await call(`/rest/v1/content_reports?id=eq.${prijavaSlike.body}`, service, { method: "DELETE" });

  console.log(`rest_ciscenje: ${assertions} provjera prolazi`);
} finally {
  if (galerijaA) {
    const sada = await call(`/rest/v1/salons?id=eq.${salonA}&select=gallery_urls`, anon, {}, salonA);
    await rpc(tokenA, "set_salon_gallery",
      { p_salon_id: salonA, p_expected: sada.body[0].gallery_urls, p_urls: galerijaA }, salonA);
  }
  await rpc(tokenB, "set_salon_image", { p_salon_id: salonB, p_kind: "cover", p_url: null }, salonB);
  await call("/storage/v1/object/" + bucket, service, {
    method: "DELETE",
    body: JSON.stringify({ prefixes: putanje }),
  });
  if (klijentId) await call("/auth/v1/admin/users/" + klijentId, service, { method: "DELETE" });
}
