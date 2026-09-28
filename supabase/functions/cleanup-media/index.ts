import { createClient } from "jsr:@supabase/supabase-js@2";
import { createHandler, type Orphan } from "./handler.ts";

const client = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

Deno.serve(createHandler({
  secret: Deno.env.get("MEDIA_CLEANUP_SECRET") ?? "",
  async orphans() {
    const { data, error } = await client.rpc("media_orphans");
    if (error) throw error;
    return data as Orphan[];
  },
  async remove(paths) {
    const { error } = await client.storage.from("salon-media").remove(paths);
    if (error) throw error;
  },
}));
