import type { SupabaseClient } from "@supabase/supabase-js";
import type { SourceType, SourceAdapter, FeedItem } from "./types.ts";
import { getActiveSources, insertFeedItems, applyHealth } from "./db.ts";
import { nextHealth } from "./health.ts";

export type AdapterMap = Record<SourceType, SourceAdapter>;

export interface CollectResult {
  perSource: Array<{ sourceId: string; inserted: number; ok: boolean; error?: string }>;
  newItems: FeedItem[];
}

export async function runCollector(
  supabase: SupabaseClient,
  adapters: AdapterMap,
  httpGet: typeof globalThis.fetch,
  now: string,
): Promise<CollectResult> {
  const sources = await getActiveSources(supabase);
  const result: CollectResult = { perSource: [], newItems: [] };

  for (const source of sources) {
    try {
      const adapter = adapters[source.type];
      if (!adapter) throw new Error(`no adapter for type ${source.type}`);
      const raw = await adapter.fetch(source, httpGet);
      const items = raw.map((r) => adapter.normalize(r, source));
      const inserted = await insertFeedItems(supabase, items);
      await applyHealth(supabase, source.id, nextHealth(source, "success", now));
      if (inserted > 0) result.newItems.push(...items);
      result.perSource.push({ sourceId: source.id, inserted, ok: true });
      console.log(`[${source.id}/${source.type}] inserted ${inserted}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await applyHealth(supabase, source.id, nextHealth(source, "failure", now));
      result.perSource.push({ sourceId: source.id, inserted: 0, ok: false, error: msg });
      console.error(`[${source.id}/${source.type}] FAILED: ${msg}`);
    }
  }
  return result;
}
