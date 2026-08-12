import type { SupabaseClient } from "@supabase/supabase-js";
import type { Source, FeedItem, HealthUpdate } from "./types.ts";

const SOURCE_COLUMNS =
  "id, ip_id, type, url, config, is_active, last_polled_at, last_success_at, consecutive_failures";

export async function getActiveSources(supabase: SupabaseClient): Promise<Source[]> {
  const { data, error } = await supabase.from("sources").select(SOURCE_COLUMNS).eq("is_active", true);
  if (error) throw new Error(`getActiveSources: ${error.message}`);
  return (data ?? []) as Source[];
}

/** 새로 삽입된 행만 반환. 중복(UNIQUE 충돌)은 무시. */
export async function insertFeedItems(
  supabase: SupabaseClient,
  items: FeedItem[],
): Promise<FeedItem[]> {
  if (items.length === 0) return [];
  const { data, error } = await supabase
    .from("feed_items")
    .upsert(items, { onConflict: "source_id,external_id", ignoreDuplicates: true })
    .select("ip_id, source_id, external_id, title, summary, url, image_url, published_at");
  if (error) throw new Error(`insertFeedItems: ${error.message}`);
  return (data ?? []) as FeedItem[];
}

export async function applyHealth(supabase: SupabaseClient, sourceId: string, h: HealthUpdate): Promise<void> {
  const { error } = await supabase.from("sources").update(h).eq("id", sourceId);
  if (error) throw new Error(`applyHealth: ${error.message}`);
}
