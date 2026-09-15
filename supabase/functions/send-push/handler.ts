export type PushJob = {
  id: string;
  salon_id: string;
  appointment_id: string;
  type: string;
  fcm_token: string;
  staff: boolean;
};

export interface PushDependencies {
  secret: string;
  claim(): Promise<PushJob[]>;
  send(job: PushJob): Promise<{ ok: boolean; error?: string }>;
  finish(job: PushJob, result: { ok: boolean; error?: string }): Promise<void>;
}

export async function workerAuthorization(
  secret: string,
  timestamp = Math.floor(Date.now() / 1000),
) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`send-push:${timestamp}`),
  );
  const hex = Array.from(
    new Uint8Array(signature),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  return `Bearer ${timestamp}.${hex}`;
}

export async function authorized(
  request: Request,
  secret: string,
): Promise<boolean> {
  if (!secret) return false;
  const match = /^Bearer (\d{10})\.([a-f0-9]{64})$/.exec(
    request.headers.get("Authorization") ?? "",
  );
  if (!match || Math.abs(Date.now() / 1000 - Number(match[1])) > 60) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signature = Uint8Array.from(
    match[2].match(/../g)!,
    (hex) => parseInt(hex, 16),
  );
  return crypto.subtle.verify(
    "HMAC",
    key,
    signature,
    new TextEncoder().encode(`send-push:${match[1]}`),
  );
}

export function messageFor(job: PushJob) {
  const titles: Record<string, string> = {
    new_request: "Novi zahtjev",
    confirmed: "Zahtjev je potvrđen",
    rejected: "Zahtjev je odbijen",
    cancelled: "Otkazivanje",
  };
  if (!(job.type in titles)) throw new Error("unsupported_type");
  return {
    message: {
      token: job.fcm_token,
      notification: {
        title: titles[job.type],
        body: "Otvorite aplikaciju za detalje.",
      },
      data: {
        notification_id: job.id,
        appointment_id: job.appointment_id,
        salon_id: job.salon_id,
        route: "/appointments",
      },
      android: { priority: "high", notification: { tag: job.id } },
      apns: {
        headers: { "apns-collapse-id": job.id, "apns-push-type": "alert" },
        payload: { aps: { sound: "default" } },
      },
    },
  };
}

export function createHandler(deps: PushDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response(null, { status: 405 });
    if (!await authorized(req, deps.secret)) {
      return new Response(null, { status: 401 });
    }
    try {
      const jobs = await deps.claim();
      let sent = 0;
      let failed = 0;
      const outcomes = await Promise.allSettled(jobs.map(async (job) => {
        let result: { ok: boolean; error?: string };
        try {
          result = await deps.send(job);
        } catch {
          // Timeout nije dokaz da poruka nije prihvacena. Bez automatskog retryja.
          result = { ok: false, error: "delivery_unknown" };
        }
        await deps.finish(job, result);
        if (result.ok) sent++;
        else failed++;
      }));
      if (outcomes.some((result) => result.status === "rejected")) {
        throw new Error("log_update_failed");
      }
      return Response.json({ sent, failed });
    } catch {
      // Nema FCM tokena, OAuth odgovora ili servisnog kljuca u logu/odgovoru.
      return Response.json({ error: "push_worker_failed" }, { status: 500 });
    }
  };
}
