import { createClient } from "@supabase/supabase-js";
import { runCollector, type AdapterMap } from "./collector.ts";
import { RssAdapter } from "./adapters/rss.ts";

const adapters: AdapterMap = { rss: RssAdapter };

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  try {
    const result = await runCollector(supabase, adapters, globalThis.fetch, new Date().toISOString());
    return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: msg }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
