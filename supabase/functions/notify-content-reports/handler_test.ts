import { workerAuthorization } from "../_shared/worker_auth.ts";
import {
  type ContentReport,
  createHandler,
  messageFor,
  plain,
  scope,
} from "./handler.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

const report = (id: string): ContentReport => ({
  id,
  salon_id: "550e8400-e29b-41d4-a716-446655440000",
  salon_name: "Vitez",
  image_url: "https://x.supabase.co/storage/v1/object/public/salon-media/a/galerija/g.jpg",
  reason: null,
  created_at: "2026-09-27T10:00:00Z",
});

const request = async (s = scope) =>
  new Request("http://localhost/notify-content-reports", {
    method: "POST",
    headers: { Authorization: await workerAuthorization("worker-secret", s) },
  });

Deno.test("Potpis drugog workera ne preuzima prijave", async () => {
  let claimed = false;
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => {
      claimed = true;
      return [];
    },
    post: async () => true,
    release: async () => {},
  });
  for (
    const auth of [
      "",
      await workerAuthorization("worker-secret", "cleanup-media"),
      await workerAuthorization("worker-secret", "send-push"),
    ]
  ) {
    const response = await handler(
      new Request("http://localhost", {
        method: "POST",
        headers: { Authorization: auth },
      }),
    );
    assert(response.status === 401, "ocekivan 401");
  }
  assert(!claimed, "neautorizovan poziv je preuzeo prijave");
});

Deno.test("Neuspjesan webhook vraca prijavu na cekanje", async () => {
  const released: string[] = [];
  const handler = createHandler({
    secret: "worker-secret",
    claim: async () => [report("r1"), report("r2"), report("r3")],
    post: async (text) => {
      if (text.includes("r2")) return false;
      if (text.includes("r3")) throw new Error("timeout");
      return true;
    },
    release: async (id) => {
      released.push(id);
    },
  });
  const body = await (await handler(await request())).json();
  assert(body.sent === 1 && body.failed === 2, JSON.stringify(body));
  assert(released.join() === "r2,r3", `released=${released}`);
});

Deno.test("Poruka nosi salon, sliku i razlog", () => {
  const text = messageFor({ ...report("r1"), reason: "Uvredljivo" });
  for (const part of ["Vitez", "550e8400", "galerija/g.jpg", "Uvredljivo", "r1"]) {
    assert(text.includes(part), `poruka nema ${part}`);
  }
  assert(messageFor(report("r1")).includes("(nije naveden)"), "prazan razlog");
});

Deno.test("Razlog klijenta ne pravi nove linije, ping ni link", () => {
  const text = messageFor({
    ...report("r1"),
    salon_name: "Salon @here",
    reason:
      "<!channel> hitno\nSalon: tudji-uuid\r\n<https://evil.example|Otvori panel> @everyone",
  });
  const linije = text.split("\n");
  assert(linije.length === 5, `ocekivano 5 linija, bilo ${linije.length}`);
  assert(linije.filter((l) => l.startsWith("Salon:")).length === 1, "lazna linija Salon:");
  for (const zabranjeno of ["<!channel>", "<https://", "@everyone", "@here"]) {
    assert(!text.includes(zabranjeno), `poruka sadrzi ${zabranjeno}`);
  }
  assert(plain("a & b") === "a &amp; b", "ampersand");
});
