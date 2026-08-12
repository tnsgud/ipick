import type { SupabaseClient } from "@supabase/supabase-js";
import type { Source, SourceType, SourceAdapter, FeedItem } from "./types.ts";
import { getActiveSources, insertFeedItems, applyHealth } from "./db.ts";
import { nextHealth } from "./health.ts";

export type AdapterMap = Partial<Record<SourceType, SourceAdapter>>;

export interface CollectResult {
  perSource: Array<{ sourceId: string; inserted: number; ok: boolean; error?: string }>;
  newItems: FeedItem[];
}

/** 헬스 기록 실패가 소스 격리를 깨지 않도록 에러를 삼킨다. */
async function safeApplyHealth(
  supabase: SupabaseClient,
  source: Source,
  outcome: "success" | "failure",
  now: string,
): Promise<void> {
  try {
    await applyHealth(supabase, source.id, nextHealth(source, outcome, now));
  } catch (e) {
    console.error(`[${source.id}] health write failed: ${e instanceof Error ? e.message : String(e)}`);
  }
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
      const insertedItems = await insertFeedItems(supabase, items);
      result.newItems.push(...insertedItems);
      result.perSource.push({ sourceId: source.id, inserted: insertedItems.length, ok: true });
      console.log(`[${source.id}/${source.type}] inserted ${insertedItems.length}`);
      await safeApplyHealth(supabase, source, "success", now);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.perSource.push({ sourceId: source.id, inserted: 0, ok: false, error: msg });
      console.error(`[${source.id}/${source.type}] FAILED: ${msg}`);
      await safeApplyHealth(supabase, source, "failure", now);
    }
  }
  return result;
}
