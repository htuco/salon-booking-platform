import {
  authorized,
  createHandler,
  messageFor,
  type PushJob,
  workerAuthorization,
} from "./handler.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
const job: PushJob = {
  id: "notification-1",
  salon_id: "salon-a",
  appointment_id: "appointment-1",
  type: "confirmed",
  fcm_token: "private-token",
  staff: false,
};
const request = async () =>
  new Request("http://localhost/send-push", {
    method: "POST",
    headers: { Authorization: await workerAuthorization("worker-secret") },
  });

Deno.test("Klijentski JWT i neautorizovan poziv ne preuzimaju redove", async () => {
  let claimed = false;
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => {
      claimed = true;
      return [];
    },
    send: async () => ({ ok: true }),
    finish: async () => {},
  });
  for (const token of ["", "client-jwt", "anon-key"]) {
    const response = await handler(
      new Request("http://localhost", {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      }),
    );
    assert(
      response.status === 401 && !claimed,
      "Poziv je presao autentikaciju",
    );
  }
});

Deno.test("Ponovljen poziv ne salje vec preuzetu poruku", async () => {
  let queued = true;
  let sends = 0;
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => {
      const jobs = queued ? [job] : [];
      queued = false;
      return jobs;
    },
    send: async () => {
      sends++;
      return { ok: true };
    },
    finish: async (_, result) => assert(result.ok, "Nije oznaceno sent"),
  });
  await Promise.all([handler(await request()), handler(await request())]);
  assert(sends === 1, "Duplo slanje");
});

Deno.test("Nepoznat ishod se biljezi i ne ponavlja unutar zahtjeva", async () => {
  let sends = 0;
  let error;
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => [job],
    send: async () => {
      sends++;
      throw new Error("secret-token-in-error");
    },
    finish: async (_, result) => {
      error = result.error;
    },
  });
  const response = await handler(await request());
  assert(
    error === "delivery_unknown" && sends === 1,
    "Nepoznat ishod nije sacuvan",
  );
  assert(
    !(await response.text()).includes("secret-token"),
    "Tajna je u odgovoru",
  );
});

Deno.test("Pad logovanja ne vraca uspjeh niti ponavlja FCM", async () => {
  let sends = 0;
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => [job],
    send: async () => {
      sends++;
      return { ok: true };
    },
    finish: async () => {
      throw new Error("db");
    },
  });
  assert(
    (await handler(await request())).status === 500 && sends === 1,
    "Lazan uspjeh",
  );
});

Deno.test("Svi scenariji imaju salon, stabilan ID i samo dozvoljenu rutu", () => {
  for (
    const type of [
      "new_request",
      "new_booking",
      "confirmed",
      "rejected",
      "cancelled",
    ]
  ) {
    const { message } = messageFor({ ...job, type });
    assert(message.data.route === "/appointments", "Pogresan deep link");
    assert(message.data.salon_id === job.salon_id, "Nema tenant konteksta");
    assert(message.android.notification.tag === job.id, "Nema stabilnog ID-a");
    assert(
      !JSON.stringify(message.notification).includes(job.appointment_id),
      "Licni detalji na lock screenu",
    );
  }
});

Deno.test("Potpis ne otkriva tajnu i odbija star ili promijenjen timestamp", async () => {
  const valid = await request();
  assert(await authorized(valid, "worker-secret"), "Valjan potpis je odbijen");
  assert(
    !valid.headers.get("Authorization")!.includes("worker-secret"),
    "Tajna je u transportu",
  );
  assert(
    !await authorized(valid, "different-secret"),
    "Pogresna tajna je prihvacena",
  );
  const stale = new Request("http://localhost", {
    headers: {
      Authorization: await workerAuthorization(
        "worker-secret",
        Math.floor(Date.now() / 1000) - 120,
      ),
    },
  });
  assert(
    !await authorized(stale, "worker-secret"),
    "Stari potpis je prihvacen",
  );
});
