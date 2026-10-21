import {
  authorized,
  createHandler,
  messageFor,
  type PushJob,
  startsIn,
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
      "expired",
      "review_request",
      "waitlist_offer",
      "reminder_d1",
      "reminder_h3",
    ]
  ) {
    const { message } = messageFor({ ...job, type });
    assert(message.data.route === "/appointments", "Pogresan deep link");
    assert(message.data.salon_id === job.salon_id, "Nema tenant konteksta");
    assert(message.android.notification.tag === job.id, "Nema stabilnog ID-a");
    // Nijema obavijest je promasena obavijest. iOS je zvuk imao od pocetka, Android nije.
    assert(
      message.android.notification.sound === "default" &&
        message.apns.payload.aps.sound === "default",
      "Obavijest je nijema na jednoj platformi",
    );
    assert(
      message.android.notification.channel_id === "appointment_updates",
      "Android obavijest pada na FCM fallback kanal",
    );
    assert(
      !JSON.stringify(message.notification).includes(job.appointment_id!),
      "Licni detalji na lock screenu",
    );
  }
});

Deno.test("Ponuda liste cekanja nema termin, a data ostaje samo stringovi", () => {
  const { message } = messageFor({
    ...job,
    type: "waitlist_offer",
    appointment_id: null,
  });
  assert(!("appointment_id" in message.data), "Ponuda nosi appointment_id");
  assert(
    Object.values(message.data).every((value) => typeof value === "string"),
    "FCM data mora biti string",
  );
  assert(
    message.notification.title === "Oslobodilo se mjesto",
    "Pogresan naslov",
  );
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

Deno.test("Podsjetnici: tekst po vertikali, satni sa preostalim vremenom", () => {
  const d1 = messageFor({
    ...job,
    type: "reminder_d1",
    appointment_term: "Tretman",
  });
  assert(d1.message.notification.title === "Podsjetnik", "Pogresan naslov");
  assert(
    d1.message.notification.body ===
      "Tretman je sutra. Detalji su u aplikaciji.",
    `Dnevni tekst: ${d1.message.notification.body}`,
  );

  const h3 = messageFor({
    ...job,
    type: "reminder_h3",
    appointment_term: "Termin",
    starts_in_minutes: 178,
  });
  assert(
    h3.message.notification.body ===
      "Termin počinje za 3 sata. Detalji su u aplikaciji.",
    `Satni tekst: ${h3.message.notification.body}`,
  );
  assert(h3.message.data.appointment_id === job.appointment_id, "Nema termina");
});

Deno.test("Podsjetnik bez novih kolona (stari claim) ne pada i ne laze", () => {
  const d1 = messageFor({ ...job, type: "reminder_d1" });
  assert(
    d1.message.notification.body ===
      "Termin je sutra. Detalji su u aplikaciji.",
    "Bez rijeci iz baze ide Termin",
  );
  const h3 = messageFor({ ...job, type: "reminder_h3", appointment_term: " " });
  assert(
    h3.message.notification.body ===
      "Termin uskoro počinje. Detalji su u aplikaciji.",
    `Bez minuta nema broja: ${h3.message.notification.body}`,
  );
});

Deno.test("Satni broji po bosanski", () => {
  const ocekivano: Array<[number, string]> = [
    [60, "za 1 sat"],
    [120, "za 2 sata"],
    [240, "za 4 sata"],
    [300, "za 5 sati"],
    [660, "za 11 sati"],
    [720, "za 12 sati"],
    [45, "za 45 minuta"],
    [1, "za 1 minutu"],
    [2, "za 2 minute"],
    [21, "za 21 minutu"],
    [12, "za 12 minuta"],
  ];
  for (const [minute, tekst] of ocekivano) {
    assert(startsIn(minute) === tekst, `${minute} min: ${startsIn(minute)}`);
  }
});
