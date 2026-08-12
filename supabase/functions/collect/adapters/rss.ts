import { parseFeed } from "rss";
import type { Source, RawItem, FeedItem, SourceAdapter } from "../types.ts";
import { stableHash } from "../hash.ts";

/** 파싱 불가능한 날짜에도 던지지 않고 null을 반환 */
function toIso(published: string | Date | null | undefined): string | null {
  if (!published) return null;
  const d = new Date(published);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** RSS/Atom XML → RawItem[] (순수) */
export async function parseRss(xml: string): Promise<RawItem[]> {
  const feed = await parseFeed(xml);
  return (feed.entries ?? []).map((e): RawItem => {
    const link = e.links?.[0]?.href ?? null;
    const published = e.published ?? e.publishedRaw ?? null;
    return {
      guid: e.id ?? null,
      link,
      title: e.title?.value ?? "(제목 없음)",
      summary: e.description?.value ?? null,
      imageUrl: e.attachments?.[0]?.url ?? null,
      publishedAt: toIso(published),
    };
  });
}

export const RssAdapter: SourceAdapter = {
  async fetch(source: Source, httpGet: typeof globalThis.fetch = globalThis.fetch) {
    const res = await httpGet(source.url, { headers: { "User-Agent": "iPick-collector/0.1" } });
    if (!res.ok) throw new Error(`RSS fetch ${res.status} for ${source.url}`);
    return parseRss(await res.text());
  },
  normalize(raw: RawItem, source: Source): FeedItem {
    const external_id = raw.guid ?? raw.link ?? stableHash(raw.title + (raw.publishedAt ?? ""));
    return {
      ip_id: source.ip_id,
      source_id: source.id,
      external_id,
      title: raw.title,
      summary: raw.summary,
      url: raw.link ?? "",
      image_url: raw.imageUrl,
      published_at: raw.publishedAt ?? new Date().toISOString(),
    };
  },
};
