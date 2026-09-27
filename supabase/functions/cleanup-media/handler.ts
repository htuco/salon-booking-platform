import { authorized } from "../_shared/worker_auth.ts";

export const scope = "cleanup-media";

export type Orphan = { salon_id: string; name: string };

export interface CleanupDependencies {
  secret: string;
  /** `public.media_orphans` — lista siročadi, najstarija prva. */
  orphans(): Promise<Orphan[]>;
  /** Storage API `remove` nad `salon-media`. Jedan poziv = putanje jednog salona. */
  remove(paths: string[]): Promise<void>;
}

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Siročad po salonu, sa putanjama koje **sigurno** počinju prefiksom tog salona.
 *
 * SQL već vraća samo takve redove; ova provjera stoji ispred Storage API-ja da greška u
 * upitu ne postane brisanje tuđih slika. Red čiji `name` ne počinje sa `<salon_id>/`, nema
 * vrstu i fajl, ili nosi `..`, ispada i broji se kao odbijen.
 */
export function groupBySalon(rows: Orphan[]) {
  const bySalon = new Map<string, string[]>();
  let rejected = 0;
  for (const row of rows) {
    const segments = row.name.split("/");
    const ok = uuid.test(row.salon_id) &&
      segments.length >= 3 &&
      segments[0] === row.salon_id &&
      segments.every((s) => s !== "" && s !== "." && s !== "..");
    if (!ok) {
      rejected++;
      continue;
    }
    bySalon.set(row.salon_id, [...(bySalon.get(row.salon_id) ?? []), row.name]);
  }
  return { bySalon, rejected };
}

export function createHandler(deps: CleanupDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response(null, { status: 405 });
    if (!await authorized(req, deps.secret, scope)) {
      return new Response(null, { status: 401 });
    }
    try {
      const { bySalon, rejected } = groupBySalon(await deps.orphans());
      let removed = 0;
      let failedSalons = 0;
      // Salon po salon: pad jednog ne zaustavlja ostale, a sljedeći sat pokušava ponovo.
      for (const paths of bySalon.values()) {
        try {
          await deps.remove(paths);
          removed += paths.length;
        } catch {
          failedSalons++;
        }
      }
      return Response.json({ removed, rejected, failed_salons: failedSalons });
    } catch {
      // Nema putanja, ključeva ni poruka baze u odgovoru.
      return Response.json({ error: "cleanup_failed" }, { status: 500 });
    }
  };
}
