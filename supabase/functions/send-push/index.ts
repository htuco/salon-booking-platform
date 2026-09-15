import { createClient } from "jsr:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9.15.1";
import {
  authorized,
  createHandler,
  messageFor,
  type PushJob,
} from "./handler.ts";

const secret = Deno.env.get("PUSH_WORKER_SECRET") ?? "";

// Konfiguracija se cita tek nakon autentikacije, prije nego worker preuzme redove.
let handler: ReturnType<typeof createHandler> | undefined;
Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  if (!await authorized(request, secret)) {
    return new Response(null, { status: 401 });
  }
  try {
    if (!handler) {
      const account = JSON.parse(
        Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "{}",
      );
      if (
        !account.project_id || !account.client_email || !account.private_key
      ) {
        throw new Error("firebase_config");
      }
      const client = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const auth = new JWT({
        email: account.client_email,
        key: account.private_key,
        scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
      });
      handler = createHandler({
        secret,
        async claim() {
          // OAuth greska prije claim-a ostavlja redove queued za sljedeci poziv.
          await auth.getAccessToken();
          const { data, error } = await client.rpc("claim_push_notifications", {
            p_limit: 20,
          });
          if (error) throw error;
          return data as PushJob[];
        },
        async send(job) {
          const { token } = await auth.getAccessToken();
          if (!token) throw new Error("oauth");
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${
              encodeURIComponent(account.project_id)
            }/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(messageFor(job)),
              signal: AbortSignal.timeout(10000),
            },
          );
          await response.body?.cancel();
          return response.ok
            ? { ok: true }
            : { ok: false, error: `fcm_http_${response.status}` };
        },
        async finish(job, result) {
          const { error } = await client.from("notification_logs").update({
            status: result.ok ? "sent" : "failed",
            sent_at: result.ok ? new Date().toISOString() : null,
            error: result.error ?? null,
          }).eq("id", job.id).eq("salon_id", job.salon_id).eq(
            "status",
            "sending",
          );
          if (error) throw error;
        },
      });
    }
    return await handler(request);
  } catch {
    return Response.json({ error: "push_configuration_failed" }, {
      status: 503,
    });
  }
});
