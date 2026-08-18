-- 유저 ↔ IP 구독 (다대다). 설계 문서(§6 subscriptions)의 스키마를 그대로 반영.
create table subscriptions (
  user_id uuid not null references auth.users(id) on delete cascade,
  ip_id uuid not null references ips(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, ip_id)
);

-- 팬아웃(구독자 조회) 쿼리용 인덱스: "이 ip_id를 구독한 user_id들"
create index subscriptions_ip_id_idx on subscriptions (ip_id);

alter table subscriptions enable row level security;

-- 본인 구독만 읽기/추가/삭제 가능 (다른 유저 구독 목록은 보이지 않음)
create policy "read own subscriptions" on subscriptions
  for select using (auth.uid() = user_id);

create policy "insert own subscriptions" on subscriptions
  for insert with check (auth.uid() = user_id);

create policy "delete own subscriptions" on subscriptions
  for delete using (auth.uid() = user_id);

-- 테이블 GRANT는 RLS와 별개로 필요하다 (Supabase CLI가 기본 GRANT를 회수함 — 0001 참고).
-- authenticated: 본인 행 CRUD(RLS가 범위를 본인으로 제한). anon: 구독은 로그인 필요이므로 GRANT 없음.
-- service_role: 다음 계획(푸시 팬아웃)에서 전체 구독자 조회가 필요하므로 select 전체 부여.
grant select, insert, delete on subscriptions to authenticated;
grant select on subscriptions to service_role;
