-- 확장
create extension if not exists "pgcrypto";

-- 대분류
create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

-- 팬덤 대상 IP
create table ips (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  thumbnail_url text,
  created_at timestamptz not null default now()
);

-- 소스 타입
create type source_type as enum ('rss', 'youtube', 'website', 'x');

-- IP별 공식 소스 화이트리스트
create table sources (
  id uuid primary key default gen_random_uuid(),
  ip_id uuid not null references ips(id) on delete cascade,
  type source_type not null,
  url text not null,
  config jsonb,
  is_active boolean not null default true,
  last_polled_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures int not null default 0,
  created_at timestamptz not null default now()
);
create index sources_active_idx on sources (is_active) where is_active;

-- 정규화된 소식
create table feed_items (
  id uuid primary key default gen_random_uuid(),
  ip_id uuid not null references ips(id) on delete cascade,
  source_id uuid not null references sources(id) on delete cascade,
  external_id text not null,
  title text not null,
  summary text,
  url text not null,
  image_url text,
  item_type text,
  buy_url text,
  published_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (source_id, external_id)          -- 중복제거의 핵심
);
create index feed_items_ip_published_idx on feed_items (ip_id, published_at desc);

-- RLS: 서비스롤(수집기)은 RLS 우회. 클라이언트 노출 대비 안전 기본값.
alter table categories enable row level security;
alter table ips enable row level security;
alter table sources enable row level security;
alter table feed_items enable row level security;

-- 공개 읽기: 카탈로그와 피드는 익명 조회 허용 (앱이 이후 소비)
create policy "categories readable" on categories for select using (true);
create policy "ips readable" on ips for select using (true);
create policy "feed_items readable" on feed_items for select using (true);
-- sources: 정책 없음 → 익명 접근 거부. 서비스롤만 접근.
