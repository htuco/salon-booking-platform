import { createClient } from "jsr:@supabase/supabase-js@2";
import { type ContentReport, createHandler } from "./handler.ts";

const client = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
const webhook = Deno.env.get("REPORT_WEBHOOK_URL") ?? "";

Deno.serve(createHandler({
  secret: Deno.env.get("CONTENT_REPORT_WORKER_SECRET") ?? "",
  async claim() {
    // Bez webhooka nema kome poslati — prijave ostaju neobaviještene u tabeli.
    if (!webhook) return [];
    const { data, error } = await client.rpc("claim_content_reports");
    if (error) throw error;
    return data as ContentReport[];
  },
  async post(text) {
    const response = await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
      signal: AbortSignal.timeout(10000),
    });
    await response.body?.cancel();
    return response.ok;
  },
  async release(id) {
    const { error } = await client.from("content_reports")
      .update({ notified_at: null }).eq("id", id);
    if (error) throw error;
  },
}));
