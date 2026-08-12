create extension if not exists pg_cron;
create extension if not exists pg_net;

-- <PROJECT_REF>는 배포 프로젝트 ref로 치환 (원격 배포 시).
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
