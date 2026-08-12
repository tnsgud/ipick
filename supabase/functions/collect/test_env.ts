import { createClient, type SupabaseClient } from "@supabase/supabase-js";

function decodeJwtRole(jwt: string): string {
  try {
    let p = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    while (p.length % 4) p += "=";
    return JSON.parse(atob(p)).role ?? "(unknown)";
  } catch {
    return "(not-a-jwt)";
  }
}

/** service_role 키를 강제 검증하고 클라이언트를 만든다. 잘못된 키면 명확히 실패. */
export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error(
      "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 미설정. " +
      'eval "$(supabase status -o env)" 후 export 하세요.',
    );
  }
  const role = decodeJwtRole(key);
  if (role !== "service_role") {
    throw new Error(
      `키의 role='${role}' 입니다. RLS 우회를 위해 SERVICE_ROLE_KEY(role=service_role)가 필요합니다.`,
    );
  }
  return createClient(url, key, { auth: { persistSession: false } });
}
