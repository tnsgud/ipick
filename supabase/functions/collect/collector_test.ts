import { assertEquals } from "std/assert";
import { serviceClient } from "./test_env.ts";
import { runCollector, type AdapterMap } from "./collector.ts";
import { RssAdapter } from "./adapters/rss.ts";

const supabase = serviceClient();
const NOW = "2026-08-12T00:00:00.000Z";
const xml = await Deno.readTextFile(new URL("./fixtures/sample_rss.xml", import.meta.url));
const adapters = { rss: RssAdapter } as unknown as AdapterMap;

Deno.test("정상 소스: 새 항목 삽입 + 성공 헬스", async () => {
  const okGet = ((_u: string) => Promise.resolve(new Response(xml, { status: 200 }))) as unknown as typeof fetch;
  const res = await runCollector(supabase, adapters, okGet, NOW);
  assertEquals(res.perSource.find((p) => p.ok)?.inserted, 2);
  assertEquals(res.newItems.length >= 2, true);
});

Deno.test("실패 소스는 격리되고 실패로 기록된다", async () => {
  const badGet = ((_u: string) => Promise.resolve(new Response("nope", { status: 500 }))) as unknown as typeof fetch;
  const res = await runCollector(supabase, adapters, badGet, NOW);
  assertEquals(res.perSource.every((p) => p.ok === false), true);
  assertEquals(res.perSource[0].error !== undefined, true);
});
