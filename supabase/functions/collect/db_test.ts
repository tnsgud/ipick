import { assertEquals } from "std/assert";
import { serviceClient } from "./test_env.ts";
import { getActiveSources, insertFeedItems, applyHealth } from "./db.ts";
import type { FeedItem } from "./types.ts";

const supabase = serviceClient();
const SEED_SOURCE = "33333333-3333-3333-3333-333333333333";
const SEED_IP = "22222222-2222-2222-2222-222222222222";

function item(external_id: string): FeedItem {
  return { ip_id: SEED_IP, source_id: SEED_SOURCE, external_id, title: "t",
    summary: null, url: "https://x/" + external_id, image_url: null,
    published_at: "2026-08-11T09:00:00.000Z" };
}

Deno.test("getActiveSources는 시드된 활성 RSS 소스를 포함한다", async () => {
  const seed = (await getActiveSources(supabase)).find((s) => s.id === SEED_SOURCE);
  assertEquals(seed?.type, "rss");
  assertEquals(seed?.is_active, true);
});

Deno.test("insertFeedItems는 새 항목만 세고, 재삽입은 0", async () => {
  assertEquals(await insertFeedItems(supabase, [item("dup-1"), item("dup-2")]), 2);
  assertEquals(await insertFeedItems(supabase, [item("dup-1"), item("dup-2")]), 0);
});

Deno.test("applyHealth는 소스 헬스를 갱신한다", async () => {
  await applyHealth(supabase, SEED_SOURCE, { last_polled_at: "2026-08-12T00:00:00.000Z", consecutive_failures: 2, is_active: true });
  const seed = (await getActiveSources(supabase)).find((s) => s.id === SEED_SOURCE);
  assertEquals(seed?.consecutive_failures, 2);
});
