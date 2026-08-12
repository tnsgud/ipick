import { assertEquals, assertNotEquals } from "std/assert";
import { stableHash } from "./hash.ts";

Deno.test("stableHash는 같은 입력에 같은 값을 낸다", () => {
  assertEquals(stableHash("hello"), stableHash("hello"));
});

Deno.test("stableHash는 다른 입력에 다른 값을 낸다", () => {
  assertNotEquals(stableHash("hello"), stableHash("world"));
});

Deno.test("stableHash는 16진 문자열이다", () => {
  assertEquals(/^[0-9a-f]+$/.test(stableHash("anything")), true);
});
