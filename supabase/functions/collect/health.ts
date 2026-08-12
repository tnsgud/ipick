import type { Source, HealthUpdate } from "./types.ts";

const MAX_FAILURES = 5;

export function nextHealth(
  source: Source,
  outcome: "success" | "failure",
  now: string,
): HealthUpdate {
  if (outcome === "success") {
    return {
      last_polled_at: now,
      last_success_at: now,
      consecutive_failures: 0,
      is_active: true,
    };
  }
  const failures = source.consecutive_failures + 1;
  return {
    last_polled_at: now,
    consecutive_failures: failures,
    is_active: failures < MAX_FAILURES,
  };
}