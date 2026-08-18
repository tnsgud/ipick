-- Fixes the collect-sources cron job to point at this project's real Edge
-- Functions URL, replacing the deploy-time <PROJECT_REF> placeholder left
-- in 0003_schedule_collect.sql. Forward-only fix per project convention
-- (see docs/superpowers/plans/2026-08-13-self-hosted-deployment.md,
-- "마이그레이션이 잘못 나갔을 때") — already-applied migrations are not
-- edited in place, they are corrected with a new migration.
--
-- URL confirmed working via manual curl against the deployed function
-- (https://<ref>.supabase.co/functions/v1/<name> — the current Supabase
-- Cloud Edge Functions invoke URL scheme, not the older
-- <ref>.functions.supabase.co form 0003 assumed at spec-writing time).
--
-- Project ref is not a secret (it's a public identifier, visible in every
-- dashboard/API URL) — safe to commit here, unlike the vault secret it
-- references for auth.

select cron.unschedule('collect-sources');

select cron.schedule(
  'collect-sources',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://obxjpqemljdtxyhykber.supabase.co/functions/v1/collect',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'collect_service_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
