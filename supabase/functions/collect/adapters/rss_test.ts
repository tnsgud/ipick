import { assertEquals } from "jsr:@std/assert@1";
import { parseRss, RssAdapter } from "./rss.ts";
import type { Source } from "../types.ts";

const source: Source = {
  id: "src-1", ip_id: "ip-1", type: "rss", url: "https://feed",
  config: null, is_active: true, last_polled_at: null,
  last_success_at: null, consecutive_failures: 0,
};

const xml = await Deno.readTextFile(
  new URL("../fixtures/sample_rss.xml", import.meta.url),
);

Deno.test("parseRss는 항목 수만큼 RawItem을 낸다", async () => {
  const items = await parseRss(xml);
  assertEquals(items.length, 2);
  assertEquals(items[0].title, "신제품 아크릴 스탠드 발매");
  assertEquals(items[0].guid, "goods-1");
  assertEquals(items[0].link, "https://example.com/goods/1");
});

Deno.test("normalize: guid가 있으면 external_id로 사용", () => {
  const raw = { guid: "goods-1", link: "https://x/1", title: "t", summary: null, imageUrl: null, publishedAt: "2026-08-11T09:00:00.000Z" };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(fi.external_id, "goods-1");
  assertEquals(fi.ip_id, "ip-1");
  assertEquals(fi.source_id, "src-1");
  assertEquals(fi.url, "https://x/1");
});

Deno.test("normalize: guid 없으면 link를 external_id로 사용", () => {
  const raw = { guid: null, link: "https://x/2", title: "t2", summary: null, imageUrl: null, publishedAt: null };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(fi.external_id, "https://x/2");
});

Deno.test("normalize: guid·link 모두 없으면 해시 폴백", () => {
  const raw = { guid: null, link: null, title: "제목", summary: null, imageUrl: null, publishedAt: "2026-08-11T09:00:00.000Z" };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(/^[0-9a-f]+$/.test(fi.external_id), true);
  assertEquals(fi.url, ""); // link 없으면 빈 문자열
});

Deno.test("fetch는 주입된 httpGet의 응답을 파싱한다", async () => {
  const fakeGet = ((_url: string) =>
    Promise.resolve(new Response(xml, { status: 200 }))) as unknown as typeof fetch;
  const items = await RssAdapter.fetch(source, fakeGet);
  assertEquals(items.length, 2);
});