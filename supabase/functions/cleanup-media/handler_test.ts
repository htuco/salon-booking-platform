import { workerAuthorization } from "../_shared/worker_auth.ts";
import { createHandler, groupBySalon, type Orphan, scope } from "./handler.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

const A = "550e8400-e29b-41d4-a716-446655440000";
const B = "550e8400-e29b-41d4-a716-446655440001";

const request = async (s = scope) =>
  new Request("http://localhost/cleanup-media", {
    method: "POST",
    headers: { Authorization: await workerAuthorization("worker-secret", s) },
  });

function handlerWith(rows: Orphan[], failFor?: string) {
  const calls: string[][] = [];
  const handler = createHandler({
    secret: "worker-secret",
    orphans: async () => rows,
    remove: async (paths) => {
      calls.push(paths);
      if (failFor && paths.some((p) => p.startsWith(failFor))) {
        throw new Error("storage");
      }
    },
  });
  return { handler, calls };
}

Deno.test("Bez potpisa i sa potpisom drugog workera nista se ne brise", async () => {
  const { handler, calls } = handlerWith([{ salon_id: A, name: `${A}/usluge/a.jpg` }]);
  for (
    const auth of [
      "",
      "Bearer anon-key",
      await workerAuthorization("worker-secret", "notify-content-reports"),
      await workerAuthorization("pogresna-tajna", scope),
      await workerAuthorization("worker-secret", scope, 1_000_000_000),
    ]
  ) {
    const response = await handler(
      new Request("http://localhost", {
        method: "POST",
        headers: { Authorization: auth },
      }),
    );
    assert(response.status === 401, `ocekivan 401 za "${auth.slice(0, 20)}"`);
  }
  assert(calls.length === 0, "neautorizovan poziv je brisao");
});

Deno.test("Jedan remove poziv nosi putanje samo jednog salona", async () => {
  const { handler, calls } = handlerWith([
    { salon_id: A, name: `${A}/usluge/a.jpg` },
    { salon_id: B, name: `${B}/galerija/b.jpg` },
    { salon_id: A, name: `${A}/logo/l.png` },
  ]);
  const body = await (await handler(await request())).json();
  assert(body.removed === 3, `removed=${body.removed}`);
  assert(calls.length === 2, `ocekivana dva poziva, bilo ${calls.length}`);
  for (const paths of calls) {
    const prefix = paths[0].split("/")[0];
    assert(
      paths.every((p) => p.startsWith(`${prefix}/`)),
      `poziv mijesa salone: ${paths}`,
    );
  }
});

Deno.test("Putanja van prefiksa svog salona se ne salje u Storage", () => {
  const { bySalon, rejected } = groupBySalon([
    // Red tvrdi salon A, a putanja je salona B — greska u upitu ne smije brisati B.
    { salon_id: A, name: `${B}/usluge/tudja.jpg` },
    { salon_id: A, name: `${A}/../${B}/usluge/x.jpg` },
    { salon_id: A, name: `${A}/bez-vrste.jpg` },
    { salon_id: A, name: `${A}//x.jpg` },
    { salon_id: "nije-uuid", name: "nije-uuid/usluge/x.jpg" },
    { salon_id: A, name: `${A}/usluge/ok.jpg` },
  ]);
  assert(rejected === 5, `rejected=${rejected}`);
  assert(
    JSON.stringify([...bySalon]) === JSON.stringify([[A, [`${A}/usluge/ok.jpg`]]]),
    `bySalon=${JSON.stringify([...bySalon])}`,
  );
});

Deno.test("Pad brisanja jednog salona ne zaustavlja drugi", async () => {
  const { handler, calls } = handlerWith([
    { salon_id: A, name: `${A}/usluge/a.jpg` },
    { salon_id: B, name: `${B}/usluge/b.jpg` },
  ], A);
  const body = await (await handler(await request())).json();
  assert(calls.length === 2, "drugi salon nije pokusan");
  assert(body.removed === 1 && body.failed_salons === 1, JSON.stringify(body));
});

Deno.test("Greska liste ne otkriva detalje", async () => {
  const handler = createHandler({
    secret: "worker-secret",
    orphans: async () => {
      throw new Error("service-role-key u poruci");
    },
    remove: async () => {},
  });
  const response = await handler(await request());
  const text = await response.text();
  assert(response.status === 500, "ocekivan 500");
  assert(!text.includes("service-role"), "odgovor otkriva gresku");
});
