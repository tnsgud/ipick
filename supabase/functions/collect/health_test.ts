import { assertEquals } from "std/assert";
import { nextHealth } from "./health.ts";
import type { Source } from "./types.ts";

const NOW = "2026-08-12T00:00:00.000Z";
function makeSource(o: Partial<Source> = {}): Source {
  return { id: "s1", ip_id: "ip1", type: "rss", url: "http://x", config: null,
    is_active: true, last_polled_at: null, last_success_at: null,
    consecutive_failures: 0, ...o };
}

Deno.test("성공 시 실패 카운트 리셋 + last_success 갱신", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 3 }), "success", NOW);
  assertEquals(h.consecutive_failures, 0);
  assertEquals(h.last_success_at, NOW);
  assertEquals(h.last_polled_at, NOW);
  assertEquals(h.is_active, true);
});

Deno.test("실패 시 카운트 증가, 5회 미만이면 활성 유지", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 3 }), "failure", NOW);
  assertEquals(h.consecutive_failures, 4);
  assertEquals(h.is_active, true);
  assertEquals(h.last_success_at, undefined);
});

Deno.test("실패로 5회 도달 시 자동 비활성화", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 4 }), "failure", NOW);
  assertEquals(h.consecutive_failures, 5);
  assertEquals(h.is_active, false);
});
