export type PushJob = {
  id: string;
  salon_id: string;
  // NULL za ponudu liste cekanja (task 68): ona je vezana za upis, ne za tudji termin.
  appointment_id: string | null;
  type: string;
  fcm_token: string;
  staff: boolean;
  // Task 56. Rijec za termin po vertikali (`vertical_packs.terminology` + override salona) i
  // minute do pocetka za satni podsjetnik. Opciono: `claim_push_notifications` ih daje od
  // migracije 56, a ovaj worker se deploya prije nje.
  appointment_term?: string | null;
  starts_in_minutes?: number | null;
};

/** Bosanski broj uz imenicu: 1 sat, 2–4 sata, 5+ sati (21 sat, 22 sata, 11–14 sati). */
function plural(n: number, jedan: string, dva: string, pet: string) {
  const zadnja = n % 10;
  const zadnje2 = n % 100;
  if (zadnja === 1 && zadnje2 !== 11) return jedan;
  if (zadnja >= 2 && zadnja <= 4 && (zadnje2 < 12 || zadnje2 > 14)) return dva;
  return pet;
}

/**
 * „za 3 sata" / „za 40 minuta" iz preostalih minuta pri slanju, ne iz N iz postavke: red koji
 * je cekao ili salon koji je promijenio N ne smiju dati tekst koji laze.
 */
export function startsIn(minutes: number) {
  if (minutes >= 60) {
    const sati = Math.round(minutes / 60);
    return `za ${sati} ${plural(sati, "sat", "sata", "sati")}`;
  }
  const m = Math.max(1, Math.round(minutes));
  return `za ${m} ${plural(m, "minutu", "minute", "minuta")}`;
}

function reminderBody(job: PushJob) {
  // Rijec za termin je subjekat recenice, pa ne treba padez ni rod: „Termin je sutra",
  // „Tretman pocinje za 3 sata". Bez vremena, usluge i salona na lock screenu, kao i
  // ostali tipovi; detalji su u aplikaciji uz RLS.
  const term = job.appointment_term?.trim() || "Termin";
  if (job.type === "reminder_d1") {
    return `${term} je sutra. Detalji su u aplikaciji.`;
  }
  const minutes = job.starts_in_minutes;
  return typeof minutes === "number" && minutes > 0
    ? `${term} počinje ${startsIn(minutes)}. Detalji su u aplikaciji.`
    : `${term} uskoro počinje. Detalji su u aplikaciji.`;
}

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
    // Salon u `auto` modu nema na šta odgovoriti: termin je već potvrđen, a ekran
    // zahtjeva prazan. „Novi zahtjev" bi ga poslao da traži posao kojeg nema.
    new_booking: "Nova rezervacija",
    confirmed: "Zahtjev je potvrđen",
    rejected: "Zahtjev je odbijen",
    cancelled: "Otkazivanje",
    // Ne „odbijen": salon nije rekao ne, nego nije odgovorio do roka (task 64).
    expired: "Salon nije odgovorio na vrijeme",
    // Salon je termin označio završenim (task 67). „Ocijeni" stoji u Mojim terminima.
    review_request: "Kako je bilo?",
    // Lista cekanja (task 68). Ne „termin je vaš": mjesto dobija ko prvi zakaže (ADR-0031).
    waitlist_offer: "Oslobodilo se mjesto",
    // Podsjetnici (task 56, ADR-0033). Isti naslov kao u listi Obavijesti klijenta.
    reminder_d1: "Podsjetnik",
    reminder_h3: "Podsjetnik",
  };
  const bodies: Record<string, string> = {
    // Bez riječi „termin": ona zavisi od vertikale, a push je isti za sve tenante.
    review_request: "Ocijenite posjet u aplikaciji.",
    waitlist_offer:
      "Na dan na koji čekate ima slobodnog vremena. Zakažite u aplikaciji.",
  };
  if (!(job.type in titles)) throw new Error("unsupported_type");
  if (job.type === "reminder_d1" || job.type === "reminder_h3") {
    bodies[job.type] = reminderBody(job);
  }
  return {
    message: {
      token: job.fcm_token,
      notification: {
        title: titles[job.type],
        body: bodies[job.type] ?? "Otvorite aplikaciju za detalje.",
      },
      // FCM `data` prima samo stringove, pa ponuda bez termina polje izostavlja. Klijent
      // prazno polje vec tretira kao „nema termina" (`PushService._messageAppointment`).
      data: {
        notification_id: job.id,
        ...(job.appointment_id ? { appointment_id: job.appointment_id } : {}),
        salon_id: job.salon_id,
        route: "/appointments",
      },
      android: {
        priority: "high",
        notification: {
          tag: job.id,
          // Zvuk se mora **tražiti**. iOS ga je dobijao kroz `aps.sound` od početka, a
          // Android nije imao nijedno polje — obavijest je stizala nijemo. Na API < 26
          // ovo direktno bira ton, a na 26+ ga FCM koristi kad sam pravi fallback kanal.
          sound: "default",
          // Bez ovoga obavijest pada na FCM-ov `fcm_fallback_notification_channel`, čija
          // importance i zvuk nisu naši. Kanal `appointment_updates` prave obje aplikacije.
          channel_id: "appointment_updates",
        },
      },
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
