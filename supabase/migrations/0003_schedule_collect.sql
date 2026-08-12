create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ============================================================================
-- ⚠️  DEPLOY-TIME TEMPLATE — DO NOT APPLY TO A REMOTE/PROD PROJECT AS-IS  ⚠️
-- ============================================================================
-- This migration registers a cron job that POSTs to the collect edge
-- function every 15 minutes. The URL below contains a literal placeholder,
-- <PROJECT_REF>, which is fine for local dev (the job registers but the
-- host does not resolve) but MUST be fixed before/when deploying remotely:
--
--   1. Replace <PROJECT_REF> below with this project's real Supabase
--      project ref (e.g. https://abcdefghijklmno.functions.supabase.co/collect).
--   2. Create the vault secret `collect_service_key` containing the real
--      service_role key BEFORE this migration runs on the remote project
--      (see Step 1 / secrets setup in the deploy runbook) — otherwise the
--      Authorization header resolves to NULL and every invocation 401s.
--
-- Skipping either step silently registers a job that fires every 15 minutes
-- against an invalid host or with a broken auth header. Local apply/reset is
-- unaffected either way and is how this job's registration is verified.
-- ============================================================================
select cron.schedule(
  'collect-sources',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.functions.supabase.co/collect',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'collect_service_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
