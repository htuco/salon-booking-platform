import { authorized } from "../_shared/worker_auth.ts";

export const scope = "notify-content-reports";

export type ContentReport = {
  id: string;
  salon_id: string;
  salon_name: string;
  image_url: string;
  reason: string | null;
  created_at: string;
};

export interface NotifyDependencies {
  secret: string;
  /** `public.claim_content_reports` — postavlja `notified_at` pri preuzimanju. */
  claim(): Promise<ContentReport[]>;
  /** POST na `REPORT_WEBHOOK_URL`. `false` = webhook nije primio poruku. */
  post(text: string): Promise<boolean>;
  /** Vraća `notified_at` na NULL, da sljedeći poziv pokuša ponovo. */
  release(id: string): Promise<void>;
}

/**
 * Tekst za Slack/Discord. Oba primaju `{"text": ...}` (Discord kroz `/slack` sufiks).
 *
 * Prijavitelj se ne šalje: webhook kanal nije mjesto za podatke o klijentu, a platformi
 * treba slika i salon, ne ko je prijavio. Red u `content_reports` ima ostalo.
 */
export function messageFor(r: ContentReport) {
  return [
    `Prijava slike — ${r.salon_name}`,
    `Salon: ${r.salon_id}`,
    `Slika: ${r.image_url}`,
    `Razlog: ${r.reason ?? "(nije naveden)"}`,
    `Prijava: ${r.id} (${r.created_at})`,
  ].join("\n");
}

export function createHandler(deps: NotifyDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response(null, { status: 405 });
    if (!await authorized(req, deps.secret, scope)) {
      return new Response(null, { status: 401 });
    }
    try {
      const reports = await deps.claim();
      let sent = 0;
      let failed = 0;
      for (const report of reports) {
        let ok = false;
        try {
          ok = await deps.post(messageFor(report));
        } catch {
          ok = false;
        }
        if (ok) {
          sent++;
        } else {
          failed++;
          await deps.release(report.id);
        }
      }
      return Response.json({ sent, failed });
    } catch {
      return Response.json({ error: "notify_failed" }, { status: 500 });
    }
  };
}
